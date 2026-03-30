import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/weather_adjustment_service.dart';

class CircadianService {
  final WeatherAdjustmentService weatherAdjustmentService =
      WeatherAdjustmentService();

  /// Вычисляет целевую яркость исключительно на основе высоты солнца (elevation)
  double calculateTargetBrightness(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    double curveSharpness = 1.0,
    List<FlSpot>? curvePoints,
    WeatherData? weather,
    double presetSensitivity = 1.0,
  }) {
    double baseBrightness;

    if (curvePoints != null && curvePoints.isNotEmpty) {
      baseBrightness = _calculateFromElevation(curvePoints, elevation);
    } else {
      // Фолбэк, если точки не загрузились - используем дефолтные значения из графика
      // -20 elevation -> 15% brightness, 30+ elevation -> 100% brightness
      if (elevation < -6)
        baseBrightness = 15.0;
      else if (elevation > 20)
        baseBrightness = 100.0;
      else
        baseBrightness = 60.0;
    }

    if (weather != null && presetSensitivity > 0) {
      final baseFactor = weatherAdjustmentService.calculateWeatherFactor(
        weather,
        elevation,
      );
      final finalFactor = 1.0 - ((1.0 - baseFactor) * presetSensitivity);
      double targetBrightness = baseBrightness * finalFactor;

      // Clamp target brightness to the minimum value of the preset
      double minAllowed = 0.0;
      if (curvePoints != null && curvePoints.isNotEmpty) {
        // Мы предполагаем, что минимальное значение яркости ночью — это первая точка
        minAllowed = curvePoints.first.y;
      } else {
        minAllowed = 15.0;
      }

      return targetBrightness.clamp(minAllowed, 100.0);
    }

    return baseBrightness;
  }

  int calculateTargetTemperature(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    required List<FlSpot> curvePoints,
    WeatherData? weather,
  }) {
    if (curvePoints.isEmpty) return 6500;

    double baseTemperature = _calculateFromElevation(curvePoints, elevation);

    // Weather impact on temperature: make it slightly cooler/warmer
    if (weather != null) {
      if (weather.weatherCode >= 50 || weather.cloudCover > 50) {
        // Less blue light during dark/cloudy conditions
        // Drop temperature depending on how heavy the cloud cover is, by up to ~500K.
        double tempDrop = (weather.cloudCover / 100) * 500;
        baseTemperature -= tempDrop;
      }
    }

    // Typical clamping for Kelvin
    return baseTemperature.clamp(1000.0, 10000.0).toInt();
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
