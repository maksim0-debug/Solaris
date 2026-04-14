import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/utils/session_grouper.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:solaris/services/regime_analyzer.dart';

void main() {
  group('Session Grouping Fix Tests', () {
    test('Overlapping and nested sessions should be handled correctly', () {
      
      // Data from screenshot:
      // Session 1: 13:26 - 19:09
      // Session 2: 13:42 - 15:52 (nested in 1)
      // Session 3: 19:26 - 21:33 (close to 1)
      
      final sessions = [
        SleepSession(
          id: '1',
          startTime: DateTime(2026, 3, 31, 13, 26),
          endTime: DateTime(2026, 3, 31, 19, 09),
          title: 'Session 1',
        ),
        SleepSession(
          id: '2',
          startTime: DateTime(2026, 3, 31, 13, 42),
          endTime: DateTime(2026, 3, 31, 15, 52),
          title: 'Session 2 (Nested)',
        ),
        SleepSession(
          id: '3',
          startTime: DateTime(2026, 3, 31, 19, 26),
          endTime: DateTime(2026, 3, 31, 21, 33),
          title: 'Session 3',
        ),
      ];

      final nightGroups = SessionGrouper.groupByNight(
        sessions,
        mergeThresholdMinutes: 210, // Default
      );

      // Should all be in ONE night group
      expect(nightGroups.length, 1);
      expect(nightGroups.first.date.day, 31);
      
      // Nested session '2' should have been removed if it's perfectly nested
      // Or at least they should all be in the same group.
      // With my new deduplicator, '2' is removed.
      expect(nightGroups.first.allSessions.length, 2); 
      expect(nightGroups.first.allSessions.any((s) => s.id == '1'), true);
      expect(nightGroups.first.allSessions.any((s) => s.id == '2'), false);
      expect(nightGroups.first.allSessions.any((s) => s.id == '3'), true);
      
      // Aggregated session should span from first start to last end
      expect(nightGroups.first.aggregatedSession.startTime, DateTime(2026, 3, 31, 13, 26));
      expect(nightGroups.first.aggregatedSession.endTime, DateTime(2026, 3, 31, 21, 33));
    });

    test('Recency tolerance should follow tolerance window', () {
      final settings = RegimeSettings(toleranceWindow: 150);
      expect(settings.recencyTolerance, 150);

      // Verify analyzer uses it
      // latest at 13:45 (Apr 2)
      // entry at 12:27 (Apr 1)
      // diff = 78 min.
      // With 150 tolerance, it should NOT be outdated.
      
      final latest = SleepSession(
        id: 'latest',
        startTime: DateTime(2026, 4, 2, 13, 45),
        endTime: DateTime(2026, 4, 2, 18, 0),
        title: 'Latest',
      );
      final prev = SleepSession(
        id: 'prev',
        startTime: DateTime(2026, 4, 1, 12, 27),
        endTime: DateTime(2026, 4, 1, 20, 0),
        title: 'Previous',
      );

      final regimes = RegimeAnalyzer.analyze([latest, prev], settings: settings);
      
      // Should be in the same regime (or at least 'prev' should not be outdated if it fits the anchor)
      // but the most important is that NightGroup does not have isOutdated=true
      final allNights = regimes.expand((r) => r.nights).toList();
      final prevNight = allNights.firstWhere((n) => n.date.day == 1);
      
      expect(prevNight.isOutdated, false, reason: '78 min diff should be within 150 min tolerance');
    });
  });
}
