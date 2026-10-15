import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/weather_adjustment_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/solar_phase_blend.dart';

/// Brightness is base + elevation shift - reductions + morning adjustment + limit.
/// Reductions are positive magnitudes; the shift, adjustment and limit are signed.
class CircadianCalculationResult {
  final double finalBrightness;
  final double baseBrightness;
  final double windDownImpact;
  final double sleepPressureImpact;
  final double sleepDebtImpact;
  final double weatherImpact;
  final double timeShiftImpact;
  final double elevationShiftImpact;
  final double limitImpact;
  final SolarPhaseBlend? basePhase;

  const CircadianCalculationResult({
    required this.finalBrightness,
    required this.baseBrightness,
    this.windDownImpact = 0,
    this.sleepPressureImpact = 0,
    this.sleepDebtImpact = 0,
    this.weatherImpact = 0,
    this.timeShiftImpact = 0,
    this.elevationShiftImpact = 0,
    this.limitImpact = 0,
    this.basePhase,
  });
}

/// All temperature impacts are signed and reconcile with the final integer value.
class TemperatureCalculationResult {
  final int baseTemperature;
  final int weatherImpact;
  final int timeShiftImpact;
  final int sleepPressureImpact;
  final int windDownImpact;
  final int sleepDebtImpact;
  final int finalTemperature;
  final int limitImpact;
  final int roundingImpact;
  final SolarPhaseBlend? basePhase;

  const TemperatureCalculationResult({
    required this.baseTemperature,
    this.weatherImpact = 0,
    this.timeShiftImpact = 0,
    this.sleepPressureImpact = 0,
    this.windDownImpact = 0,
    this.sleepDebtImpact = 0,
    required this.finalTemperature,
    this.limitImpact = 0,
    this.roundingImpact = 0,
    this.basePhase,
  });
}

class CircadianService {
  final WeatherAdjustmentService weatherAdjustmentService =
      WeatherAdjustmentService();

  /// Calculates target brightness and distributes factor influences.
  CircadianCalculationResult calculateTargetBrightness(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    double curveSharpness = 1.0,
    List<FlSpot>? curvePoints,
    WeatherData? weather,
    double presetSensitivity = 1.0,
    double weatherIntensity = 1.0,
    SmartCircadianData smartData = const SmartCircadianData.neutral(),
    CircadianMode circadianMode = CircadianMode.solarPhases,
    SolarPhasesConfig? phasesConfig,
    double? maxElevation,
    double? minElevation,
    double? unshiftedElevation,
  }) {
    double baseAt(double sunElevation) {
      if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
        return calculateBrightnessFromPhases(
          config: phasesConfig,
          phases: phases,
          elevation: sunElevation,
          maxElevation: maxElevation ?? 60.0,
          minElevation: minElevation ?? -60.0,
          now: now,
        );
      } else if (curvePoints != null && curvePoints.isNotEmpty) {
        final double effectiveElevation = normalizeElevationToStandardRange(
          elevation: sunElevation,
          minElevation: minElevation ?? -20.0,
          maxElevation: maxElevation ?? 90.0,
        );
        return interpolateCurve(curvePoints, effectiveElevation).clamp(0, 100);
      }
      if (sunElevation < -6) return 15;
      if (sunElevation > 20) return 100;
      return 60;
    }

    final baseBrightness = baseAt(unshiftedElevation ?? elevation);
    final shiftedBase = baseAt(elevation);

    double weatherFactor = 1.0;
    final bool isWeatherActiveWindow =
        now.isAfter(phases.sunrise) && now.isBefore(phases.astronomicalDusk);

    if (weather != null && presetSensitivity > 0 && isWeatherActiveWindow) {
      final baseFactor = weatherAdjustmentService.calculateWeatherFactor(
        weather,
        elevation,
      );
      final penalty = (1.0 - baseFactor) * presetSensitivity * weatherIntensity;
      weatherFactor = 1.0 - penalty;
    }

    final double baselineFloor;
    if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
      baselineFloor = _minimumPhaseBrightness(phasesConfig);
    } else if (curvePoints != null && curvePoints.isNotEmpty) {
      baselineFloor = curvePoints
          .map((p) => p.y)
          .reduce(math.min)
          .clamp(0, 100);
    } else {
      baselineFloor = 15.0;
    }

    // A weather floor may limit a reduction, but must never raise the curve.
    final double weatherAdjustedBase = (shiftedBase * weatherFactor).clamp(
      math.min(baselineFloor, shiftedBase),
      shiftedBase,
    );

    // Apply smart multipliers (Wind-down, Sleep Pressure, Sleep Debt) to the weather-adjusted base
    double theoreticalFinal =
        weatherAdjustedBase * smartData.brightnessMultiplier;

    // Apply Bio-morning boost (Additive towards 100%)
    double timeShiftImpact = 0.0;
    if (smartData.timeShiftFactor > 0) {
      // Pull towards 100% (or the max of the user preset / daytime phase)
      double morningTarget = 100.0;
      if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
        morningTarget = phasesConfig.day.brightness;
      } else if (curvePoints != null && curvePoints.isNotEmpty) {
        morningTarget = curvePoints.last.y;
      }

      final double adjBrightIntensity = math
          .pow(smartData.timeShiftBrightnessIntensity, 1.5)
          .toDouble();

      timeShiftImpact =
          (morningTarget - theoreticalFinal) *
          smartData.timeShiftFactor *
          adjBrightIntensity;
      theoreticalFinal += timeShiftImpact;
    }

    final finalBrightness = theoreticalFinal.clamp(0.0, 100.0);
    // Attribute the actual smart reduction before adding the morning boost.
    // Weather has its own effective reduction, including its floor.
    final reduction =
        weatherAdjustedBase * (1 - smartData.brightnessMultiplier);
    final wWindDown = math.max(0.0, 1 - smartData.windDownFactor);
    final wPressure = math.max(0.0, 1 - smartData.sleepPressureFactor);
    final wDebt = math.max(0.0, 1 - smartData.sleepDebtFactor);
    final weights = wWindDown + wPressure + wDebt;

    return CircadianCalculationResult(
      finalBrightness: finalBrightness,
      baseBrightness: baseBrightness,
      basePhase:
          circadianMode == CircadianMode.solarPhases && phasesConfig != null
          ? resolvePhaseBlend(
              phases: phases,
              elevation: unshiftedElevation ?? elevation,
              maxElevation: maxElevation ?? 60,
              now: now,
            )
          : null,
      elevationShiftImpact: shiftedBase - baseBrightness,
      weatherImpact: shiftedBase - weatherAdjustedBase,
      windDownImpact: weights > 0 ? reduction * wWindDown / weights : 0,
      sleepPressureImpact: weights > 0 ? reduction * wPressure / weights : 0,
      sleepDebtImpact: weights > 0 ? reduction * wDebt / weights : 0,
      timeShiftImpact: timeShiftImpact,
      limitImpact:
          finalBrightness - theoreticalFinal - (weights == 0 ? reduction : 0),
    );
  }

  TemperatureCalculationResult calculateTargetTemperature(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    required List<FlSpot> curvePoints,
    WeatherData? weather,
    double weatherIntensity = 1.0,
    SmartCircadianData smartData = const SmartCircadianData.neutral(),
    CircadianMode circadianMode = CircadianMode.solarPhases,
    SolarPhasesConfig? phasesConfig,
    double? maxElevation,
    double? minElevation,
  }) {
    if (curvePoints.isEmpty && phasesConfig == null) {
      return TemperatureCalculationResult(
        baseTemperature: 6500,
        finalTemperature: 6500,
      );
    }

    final int rawBaseTemperature;
    if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
      rawBaseTemperature = calculateTemperatureFromPhases(
        config: phasesConfig,
        phases: phases,
        elevation: elevation,
        maxElevation: maxElevation ?? 60.0,
        minElevation: minElevation ?? -60.0,
        now: now,
      );
    } else if (curvePoints.isNotEmpty) {
      final double effectiveElevation = normalizeElevationToStandardRange(
        elevation: elevation,
        minElevation: minElevation ?? -20.0,
        maxElevation: maxElevation ?? 90.0,
      );
      rawBaseTemperature = interpolateCurve(
        curvePoints,
        effectiveElevation,
      ).toInt();
    } else {
      rawBaseTemperature = 6500;
    }

    // Weather impact via centralised formula (D4)
    double weatherDrop = 0.0;
    if (weather != null) {
      weatherDrop = weatherAdjustmentService.calculateWeatherTemperatureDrop(
        weather: weather,
        now: now,
        phases: phases,
        intensity: weatherIntensity,
      );
    }

    const int minFloor = TemperatureConstants.min;
    const int maxAllowed = TemperatureConstants.max;

    final double baselineFloor;
    if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
      baselineFloor = [
        phasesConfig.night.temperature,
        phasesConfig.sunrise.temperature,
        phasesConfig.day.temperature,
        phasesConfig.sunset.temperature,
      ].reduce(math.min).clamp(minFloor, maxAllowed).toDouble();
    } else if (curvePoints.isNotEmpty) {
      baselineFloor = curvePoints
          .map((p) => p.y)
          .reduce(math.min)
          .clamp(minFloor.toDouble(), maxAllowed.toDouble());
    } else {
      baselineFloor = minFloor.toDouble();
    }

    // Weather impact cannot drop daytime temperature below the baseline night target
    final double weatherAdjustedBase =
        (rawBaseTemperature.toDouble() - weatherDrop).clamp(
          math.min(baselineFloor, rawBaseTemperature.toDouble()),
          rawBaseTemperature.toDouble(),
        );
    weatherDrop = rawBaseTemperature - weatherAdjustedBase;

    final double netNegativeSmartOffset =
        (smartData.sleepPressureTemperatureOffset < 0
            ? smartData.sleepPressureTemperatureOffset.toDouble()
            : 0.0) +
        (smartData.windDownTemperatureOffset < 0
            ? smartData.windDownTemperatureOffset.toDouble()
            : 0.0) +
        (smartData.sleepDebtTemperatureOffset < 0
            ? smartData.sleepDebtTemperatureOffset.toDouble()
            : 0.0);

    // Bio-Morning Cooling Boost (Additive towards 6500K / daytime cool target)
    // Priorities over Sleep Debt / Pressure / WindDown by calculating gap against effective base
    int timeShiftBoost = 0;
    if (smartData.timeShiftFactor > 0) {
      double morningTempTarget = maxAllowed.toDouble();
      if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
        morningTempTarget = phasesConfig.day.temperature.toDouble();
      } else if (curvePoints.isNotEmpty) {
        morningTempTarget = curvePoints.last.y;
      }

      final double effectiveBase = weatherAdjustedBase + netNegativeSmartOffset;
      final double gapToCool = morningTempTarget - effectiveBase;
      if (gapToCool > 0) {
        final double adjTempIntensity = math
            .pow(smartData.timeShiftTemperatureIntensity, 1.5)
            .toDouble();
        timeShiftBoost =
            (gapToCool * smartData.timeShiftFactor * adjTempIntensity).round();
      }
    }

    // Unclamped theoretical temperature
    final double theoreticalFinal =
        weatherAdjustedBase +
        timeShiftBoost +
        smartData.sleepPressureTemperatureOffset +
        smartData.windDownTemperatureOffset +
        smartData.sleepDebtTemperatureOffset;

    const minAllowed = minFloor;

    final int finalTemperature = theoreticalFinal.round().clamp(
      minAllowed,
      maxAllowed,
    );

    // Clamp effective timeShiftBoost if theoreticalFinal exceeded maxAllowed
    int effectiveTimeShiftBoost = timeShiftBoost;
    if (theoreticalFinal > maxAllowed) {
      final double overflow = theoreticalFinal - maxAllowed;
      effectiveTimeShiftBoost = math.max(
        0,
        (timeShiftBoost - overflow).round(),
      );
    }

    // Proportional distribution logic when lower bound (minAllowed) is hit
    double effectiveWeatherImpact = -weatherDrop;
    double effectiveSleepPressureImpact = smartData
        .sleepPressureTemperatureOffset
        .toDouble();
    double effectiveWindDownImpact = smartData.windDownTemperatureOffset
        .toDouble();
    double effectiveSleepDebtImpact = smartData.sleepDebtTemperatureOffset
        .toDouble();

    if (finalTemperature < minAllowed ||
        (theoreticalFinal < minAllowed && finalTemperature <= minAllowed)) {
      final double totalNegativeNeeded =
          (finalTemperature - (rawBaseTemperature + effectiveTimeShiftBoost))
              .toDouble();
      final double rawNegativeSum = -weatherDrop + netNegativeSmartOffset;
      if (rawNegativeSum < 0) {
        final double ratio = totalNegativeNeeded / rawNegativeSum;
        effectiveWeatherImpact *= ratio;
        effectiveSleepPressureImpact *= ratio;
        effectiveWindDownImpact *= ratio;
        effectiveSleepDebtImpact *= ratio;
      }
    }

    final finalWeatherImpact = effectiveWeatherImpact.round();
    final finalSleepPressureImpact = effectiveSleepPressureImpact.round();
    final finalWindDownImpact = effectiveWindDownImpact.round();
    final finalSleepDebtImpact = effectiveSleepDebtImpact.round();
    // Effective contributions already absorb proportional lower-bound limiting
    // and capped morning boosts. Keep their integer rounding separate from any
    // remaining range correction (e.g. a curve outside the supported range).
    final unroundedTotal =
        rawBaseTemperature +
        effectiveTimeShiftBoost +
        effectiveWeatherImpact +
        effectiveSleepPressureImpact +
        effectiveWindDownImpact +
        effectiveSleepDebtImpact;
    final roundedContributions =
        rawBaseTemperature +
        effectiveTimeShiftBoost +
        finalWeatherImpact +
        finalSleepPressureImpact +
        finalWindDownImpact +
        finalSleepDebtImpact;

    return TemperatureCalculationResult(
      baseTemperature: rawBaseTemperature,
      basePhase:
          circadianMode == CircadianMode.solarPhases && phasesConfig != null
          ? resolvePhaseBlend(
              phases: phases,
              elevation: elevation,
              maxElevation: maxElevation ?? 60,
              now: now,
            )
          : null,
      weatherImpact: finalWeatherImpact,
      timeShiftImpact: effectiveTimeShiftBoost,
      sleepPressureImpact: finalSleepPressureImpact,
      windDownImpact: finalWindDownImpact,
      sleepDebtImpact: finalSleepDebtImpact,
      finalTemperature: finalTemperature,
      limitImpact: finalTemperature - unroundedTotal.round(),
      roundingImpact: unroundedTotal.round() - roundedContributions,
    );
  }

  double _minimumPhaseBrightness(SolarPhasesConfig config) => [
    config.night.brightness,
    config.sunrise.brightness,
    config.day.brightness,
    config.sunset.brightness,
  ].reduce(math.min).clamp(0, 100);

  /// Linear interpolation shared by the editor marker and automatic control.
  /// Callers handle unavailable curves in their own brightness/temperature units.
  /// Throws [ArgumentError] when [points] is empty.
  double interpolateCurve(List<FlSpot> points, double currentElevation) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'Curve must not be empty');
    }

    // Clamp values if sun elevation falls outside chart boundaries
    if (currentElevation <= points.first.x) return points.first.y;
    if (currentElevation >= points.last.x) return points.last.y;

    // Linear interpolation between the two nearest points by sun elevation
    for (int i = 0; i < points.length - 1; i++) {
      if (currentElevation >= points[i].x &&
          currentElevation <= points[i + 1].x) {
        final p1 = points[i];
        final p2 = points[i + 1];
        if (p2.x == p1.x) return p1.y; // Guard against division by zero

        final t = (currentElevation - p1.x) / (p2.x - p1.x);
        return p1.y + (p2.y - p1.y) * t;
      }
    }

    return points.last.y;
  }

  /// Shares phase boundaries with the values and their user-facing explanation.
  SolarPhaseBlend resolvePhaseBlend({
    required SolarPhaseModel phases,
    required double elevation,
    required double maxElevation,
    required DateTime now,
    double plateauRatio = 0.5,
  }) {
    if (elevation <= -6) {
      return const SolarPhaseBlend.at(SolarTargetPhase.night);
    }
    final effectiveMax = maxElevation > 0 ? maxElevation : 1.0;
    final threshold = math.max(
      effectiveMax * plateauRatio,
      math.min(effectiveMax, 2),
    );
    if (elevation >= threshold) {
      return const SolarPhaseBlend.at(SolarTargetPhase.day);
    }
    final nowMinutes = now.hour * 60 + now.minute + now.second / 60.0;
    final noon = phases.solarNoon;
    double delta =
        nowMinutes - (noon.hour * 60 + noon.minute + noon.second / 60.0);
    while (delta > 720) {
      delta -= 1440;
    }
    while (delta < -720) {
      delta += 1440;
    }
    final morning = delta < 0;
    if (elevation == 0) {
      return SolarPhaseBlend.at(
        morning ? SolarTargetPhase.sunrise : SolarTargetPhase.sunset,
      );
    }
    final t = elevation < 0
        ? ((elevation + 6) / 6).clamp(0.0, 1.0)
        : (elevation / threshold).clamp(0.0, 1.0);
    final progress = t * t * (3 - 2 * t);
    if (elevation < 0) {
      return morning
          ? SolarPhaseBlend(
              SolarTargetPhase.night,
              SolarTargetPhase.sunrise,
              progress,
            )
          : SolarPhaseBlend(
              SolarTargetPhase.sunset,
              SolarTargetPhase.night,
              1 - progress,
            );
    }
    return morning
        ? SolarPhaseBlend(
            SolarTargetPhase.sunrise,
            SolarTargetPhase.day,
            progress,
          )
        : SolarPhaseBlend(
            SolarTargetPhase.day,
            SolarTargetPhase.sunset,
            1 - progress,
          );
  }

  double calculateBrightnessFromPhases({
    required SolarPhasesConfig config,
    required SolarPhaseModel phases,
    required double elevation,
    required double maxElevation,
    double? minElevation,
    required DateTime now,
    double plateauRatio = 0.5,
  }) => resolvePhaseBlend(
    phases: phases,
    elevation: elevation,
    maxElevation: maxElevation,
    now: now,
    plateauRatio: plateauRatio,
  ).brightness(config).clamp(0, 100);

  int calculateTemperatureFromPhases({
    required SolarPhasesConfig config,
    required SolarPhaseModel phases,
    required double elevation,
    required double maxElevation,
    double? minElevation,
    required DateTime now,
    double plateauRatio = 0.5,
  }) =>
      resolvePhaseBlend(
            phases: phases,
            elevation: elevation,
            maxElevation: maxElevation,
            now: now,
            plateauRatio: plateauRatio,
          )
          .temperature(config)
          .round()
          .clamp(TemperatureConstants.min, TemperatureConstants.max);

  double normalizeElevationToStandardRange({
    required double elevation,
    required double minElevation,
    required double maxElevation,
  }) {
    if (elevation >= 0) {
      final effectiveMax = maxElevation > 0 ? maxElevation : 1.0;
      final clampedElev = elevation.clamp(0.0, effectiveMax);
      return (clampedElev / effectiveMax) * 90.0;
    } else {
      final effectiveMin = minElevation < 0 ? minElevation.abs() : 1.0;
      final clampedElev = elevation.clamp(-effectiveMin, 0.0);
      return (clampedElev / effectiveMin) * 20.0;
    }
  }
}
