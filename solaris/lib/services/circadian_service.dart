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

  CircadianCalculationResult({
    required this.finalBrightness,
    required this.baseBrightness,
    this.windDownImpact = 0,
    this.sleepPressureImpact = 0,
    this.sleepDebtImpact = 0,
    this.weatherImpact = 0,
  });
}

class CircadianService {
  final WeatherAdjustmentService weatherAdjustmentService =
      WeatherAdjustmentService();

  /// Вычисляет целевую яркость и распределяет влияние факторов
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
        );
      }
    }

    return CircadianCalculationResult(
      finalBrightness: finalBrightness,
      baseBrightness: baseBrightness,
    );
  }

  int calculateTargetTemperature(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    required List<FlSpot> curvePoints,
    WeatherData? weather,
    SmartCircadianData smartData = const SmartCircadianData.neutral(),
  }) {
    if (curvePoints.isEmpty) return 6500;

    double baseTemperature = _calculateFromElevation(curvePoints, elevation);

    // Weather impact on temperature: make it slightly cooler/warmer
    final bool isWeatherActiveWindow =
        now.isAfter(phases.sunrise) && now.isBefore(phases.astronomicalDusk);

    if (weather != null && isWeatherActiveWindow) {
      if (weather.weatherCode >= 50 || weather.cloudCover > 50) {
        // Less blue light during dark/cloudy conditions
        // Drop temperature depending on how heavy the cloud cover is, by up to ~500K.
        double tempDrop = (weather.cloudCover / 100) * 500;
        baseTemperature -= tempDrop;
      }
    }

    // Typical clamping for Kelvin
    int finalTemp = baseTemperature.clamp(3300.0, 6500.0).toInt();

    // Apply Smart Offset (Wind-down, Sleep Debt)
    finalTemp += smartData.temperatureOffset;

    return finalTemp.clamp(3300, 6500);
  }

  double _calculateFromElevation(List<FlSpot> points, double currentElevation) {
    if (points.isEmpty) return 15.0;

    // Ограничители, если солнце ушло за пределы графика
    if (currentElevation <= points.first.x) return points.first.y;
    if (currentElevation >= points.last.x) return points.last.y;

    // Линейная интерполяция между двумя ближайшими точками по высоте солнца
    for (int i = 0; i < points.length - 1; i++) {
      if (currentElevation >= points[i].x &&
          currentElevation <= points[i + 1].x) {
        final p1 = points[i];
        final p2 = points[i + 1];
        if (p2.x == p1.x) return p1.y; // Защита от деления на ноль

        final t = (currentElevation - p1.x) / (p2.x - p1.x);
        return p1.y + (p2.y - p1.y) * t;
      }
    }

    return points.last.y;
  }
}
