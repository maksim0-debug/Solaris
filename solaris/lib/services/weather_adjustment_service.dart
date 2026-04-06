import 'package:solaris/services/weather_service.dart';

class WeatherAdjustmentService {
  /// Вычисляет модификатор погоды от 0.40 (сильная гроза, -60%) до 1.0 (ясно).
  /// [weatherData] - текущая погода.
  /// [sunElevation] - высота солнца в градусах.
  double calculateWeatherFactor(WeatherData? weatherData, double sunElevation) {
    if (weatherData == null) return 1.0;

    double baseFactor = 1.0;

    // Сначала проверяем осадки, они приоритетнее облачности
    if (weatherData.weatherCode >= 80 && weatherData.weatherCode <= 99) {
      // Ливни и грозы (очень темно)
      baseFactor = 0.50; // -50% яркости
    } else if (weatherData.weatherCode >= 50 && weatherData.weatherCode <= 69) {
      // Морось и дождь
      baseFactor = 0.55; // -45% яркости
    } else if (weatherData.cloudCover > 80) {
      // Сильная облачность
      baseFactor = 0.70; // -30% яркости
    } else if (weatherData.cloudCover < 20) {
      // Ясно
      baseFactor = 1.0;
    } else {
      // Линейная интерполяция для облачности от 20% до 80% (штраф от 0 до -30%)
      final cloudFactor = 1.0 - ((weatherData.cloudCover - 20) / 60) * 0.30;
      baseFactor = cloudFactor;
    }

    // Если ночь (солнце ниже 0), фактор погоды плавно отключается.
    // Сужаем зону затухания до 5° (раньше было 10°).
    // Теперь эффект погоды остается сильным вплоть до самого заката.
    double elevationMultiplier = (sunElevation.clamp(0.0, 5.0)) / 5.0;

    // Итоговый фактор
    final penalty = 1.0 - baseFactor;
    return 1.0 - (penalty * elevationMultiplier);
  }
}
