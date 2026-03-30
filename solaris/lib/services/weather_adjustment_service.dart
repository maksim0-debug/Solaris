import 'package:solaris/services/weather_service.dart';

class WeatherAdjustmentService {
  /// Вычисляет модификатор погоды от 0.65 (сильная гроза) до 1.0 (ясно).
  /// [weatherData] - текущая погода.
  /// [sunElevation] - высота солнца в градусах.
  double calculateWeatherFactor(WeatherData? weatherData, double sunElevation) {
    if (weatherData == null) return 1.0;

    double baseFactor = 1.0;

    // Сначала проверяем осадки, они приоритетнее облачности
    if (weatherData.weatherCode >= 80 && weatherData.weatherCode <= 99) {
      // Ливни и грозы
      baseFactor = 0.65;
    } else if (weatherData.weatherCode >= 50 && weatherData.weatherCode <= 69) {
      // Морось и дождь
      baseFactor = 0.75;
    } else if (weatherData.cloudCover > 80) {
      // Сильная облачность
      baseFactor = 0.85;
    } else if (weatherData.cloudCover < 20) {
      // Ясно
      baseFactor = 1.0;
    } else {
      // Линейная интерполяция для облачности от 20% до 80% между 1.0 и 0.85
      final cloudFactor = 1.0 - ((weatherData.cloudCover - 20) / 60) * 0.15;
      baseFactor = cloudFactor;
    }

    // Если ночь (солнце ниже 0), фактор погоды плавно отключается
    // Влияние погоды полностью работает когда солнце > 10°
    // А от 0° до 10° плавно сходит на нет (фактор стремится к 1.0)
    double elevationMultiplier = (sunElevation.clamp(0.0, 10.0)) / 10.0;

    // Итоговый фактор
    final penalty = 1.0 - baseFactor;
    return 1.0 - (penalty * elevationMultiplier);
  }
}
