import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/services/sun_calculator_service.dart';

void main() {
  late SunCalculatorService service;

  setUp(() {
    service = SunCalculatorService();
    service.updateLocation(); // Reset cache
  });

  group('SunCalculatorService', () {
    const double lat = 50.45; // Kyiv
    const double lon = 30.52;
    final testDate = DateTime.utc(2024, 3, 20, 12, 0, 0); // Equinox

    test('calculatePhases returns a valid model and caches it', () async {
      final phases = await service.calculatePhases(lat, lon, testDate);

      expect(phases.sunrise, isNotNull);
      expect(phases.sunset, isNotNull);
      expect(phases.goldenHourMorning, isNotNull);
      expect(phases.goldenHourEvening, isNotNull);
      expect(phases.solarNoon, isNotNull);
      expect(phases.astronomicalDusk, isNotNull);

      // Test caching
      final phases2 = await service.calculatePhases(lat, lon, testDate);
      expect(identical(phases, phases2), isTrue);
    });

    test('getCurrentPhase correctly identifies zenith at noon', () async {
      final phases = await service.calculatePhases(lat, lon, testDate);

      // Solar noon is at phases.solarNoon
      final phase = service.getCurrentPhase(phases, phases.solarNoon);
      expect(phase, CurrentDayPhase.zenith);
    });

    test('getCurrentPhase correctly identifies deepNight', () async {
      final phases = await service.calculatePhases(lat, lon, testDate);

      // 1 AM is deep night
      final midnight = DateTime(
        phases.sunrise.year,
        phases.sunrise.month,
        phases.sunrise.day,
        1,
        0,
      );
      final phase = service.getCurrentPhase(phases, midnight);
      expect(phase, CurrentDayPhase.deepNight);
    });

    test(
      'getTimeUntilNextEvent returns positive duration for upcoming event',
      () async {
        final phases = await service.calculatePhases(lat, lon, testDate);

        // 1 hour before sunrise is 5:00 AM (approx).
        // Next event is civilTwilightBegin (approx 5:30 AM).
        // So duration should be around 30 minutes.
        final timeBeforeSunrise = phases.sunrise.subtract(
          const Duration(hours: 1),
        );
        final duration = service.getTimeUntilNextEvent(
          phases,
          timeBeforeSunrise,
        );

        expect(duration.inMinutes, closeTo(30, 5));
      },
    );

    test('updateLocation invalidates cache', () async {
      final phases = await service.calculatePhases(lat, lon, testDate);

      service.updateLocation();

      final phases2 = await service.calculatePhases(lat, lon, testDate);
      expect(identical(phases, phases2), isFalse);
    });
  });
}
