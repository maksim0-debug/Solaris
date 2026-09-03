import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/weather_adjustment_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';

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
  }) {
    double baseBrightness;

    if (curvePoints != null && curvePoints.isNotEmpty) {
      baseBrightness = _calculateFromElevation(curvePoints, elevation);
    } else {
      if (elevation < -6)
        baseBrightness = 15.0;
      else if (elevation > 20)
        baseBrightness = 100.0;
      else
        baseBrightness = 60.0;
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

    // Physical final brightness (multiplicative)
    double theoreticalFinal =
        baseBrightness * weatherFactor * smartData.brightnessMultiplier;

    // Apply Bio-morning boost (Additive towards 100%)
    double timeShiftImpact = 0.0;
    if (smartData.timeShiftFactor > 0) {
      // Pull towards 100% (or the max of the user preset)
      double morningTarget = 100.0;
      if (curvePoints != null && curvePoints.isNotEmpty) {
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

    // Clamp to minimum allowed
    double minAllowed = 15.0;
    if (curvePoints != null && curvePoints.isNotEmpty) {
      minAllowed = curvePoints.first.y;
    }

    double finalBrightness = theoreticalFinal.clamp(minAllowed, 100.0);

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
  }) {
    if (curvePoints.isEmpty) {
      return TemperatureCalculationResult(
        baseTemperature: 6500,
        finalTemperature: 6500,
      );
    }

    final int rawBaseTemperature = _calculateFromElevation(
      curvePoints,
      elevation,
    ).toInt();

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

    final int minAllowed = curvePoints.isNotEmpty
        ? curvePoints.first.y.toInt().clamp(3300, 6500)
        : 3300;
    const int maxAllowed = 6500;

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
      if (curvePoints.isNotEmpty) {
        morningTempTarget = curvePoints.last.y;
      }

      final double effectiveBase = rawBaseTemperature + netNegativeSmartOffset;
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
        rawBaseTemperature +
        timeShiftBoost -
        weatherDrop +
        smartData.sleepPressureTemperatureOffset +
        smartData.windDownTemperatureOffset +
        smartData.sleepDebtTemperatureOffset;

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
}
