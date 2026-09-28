import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/weather_adjustment_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/solar_phases_config.dart';

class CircadianCalculationResult {
  final double finalBrightness;
  final double baseBrightness;
  final double windDownImpact;
  final double sleepPressureImpact;
  final double sleepDebtImpact;
  final double weatherImpact;
  final double timeShiftImpact;

  CircadianCalculationResult({
    required this.finalBrightness,
    required this.baseBrightness,
    this.windDownImpact = 0,
    this.sleepPressureImpact = 0,
    this.sleepDebtImpact = 0,
    this.weatherImpact = 0,
    this.timeShiftImpact = 0,
  });
}

class TemperatureCalculationResult {
  final int baseTemperature;
  final int weatherImpact;
  final int timeShiftImpact;
  final int sleepPressureImpact;
  final int windDownImpact;
  final int sleepDebtImpact;
  final int finalTemperature;

  TemperatureCalculationResult({
    required this.baseTemperature,
    this.weatherImpact = 0,
    this.timeShiftImpact = 0,
    this.sleepPressureImpact = 0,
    this.windDownImpact = 0,
    this.sleepDebtImpact = 0,
    required this.finalTemperature,
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
  }) {
    double baseBrightness;

    if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
      baseBrightness = calculateBrightnessFromPhases(
        config: phasesConfig,
        phases: phases,
        elevation: elevation,
        maxElevation: maxElevation ?? 60.0,
        minElevation: minElevation ?? -60.0,
        now: now,
      );
    } else if (curvePoints != null && curvePoints.isNotEmpty) {
      final double effectiveElevation = normalizeElevationToStandardRange(
        elevation: elevation,
        minElevation: minElevation ?? -20.0,
        maxElevation: maxElevation ?? 90.0,
      );
      baseBrightness = _calculateFromElevation(curvePoints, effectiveElevation);
    } else {
      if (elevation < -6) {
        baseBrightness = 15.0;
      } else if (elevation > 20) {
        baseBrightness = 100.0;
      } else {
        baseBrightness = 60.0;
      }
    }

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
      baselineFloor = phasesConfig.night.brightness.clamp(0.0, 100.0);
    } else if (curvePoints != null && curvePoints.isNotEmpty) {
      baselineFloor = curvePoints.first.y;
    } else {
      baselineFloor = 15.0;
    }

    // Weather impact should not drop daylight below baseline floor
    final double weatherAdjustedBase = (baseBrightness * weatherFactor).clamp(
      baselineFloor,
      100.0,
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

    double finalBrightness = theoreticalFinal.clamp(0.0, 100.0);

    // Proportional distribution logic
    if (finalBrightness < baseBrightness) {
      final totalReduction = baseBrightness - finalBrightness;

      // Weights based on reduction "strength" of each factor
      final wWeather = 1.0 - weatherFactor;
      final wWindDown = 1.0 - smartData.windDownFactor;
      final wPressure = 1.0 - smartData.sleepPressureFactor;
      final wDebt = 1.0 - smartData.sleepDebtFactor;

      final sumOfWeights = wWeather + wWindDown + wPressure + wDebt;

      if (sumOfWeights > 0) {
        return CircadianCalculationResult(
          finalBrightness: finalBrightness,
          baseBrightness: baseBrightness,
          weatherImpact: totalReduction * (wWeather / sumOfWeights),
          windDownImpact: totalReduction * (wWindDown / sumOfWeights),
          sleepPressureImpact: totalReduction * (wPressure / sumOfWeights),
          sleepDebtImpact: totalReduction * (wDebt / sumOfWeights),
          timeShiftImpact: timeShiftImpact,
        );
      }
    }

    return CircadianCalculationResult(
      finalBrightness: finalBrightness,
      baseBrightness: baseBrightness,
      timeShiftImpact: timeShiftImpact,
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
      rawBaseTemperature = _calculateFromElevation(
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
      baselineFloor = phasesConfig.night.temperature
          .clamp(minFloor, maxAllowed)
          .toDouble();
    } else if (curvePoints.isNotEmpty) {
      baselineFloor = curvePoints.first.y.clamp(
        minFloor.toDouble(),
        maxAllowed.toDouble(),
      );
    } else {
      baselineFloor = minFloor.toDouble();
    }

    // Weather impact cannot drop daytime temperature below the baseline night target
    final double weatherAdjustedBase =
        (rawBaseTemperature.toDouble() - weatherDrop).clamp(
          baselineFloor,
          maxAllowed.toDouble(),
        );

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

    final int minAllowed;
    if (circadianMode == CircadianMode.solarPhases && phasesConfig != null) {
      minAllowed = minFloor;
    } else if (curvePoints.isNotEmpty) {
      final hasSmartReduction =
          smartData.windDownTemperatureOffset < 0 ||
          smartData.sleepPressureTemperatureOffset < 0 ||
          smartData.sleepDebtTemperatureOffset < 0;
      minAllowed = hasSmartReduction
          ? minFloor
          : curvePoints.first.y.round().clamp(minFloor, maxAllowed);
    } else {
      minAllowed = minFloor;
    }

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
    int finalWeatherImpact = weatherDrop > 0 ? -weatherDrop.round() : 0;
    int finalSleepPressureImpact = smartData.sleepPressureTemperatureOffset;
    int finalWindDownImpact = smartData.windDownTemperatureOffset;
    int finalSleepDebtImpact = smartData.sleepDebtTemperatureOffset;

    if (finalTemperature < minAllowed ||
        (theoreticalFinal < minAllowed && finalTemperature <= minAllowed)) {
      final double totalNegativeNeeded =
          (finalTemperature - (rawBaseTemperature + effectiveTimeShiftBoost))
              .toDouble();
      final double rawNegativeSum = -weatherDrop + netNegativeSmartOffset;
      if (rawNegativeSum < 0) {
        final double ratio = totalNegativeNeeded / rawNegativeSum;
        finalWeatherImpact = (-weatherDrop * ratio).round();
        finalSleepPressureImpact =
            (smartData.sleepPressureTemperatureOffset * ratio).round();
        finalWindDownImpact = (smartData.windDownTemperatureOffset * ratio)
            .round();
        finalSleepDebtImpact = (smartData.sleepDebtTemperatureOffset * ratio)
            .round();
      }
    }

    return TemperatureCalculationResult(
      baseTemperature: rawBaseTemperature,
      weatherImpact: finalWeatherImpact,
      timeShiftImpact: effectiveTimeShiftBoost,
      sleepPressureImpact: finalSleepPressureImpact,
      windDownImpact: finalWindDownImpact,
      sleepDebtImpact: finalSleepDebtImpact,
      finalTemperature: finalTemperature,
    );
  }

  double _calculateFromElevation(List<FlSpot> points, double currentElevation) {
    if (points.isEmpty) return 15.0;

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

  double calculateBrightnessFromPhases({
    required SolarPhasesConfig config,
    required SolarPhaseModel phases,
    required double elevation,
    required double maxElevation,
    double? minElevation,
    required DateTime now,
    double plateauRatio = 0.5,
  }) {
    final nowMinutes = now.hour * 60 + now.minute + now.second / 60.0;
    final noonMinutes =
        phases.solarNoon.hour * 60 +
        phases.solarNoon.minute +
        phases.solarNoon.second / 60.0;
    // Calculate distance in minutes from solar noon across a 24h cycle [-720..720].
    // Ascending from nadir to noon is morning/sunrise branch.
    double deltaFromNoon = nowMinutes - noonMinutes;
    while (deltaFromNoon > 720.0) {
      deltaFromNoon -= 1440.0;
    }
    while (deltaFromNoon < -720.0) {
      deltaFromNoon += 1440.0;
    }
    final isMorning = deltaFromNoon < 0.0;
    final effectiveMax = maxElevation > 0 ? maxElevation : 1.0;
    final plateauThreshold = math.max(
      effectiveMax * plateauRatio,
      math.min(effectiveMax, 2.0),
    );

    // Deep night: sun well below twilight
    if (elevation <= -6.0) {
      return config.night.brightness.clamp(0.0, 100.0);
    }

    // Twilight transition (-6° to 0°)
    if (elevation < 0.0) {
      final t = ((elevation + 6.0) / 6.0).clamp(0.0, 1.0);
      final smoothT = t * t * (3 - 2 * t);
      final val = isMorning
          ? config.night.brightness +
                (config.sunrise.brightness - config.night.brightness) * smoothT
          : config.night.brightness +
                (config.sunset.brightness - config.night.brightness) * smoothT;
      return val.clamp(0.0, 100.0);
    }

    // Daytime Plateau
    if (elevation >= plateauThreshold) {
      return config.day.brightness.clamp(0.0, 100.0);
    }

    // Ramp from Sunrise/Sunset to Daytime Plateau (0° to plateauThreshold)
    final t = (elevation / plateauThreshold).clamp(0.0, 1.0);
    final smoothT = t * t * (3 - 2 * t);

    final val = isMorning
        ? config.sunrise.brightness +
              (config.day.brightness - config.sunrise.brightness) * smoothT
        : config.sunset.brightness +
              (config.day.brightness - config.sunset.brightness) * smoothT;
    return val.clamp(0.0, 100.0);
  }

  int calculateTemperatureFromPhases({
    required SolarPhasesConfig config,
    required SolarPhaseModel phases,
    required double elevation,
    required double maxElevation,
    double? minElevation,
    required DateTime now,
    double plateauRatio = 0.5,
  }) {
    final nowMinutes = now.hour * 60 + now.minute + now.second / 60.0;
    final noonMinutes =
        phases.solarNoon.hour * 60 +
        phases.solarNoon.minute +
        phases.solarNoon.second / 60.0;
    // Calculate distance in minutes from solar noon across a 24h cycle [-720..720].
    // Ascending from nadir to noon is morning/sunrise branch.
    double deltaFromNoon = nowMinutes - noonMinutes;
    while (deltaFromNoon > 720.0) {
      deltaFromNoon -= 1440.0;
    }
    while (deltaFromNoon < -720.0) {
      deltaFromNoon += 1440.0;
    }
    final isMorning = deltaFromNoon < 0.0;
    final effectiveMax = maxElevation > 0 ? maxElevation : 1.0;
    final plateauThreshold = math.max(
      effectiveMax * plateauRatio,
      math.min(effectiveMax, 2.0),
    );

    if (elevation <= -6.0) {
      return config.night.temperature.clamp(
        TemperatureConstants.min,
        TemperatureConstants.max,
      );
    }

    if (elevation < 0.0) {
      final t = ((elevation + 6.0) / 6.0).clamp(0.0, 1.0);
      final smoothT = t * t * (3 - 2 * t);
      final val = isMorning
          ? (config.night.temperature +
                    (config.sunrise.temperature - config.night.temperature) *
                        smoothT)
                .round()
          : (config.night.temperature +
                    (config.sunset.temperature - config.night.temperature) *
                        smoothT)
                .round();
      return val.clamp(TemperatureConstants.min, TemperatureConstants.max);
    }

    if (elevation >= plateauThreshold) {
      return config.day.temperature.clamp(
        TemperatureConstants.min,
        TemperatureConstants.max,
      );
    }

    final t = (elevation / plateauThreshold).clamp(0.0, 1.0);
    final smoothT = t * t * (3 - 2 * t);

    final val = isMorning
        ? (config.sunrise.temperature +
                  (config.day.temperature - config.sunrise.temperature) *
                      smoothT)
              .round()
        : (config.sunset.temperature +
                  (config.day.temperature - config.sunset.temperature) *
                      smoothT)
              .round();
    return val.clamp(TemperatureConstants.min, TemperatureConstants.max);
  }

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
