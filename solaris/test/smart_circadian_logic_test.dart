import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/smart_circadian_service.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/models/solar_phase_model.dart';

void main() {
  group('Bio-morning (Time Shift) Logic Overhaul Tests', () {
    final smartService = SmartCircadianService();
    final circadianService = CircadianService();

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

    final testSession = SleepSession(
      id: 'session1',
      startTime: DateTime(2026, 3, 19, 0, 0),
      endTime: DateTime(2026, 3, 19, 7, 0),
    );

    final regime = SleepRegime(
      id: 'test',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 31),
      averageBedtimeNormalized: 0,
      averageBedtimeFormatted: '00:00',
      averageWakeTimeNormalized: 360,
      averageWakeTimeFormatted: '06:00',
      windowStart: '00:00',
      windowEnd: '06:00',
      anomalyDates: const [],
      dayCount: 30,
      isFloating: false,
      isCurrent: true,
      nights: [
        NightGroup(
          date: DateTime(2026, 3, 19),
          aggregatedSession: testSession,
          allSessions: [testSession],
        ),
      ],
    );

    test(
      'Waking up 1h after sunrise should produce a positive timeShiftFactor',
      () {
        final now = DateTime(2026, 3, 19, 8, 30); // 1.5h after waking up
        final result = smartService.calculateSmartAdjustments(
          regimes: [regime],
          now: now,
          astronomicalSunrise: phases.sunrise,
          timeShiftIntensity: 1.0,
        );

        expect(result.isTimeShiftActive, isTrue);
        expect(result.timeShiftFactor, greaterThan(0));

        // 1.5h (90 min) out of 6h (360 min) is 0.25 progress.
        // cos(0.25 * pi/2) is around 0.9238.
        expect(result.timeShiftFactor, closeTo(0.9238, 0.01));
      },
    );

    test(
      'CircadianService should apply the factor as a boost towards 100%',
      () {
        final now = DateTime(2026, 3, 19, 8, 30);

        final smartData = SmartCircadianData(
          timeShiftFactor: 0.5, // 50% boost strength
        );

        final result = circadianService.calculateTargetBrightness(
          phases,
          15.0, // sun elevation
          now,
          smartData: smartData,
        );

        // elevation 15 is between -6 and 20 -> base=60.
        // Boost: (100 - 60) * 0.5 = 20. Final = 80.

        expect(result.finalBrightness, 80.0);
        expect(result.timeShiftImpact, 20.0);
      },
    );

    test('Low intensity should NOT disable the feature immediately', () {
      final now = DateTime(2026, 3, 19, 7, 30); // 30 min after waking up
      final result = smartService.calculateSmartAdjustments(
        regimes: [regime],
        now: now,
        astronomicalSunrise: phases.sunrise,
        timeShiftIntensity: 0.1, // 10% intensity
      );

      expect(result.isTimeShiftActive, isTrue);
      // 30 min / 360 min = 0.0833 progress.
      // cos(0.0833 * pi/2) = 0.9914.
      // factor = 0.1 * 0.9914 = 0.09914.
      expect(result.timeShiftFactor, closeTo(0.099, 0.005));
    });
  });
}
