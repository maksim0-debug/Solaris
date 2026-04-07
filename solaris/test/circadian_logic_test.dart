import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  group('CircadianService Tests', () {
    final service = CircadianService();

    // Mock SolarPhaseModel
    final phases = SolarPhaseModel(
      sunrise: DateTime(2026, 3, 19, 6, 0),
      sunset: DateTime(2026, 3, 19, 18, 0),
      goldenHourMorning: DateTime(2026, 3, 19, 5, 30),
      goldenHourMorningEnd: DateTime(2026, 3, 19, 6, 30),
      goldenHourEvening: DateTime(2026, 3, 19, 17, 30),
      goldenHourEveningEnd: DateTime(2026, 3, 19, 18, 30),
      civilTwilightBegin: DateTime(2026, 3, 19, 5, 30),
      civilTwilightEnd: DateTime(2026, 3, 19, 18, 30),
      astronomicalDawn: DateTime(2026, 3, 19, 4, 30),
      civilDusk: DateTime(2026, 3, 19, 18, 30),
      solarNoon: DateTime(2026, 3, 19, 12, 0),
      astronomicalDusk: DateTime(2026, 3, 19, 19, 30),
    );

    final curvePoints = [
      const FlSpot(-20, 15),
      const FlSpot(-6, 25),
      const FlSpot(0, 60),
      const FlSpot(10, 85),
      const FlSpot(30, 100),
      const FlSpot(90, 100),
    ];

    test('Deep Night should return default minBrightness (15%)', () {
      final now = DateTime(2026, 3, 19, 2, 0); // 2 AM
      final result = service.calculateTargetBrightness(phases, -30.0, now);
      expect(result.finalBrightness, 15.0);
    });

    test('Solar Zenith should return default maxBrightness (100%)', () {
      final now = DateTime(2026, 3, 19, 12, 0); // Noon
      final result = service.calculateTargetBrightness(phases, 60.0, now);
      expect(result.finalBrightness, 100.0);
    });

    test(
      'Golden Hour Evening (30 min before sunset) should return around 72.5% based on curve',
      () {
        final now = DateTime(2026, 3, 19, 17, 30);
        final result = service.calculateTargetBrightness(
          phases,
          5.0,
          now,
          curvePoints: curvePoints,
        );
        // elevation 5 between 0 (60%) and 10 (85%) => 72.5%
        expect(result.finalBrightness, closeTo(72.5, 0.1));
      },
    );

    test('Civil Twilight should return between 60% and 15% based on curve', () {
      final now = DateTime(2026, 3, 19, 18, 15); // Middle of Civil Twilight
      final result = service.calculateTargetBrightness(
        phases,
        -3.0,
        now,
        curvePoints: curvePoints,
      );
      // elevation -3 between -6 (25%) and 0 (60%) => 42.5%
      expect(result.finalBrightness, closeTo(42.5, 0.1));
    });

    test(
      'Weather adjustment applies preset sensitivity for daytime values',
      () {
        final now = DateTime(2026, 3, 19, 13, 0);
        final weather = WeatherData(
          temperature: 20,
          humidity: 50,
          uvIndex: 5,
          directRadiation: 500,
          diffuseRadiation: 150,
          cloudCover: 30,
          windSpeed: 15,
          weatherCode: 55, // rain => base weather factor 0.75 in daytime
          lastUpdated: DateTime.now(),
        );

        final result = service.calculateTargetBrightness(
          phases,
          30.0,
          now,
          curvePoints: curvePoints,
          weather: weather,
          presetSensitivity: 0.6,
        );

        // base=100; penalty=0.45; finalFactor=1-(0.45*0.6)=0.73 => 73
        expect(result.finalBrightness, closeTo(73.0, 0.1));
      },
    );

    test('Weather adjustment respects minimum preset brightness clamp', () {
      final now = DateTime(2026, 3, 19, 13, 0);
      final weather = WeatherData(
        temperature: 18,
        humidity: 60,
        uvIndex: 4,
        directRadiation: 300,
        diffuseRadiation: 120,
        cloudCover: 95,
        windSpeed: 25,
        weatherCode: 95, // thunderstorm => strongest penalty
        lastUpdated: DateTime.now(),
      );

      final pointsWithHighMinimum = [
        const FlSpot(-20, 40),
        const FlSpot(10, 20),
        const FlSpot(90, 20),
      ];

      final result = service.calculateTargetBrightness(
        phases,
        20.0,
        now,
        curvePoints: pointsWithHighMinimum,
        weather: weather,
        presetSensitivity: 1.0,
      );

      // Computed value falls below the configured minimum (first point = 40),
      // so the result must be clamped.
      expect(result.finalBrightness, 40.0);
    });
  });
}
