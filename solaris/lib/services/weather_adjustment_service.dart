import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';

class WeatherAdjustmentService {
  /// Calculates weather modifier from 0.40 (severe storm, -60%) to 1.0 (clear).
  /// [weatherData] - current weather.
  /// [sunElevation] - sun elevation in degrees.
  double calculateWeatherFactor(WeatherData? weatherData, double sunElevation) {
    if (weatherData == null) return 1.0;

    double baseFactor = 1.0;

    // Check precipitation first, taking priority over cloudiness
    if (weatherData.weatherCode >= 80 && weatherData.weatherCode <= 99) {
      // Downpours and thunderstorms (very dark)
      baseFactor = 0.50; // -50% brightness
    } else if (weatherData.weatherCode >= 50 && weatherData.weatherCode <= 69) {
      // Drizzle and rain
      baseFactor = 0.55; // -45% brightness
    } else if (weatherData.cloudCover > 80) {
      // Heavy cloud cover
      baseFactor = 0.70; // -30% brightness
    } else if (weatherData.cloudCover < 20) {
      // Clear sky
      baseFactor = 1.0;
    } else {
      // Linear interpolation for cloud cover from 20% to 80% (penalty from 0 to -30%)
      final cloudFactor = 1.0 - ((weatherData.cloudCover - 20) / 60) * 0.30;
      baseFactor = cloudFactor;
    }

    // Smoothly disable weather factor at night (sun below 0°).
    // Narrow fade zone to 5° so weather effect stays strong until sunset.
    double elevationMultiplier = (sunElevation.clamp(0.0, 5.0)) / 5.0;

    // Final factor
    final penalty = 1.0 - baseFactor;
    return 1.0 - (penalty * elevationMultiplier);
  }

  /// Centralized calculation of weather-induced color temperature shift (in Kelvin).
  ///
  /// Returns the reduction amount (>= 0). The caller subtracts this from base temperature.
  /// Active only during the "sunrise -> astronomical dusk" window and in
  /// adverse weather (weatherCode >= 50 || cloudCover > 50).
  ///
  /// Formula: `(cloudCover / 100) * 500 * intensity`.
  /// Maximum shift at intensity=1.0: -500K.
  double calculateWeatherTemperatureDrop({
    required WeatherData weather,
    required DateTime now,
    required SolarPhaseModel phases,
    double intensity = 1.0,
  }) {
    final bool isInActiveWindow =
        now.isAfter(phases.sunrise) && now.isBefore(phases.astronomicalDusk);

    if (!isInActiveWindow) return 0.0;

    final bool isBadWeather =
        weather.weatherCode >= 50 || weather.cloudCover > 50;

    if (!isBadWeather) return 0.0;

    return (weather.cloudCover / 100) * 500 * intensity;
  }
}
