import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';

void main() {
  group('CircadianService Tests', () {
    final service = CircadianService();

    // Mock SolarPhaseModel
    final phases = SolarPhaseModel(
      sunrise: DateTime(2026, 3, 19, 6, 0),
      sunset: DateTime(2026, 3, 19, 18, 0),
      goldenHourMorning: DateTime(2026, 3, 19, 5, 30),
      goldenHourEvening: DateTime(2026, 3, 19, 17, 30),
      civilTwilightBegin: DateTime(2026, 3, 19, 5, 30),
      civilTwilightEnd: DateTime(2026, 3, 19, 18, 30),
      astronomicalDawn: DateTime(2026, 3, 19, 4, 30),
      civilDusk: DateTime(2026, 3, 19, 18, 30),
      solarNoon: DateTime(2026, 3, 19, 12, 0),
      astronomicalDusk: DateTime(2026, 3, 19, 19, 30),
    );

    test('Deep Night should return minBrightness (15%)', () {
      final now = DateTime(2026, 3, 19, 2, 0); // 2 AM
      final brightness = service.calculateTargetBrightness(phases, -30.0, now);
      expect(brightness, CircadianService.minBrightness);
    });

    test('Solar Zenith should return maxBrightness (100%)', () {
      final now = DateTime(2026, 3, 19, 12, 0); // Noon
      final brightness = service.calculateTargetBrightness(phases, 60.0, now);
      expect(brightness, CircadianService.maxBrightness);
    });

    test(
      'Golden Hour Evening (30 min before sunset) should return around 70-80%',
      () {
        final now = DateTime(2026, 3, 19, 17, 30);
        // Progress = 1800 / 3600 = 0.5. Eased: 1 - (-2 * 0.5 + 2)^2 / 2 = 1 - 1/2 = 0.5.
        // Wait, 1 - (-2*0.5 + 2)^2 / 2 = 1 - (1)^2 / 2 = 0.5.
        // 60 + (100 - 60) * 0.5 = 80.
        final brightness = service.calculateTargetBrightness(phases, 5.0, now);
        expect(brightness, closeTo(80.0, 0.1));
      },
    );

    test('Civil Twilight should return between 60% and 25%', () {
      final now = DateTime(2026, 3, 19, 18, 15); // Middle of Civil Twilight
      final brightness = service.calculateTargetBrightness(phases, -3.0, now);
      // progress = -3 / -6 = 0.5. 60 - (60 - 25) * 0.5 = 42.5.
      expect(brightness, closeTo(42.5, 0.1));
    });
  });
}
