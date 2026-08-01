import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
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

    group('calculateTargetTemperature', () {
      final now = DateTime(2026, 3, 19, 12, 0); // Noon

      final tempPoints = [
        const FlSpot(-20, 3300),
        const FlSpot(-6, 3300),
        const FlSpot(0, 5000),
        const FlSpot(10, 6500),
        const FlSpot(90, 6500),
      ];

      test(
        'should return base temperature without weather or smart offset',
        () {
          final result = service.calculateTargetTemperature(
            phases,
            10.0,
            now,
            curvePoints: tempPoints,
          );
          expect(result.baseTemperature, 6500);
          expect(result.finalTemperature, 6500);
          expect(result.weatherImpact, 0);
          expect(result.sleepPressureImpact, 0);
        },
      );

      test('should apply weather temperature drop and respect intensity', () {
        final weather = WeatherData(
          temperature: 20,
          humidity: 50,
          uvIndex: 5,
          directRadiation: 500,
          diffuseRadiation: 150,
          cloudCover: 100, // 100% cloud cover
          windSpeed: 10,
          weatherCode: 51,
          lastUpdated: DateTime.now(),
        );

        final result = service.calculateTargetTemperature(
          phases,
          10.0,
          now,
          curvePoints: tempPoints,
          weather: weather,
          weatherIntensity: 0.8,
        );

        // drop = 100% * 500 * 0.8 = 400 K
        // base = 6500 -> 6100 (inside clamp 3300-6500)
        expect(result.baseTemperature, 6500);
        expect(result.weatherImpact, -400);
        expect(result.finalTemperature, 6100);
      });

      test(
        'should apply smart offsets and respect clamp logic with proportional impact',
        () {
          final smartData = const SmartCircadianData.neutral().copyWith(
            sleepPressureTemperatureOffset: -1000,
            windDownTemperatureOffset: -3000,
          );

          // Elevation 0.0 -> base = 5000 K
          // Total raw offset = -4000 K -> theoretical 1000 K.
          // Clamped final = 3300 K.
          // Total reduction = 5000 - 3300 = 1700 K.
          // windDown weight = 3000, pressure weight = 1000 (total = 4000).
          // windDownImpact = -1700 * 3000 / 4000 = -1275 K.
          // sleepPressureImpact = -1700 * 1000 / 4000 = -425 K.
          final result = service.calculateTargetTemperature(
            phases,
            0.0,
            now,
            curvePoints: tempPoints,
            smartData: smartData,
          );

          expect(result.baseTemperature, 5000);
          expect(result.sleepPressureImpact, -425);
          expect(result.windDownImpact, -1275);
          expect(result.finalTemperature, 3300);
          expect(
            result.baseTemperature +
                result.sleepPressureImpact +
                result.windDownImpact,
            3300,
          );
        },
      );

      test(
        'should prioritize Bio-Morning cooling boost to override Sleep Debt warming penalty',
        () {
          final smartData = const SmartCircadianData.neutral().copyWith(
            sleepDebtTemperatureOffset: -500,
            timeShiftFactor: 1.0,
            timeShiftTemperatureIntensity: 1.0,
          );

          // Elevation 10.0 -> base = 6500 K.
          // Sleep Debt = -500 K.
          // Bio-Morning factor = 1.0 -> effectiveBase = 6000 K -> gapToCool = 500 K.
          // timeShiftBoost = +500 K.
          // theoreticalFinal = 6500 + 500 - 500 = 6500 K.
          final result = service.calculateTargetTemperature(
            phases,
            10.0,
            now,
            curvePoints: tempPoints,
            smartData: smartData,
          );

          expect(result.baseTemperature, 6500);
          expect(result.sleepDebtImpact, -500);
          expect(result.timeShiftImpact, 500);
          expect(result.finalTemperature, 6500);
        },
      );
    });
  });
}
