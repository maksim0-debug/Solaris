import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
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
      final brightness = service.calculateTargetBrightness(
        phases,
        -30.0,
        now,
      );
      expect(brightness, 15.0);
    });

    test('Solar Zenith should return default maxBrightness (100%)', () {
      final now = DateTime(2026, 3, 19, 12, 0); // Noon
      final brightness = service.calculateTargetBrightness(
        phases,
        60.0,
        now,
      );
      expect(brightness, 100.0);
    });

    test(
      'Golden Hour Evening (30 min before sunset) should return around 72.5% based on curve',
      () {
        final now = DateTime(2026, 3, 19, 17, 30);
        final brightness = service.calculateTargetBrightness(
          phases,
          5.0,
          now,
          curvePoints: curvePoints,
        );
        // elevation 5 between 0 (60%) and 10 (85%) => 72.5%
        expect(brightness, closeTo(72.5, 0.1));
      },
    );

    test('Civil Twilight should return between 60% and 15% based on curve', () {
      final now = DateTime(2026, 3, 19, 18, 15); // Middle of Civil Twilight
      final brightness = service.calculateTargetBrightness(
        phases,
        -3.0,
        now,
        curvePoints: curvePoints,
      );
      // elevation -3 between -6 (25%) and 0 (60%) => 42.5%
      expect(brightness, closeTo(42.5, 0.1));
    });
  });
}
