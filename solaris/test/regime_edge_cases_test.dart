import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:solaris/services/regime_analyzer.dart';

void main() {
  group('Regime Edge Cases & Overhaul Tests', () {
    test(
      'User exact scenario (4-11 Sep): clean average bedtime and no outdated pollution',
      () {
        final sessions = [
          // Sep 4 night: 22:40 - 06:30
          SleepSession(
            id: 's_sep4',
            startTime: DateTime(2026, 9, 4, 22, 40),
            endTime: DateTime(2026, 9, 5, 6, 30),
            title: 'Sep 4 night',
          ),
          // Sep 5 night (sleeps past midnight): Sep 6 00:13 - 06:32
          SleepSession(
            id: 's_sep5',
            startTime: DateTime(2026, 9, 6, 0, 13),
            endTime: DateTime(2026, 9, 6, 6, 32),
            title: 'Sep 5 night',
          ),
          // Sep 6 night: 22:32 - 07:22
          SleepSession(
            id: 's_sep6',
            startTime: DateTime(2026, 9, 6, 22, 32),
            endTime: DateTime(2026, 9, 7, 7, 22),
            title: 'Sep 6 night',
          ),
          // Sep 7 night: 23:24 - 06:58
          SleepSession(
            id: 's_sep7',
            startTime: DateTime(2026, 9, 7, 23, 24),
            endTime: DateTime(2026, 9, 8, 6, 58),
            title: 'Sep 7 night',
          ),
          // Sep 8 night: 22:59 - 07:13
          SleepSession(
            id: 's_sep8',
            startTime: DateTime(2026, 9, 8, 22, 59),
            endTime: DateTime(2026, 9, 9, 7, 13),
            title: 'Sep 8 night',
          ),
          // Sep 9 night: 22:51 - 07:49
          SleepSession(
            id: 's_sep9',
            startTime: DateTime(2026, 9, 9, 22, 51),
            endTime: DateTime(2026, 9, 10, 7, 49),
            title: 'Sep 9 night',
          ),
          // Sep 10 night: Sep 11 00:33 - 08:01
          SleepSession(
            id: 's_sep10',
            startTime: DateTime(2026, 9, 11, 0, 33),
            endTime: DateTime(2026, 9, 11, 8, 1),
            title: 'Sep 10 night',
          ),
        ];

        const settings = RegimeSettings(
          toleranceWindow: 100,
          maxSpread: 100,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
        expect(regimes.isNotEmpty, true);

        final current = regimes.firstWhere(
          (r) => r.isCurrent,
          orElse: () => regimes.first,
        );

        // Total nights should be 7
        expect(current.nights.length, 7);

        // Average bedtime should be around 22:50 - 23:15, NOT distorted to 23:47!
        // 22:40 is 640 min, 23:20 is 680 min from noon.
        expect(current.averageBedtimeNormalized, inInclusiveRange(640, 680));
      },
    );

    test(
      'New 1-day active regime is never filtered out even if minRegimeLength is 2',
      () {
        final sessions = [
          // Established 4-day night regime at ~23:00
          SleepSession(
            id: 's1',
            startTime: DateTime(2026, 8, 1, 23, 0),
            endTime: DateTime(2026, 8, 2, 7, 0),
          ),
          SleepSession(
            id: 's2',
            startTime: DateTime(2026, 8, 2, 23, 10),
            endTime: DateTime(2026, 8, 3, 7, 0),
          ),
          SleepSession(
            id: 's3',
            startTime: DateTime(2026, 8, 3, 22, 55),
            endTime: DateTime(2026, 8, 4, 7, 0),
          ),
          SleepSession(
            id: 's4',
            startTime: DateTime(2026, 8, 4, 23, 05),
            endTime: DateTime(2026, 8, 5, 7, 0),
          ),
          // Next day, user shifted completely to day sleep (e.g. Aug 6 09:00 AM)
          SleepSession(
            id: 's5',
            startTime: DateTime(2026, 8, 6, 9, 0),
            endTime: DateTime(2026, 8, 6, 17, 0),
          ),
        ];

        const settings = RegimeSettings(
          toleranceWindow: 90,
          maxSpread: 90,
          maxAnomalies: 0, // Immediately break regime on schedule shift
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);

        // There must be 2 regimes: the older 4-day regime and the new 1-day regime!
        expect(regimes.length, 2);

        // The newest regime (first in list) must be the 1-day morning regime
        final latest = regimes.first;
        expect(latest.dayCount, 1);
        expect(latest.averageBedtimeFormatted, '09:00');
      },
    );

    test('Daytime shift workers (sleep at 14:00) cleanly supported', () {
      final sessions = [
        SleepSession(
          id: 'd1',
          startTime: DateTime(2026, 7, 10, 14, 0),
          endTime: DateTime(2026, 7, 10, 22, 0),
        ),
        SleepSession(
          id: 'd2',
          startTime: DateTime(2026, 7, 11, 14, 15),
          endTime: DateTime(2026, 7, 11, 22, 15),
        ),
        SleepSession(
          id: 'd3',
          startTime: DateTime(2026, 7, 12, 13, 50),
          endTime: DateTime(2026, 7, 12, 21, 50),
        ),
      ];

      const settings = RegimeSettings(
        toleranceWindow: 60,
        maxSpread: 60,
        minRegimeLength: 2,
      );

      final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
      expect(regimes.length, 1);
      expect(regimes.first.dayCount, 3);
      // 14:00 is 120 minutes from noon
      expect(
        regimes.first.averageBedtimeNormalized,
        inInclusiveRange(110, 130),
      );
      expect(regimes.first.averageBedtimeFormatted.startsWith('14:'), true);
    });
  });
}
