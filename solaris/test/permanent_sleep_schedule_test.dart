import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/utils/session_grouper.dart';
import 'package:solaris/services/regime_analyzer.dart';
import 'package:solaris/services/smart_circadian_service.dart';
import 'package:solaris/providers/sleep_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('perm_sleep_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return tempDir.path;
          },
        );
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('SleepSession & SleepRegime Models (isPermanent)', () {
    test('toJson and fromJson preserves isPermanent flag', () {
      final session = SleepSession(
        id: 'test_perm_1',
        startTime: DateTime.utc(2026, 9, 20, 23, 0),
        endTime: DateTime.utc(2026, 9, 21, 7, 0),
        title: 'Permanent Sleep',
        isPermanent: true,
      );

      final json = session.toJson();
      expect(json['isPermanent'], isTrue);

      final restored = SleepSession.fromJson(json);
      expect(restored.isPermanent, isTrue);
      expect(restored.id, 'test_perm_1');
    });

    test('fromJson defaults isPermanent to false for legacy data', () {
      final legacyJson = {
        'id': 'legacy_1',
        'startTime': '2026-09-20T23:00:00.000Z',
        'endTime': '2026-09-21T07:00:00.000Z',
        'source': 'manual',
      };

      final session = SleepSession.fromJson(legacyJson);
      expect(session.isPermanent, isFalse);
    });

    test('copyWith properly updates isPermanent', () {
      final session = SleepSession(
        id: 'copy_1',
        startTime: DateTime.utc(2026, 9, 20, 23, 0),
        endTime: DateTime.utc(2026, 9, 21, 7, 0),
      );
      expect(session.isPermanent, isFalse);

      final updated = session.copyWith(isPermanent: true);
      expect(updated.isPermanent, isTrue);
      expect(updated.id, session.id);
    });
  });

  group('SessionGrouper & RegimeAnalyzer with isPermanent', () {
    test('SessionGrouper propagates isPermanent to aggregatedSession', () {
      final session = SleepSession(
        id: 's_perm_group',
        startTime: DateTime(2026, 9, 10, 23, 0),
        endTime: DateTime(2026, 9, 11, 7, 0),
        isPermanent: true,
      );

      final nights = SessionGrouper.groupByNight([session]);
      expect(nights.length, 1);
      expect(nights.first.aggregatedSession.isPermanent, isTrue);
    });

    test(
      'RegimeAnalyzer marks regime as isPermanent and isCurrent even if 10 days old',
      () {
        final oldStartTime = DateTime.now().subtract(
          const Duration(days: 10, hours: 8),
        );
        final oldEndTime = DateTime.now().subtract(const Duration(days: 10));

        final oldSession = SleepSession(
          id: 'old_permanent_session',
          startTime: oldStartTime,
          endTime: oldEndTime,
          source: 'manual',
          isPermanent: true,
        );

        final regimes = RegimeAnalyzer.analyze([oldSession]);
        expect(regimes.length, 1);
        final regime = regimes.first;

        // Because isPermanent is true, isCurrent must NOT expire after 2 days
        expect(regime.isPermanent, isTrue);
        expect(regime.isCurrent, isTrue);
      },
    );

    test(
      'RegimeAnalyzer preserves 1-day permanent regime even when older isolated regimes exist',
      () {
        // Regime 1: 1-day permanent regime (e.g. 5 days ago)
        final permDate = DateTime.now().subtract(const Duration(days: 5));
        final permSession = SleepSession(
          id: 'perm_1day',
          startTime: permDate,
          endTime: permDate.add(const Duration(hours: 8)),
          source: 'manual',
          isPermanent: true,
        );

        // Regime 2: 1-day non-permanent session (e.g. yesterday)
        final recentDate = DateTime.now().subtract(const Duration(days: 1));
        final recentSession = SleepSession(
          id: 'recent_1day',
          startTime: recentDate,
          endTime: recentDate.add(const Duration(hours: 7)),
          source: 'manual',
          isPermanent: false,
        );

        final regimes = RegimeAnalyzer.analyze([permSession, recentSession]);
        // Permanent regime must NOT be discarded despite length = 1
        expect(regimes.any((r) => r.isPermanent), isTrue);
      },
    );

    test(
      'Permanent schedule is isolated from historical organic sessions and never flagged as anomaly',
      () {
        // User historical sessions around 04:00 AM
        final s1 = SleepSession(
          id: 'hist_1',
          startTime: DateTime(2026, 9, 21, 3, 59),
          endTime: DateTime(2026, 9, 21, 12, 13),
          isPermanent: false,
        );
        final s2 = SleepSession(
          id: 'hist_2',
          startTime: DateTime(2026, 9, 22, 4, 3),
          endTime: DateTime(2026, 9, 22, 12, 18),
          isPermanent: false,
        );
        final s3 = SleepSession(
          id: 'hist_3',
          startTime: DateTime(2026, 9, 23, 5, 38),
          endTime: DateTime(2026, 9, 23, 13, 15),
          isPermanent: false,
        );

        // User sets permanent schedule for 23:00 - 08:00
        final perm = SleepSession(
          id: 'perm_schedule',
          startTime: DateTime(2026, 9, 23, 23, 0),
          endTime: DateTime(2026, 9, 24, 8, 0),
          isPermanent: true,
        );

        final regimes = RegimeAnalyzer.analyze([s1, s2, s3, perm]);

        // Permanent regime must exist and be isolated
        final permRegime = regimes.firstWhere((r) => r.isPermanent);
        expect(permRegime.averageBedtimeFormatted, '23:00');
        expect(permRegime.averageWakeTimeFormatted, '08:00');
        expect(permRegime.anomalyDates, isEmpty);
        expect(permRegime.nights.length, 1);
        expect(permRegime.nights.first.allSessions.first.id, 'perm_schedule');

        // Historical sessions must be kept in their own historical regime
        final histRegime = regimes.firstWhere((r) => !r.isPermanent);
        expect(histRegime.nights.length, 3);
        expect(histRegime.averageBedtimeFormatted, '04:01');
      },
    );
  });

  group('SmartCircadianService Virtual Cycle (Anti-Sleep-Pressure Collapse)', () {
    final service = SmartCircadianService();
    final phases = SolarPhaseModel(
      sunrise: DateTime(2026, 9, 23, 6, 30),
      sunset: DateTime(2026, 9, 23, 19, 0),
      goldenHourMorning: DateTime(2026, 9, 23, 6, 0),
      goldenHourMorningEnd: DateTime(2026, 9, 23, 7, 0),
      goldenHourEvening: DateTime(2026, 9, 23, 18, 30),
      goldenHourEveningEnd: DateTime(2026, 9, 23, 19, 30),
      civilTwilightBegin: DateTime(2026, 9, 23, 6, 0),
      civilTwilightEnd: DateTime(2026, 9, 23, 19, 30),
      astronomicalDawn: DateTime(2026, 9, 23, 5, 0),
      civilDusk: DateTime(2026, 9, 23, 19, 30),
      solarNoon: DateTime(2026, 9, 23, 12, 45),
      astronomicalDusk: DateTime(2026, 9, 23, 20, 30),
    );

    // Bedtime: 23:00, Wake time: 07:00
    // In minutes from noon: 23:00 = 660, 07:00 = 1140 (or -300)
    final permanentRegime = SleepRegime(
      id: 'regime_perm',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 2),
      averageBedtimeNormalized: 660,
      averageBedtimeFormatted: '23:00',
      averageWakeTimeNormalized: 1140,
      averageWakeTimeFormatted: '07:00',
      windowStart: '23:00',
      windowEnd: '23:00',
      anomalyDates: const [],
      dayCount: 1,
      nights: [
        NightGroup(
          date: DateTime(2026, 9, 1),
          aggregatedSession: SleepSession(
            id: 'agg_perm',
            startTime: DateTime(2026, 9, 1, 23, 0),
            endTime: DateTime(2026, 9, 2, 7, 0),
            isPermanent: true,
          ),
        ),
      ],
      isFloating: false,
      isCurrent: true,
      isPermanent: true,
    );

    test(
      'At 14:00 (afternoon), sleep pressure must NOT collapse brightness to 0.1 for 3-week-old permanent session',
      () {
        final nowAfternoon = DateTime(2026, 9, 23, 14, 0);

        final result = service.calculateSmartAdjustments(
          regimes: [permanentRegime],
          now: nowAfternoon,
          astronomicalSunrise: phases.sunrise,
          useSleepPressure: true,
          useWindDown: true,
        );

        // Sleep pressure factor should be 1.0 (since only 7 hours passed since today's 07:00 wake-up)
        expect(result.sleepPressureFactor, closeTo(1.0, 0.01));
        expect(result.brightnessMultiplier, closeTo(1.0, 0.05));
        expect(result.isWindDownActive, isFalse);
      },
    );

    test(
      'At 22:30 (evening), wind-down must smoothly activate 30 mins before 23:00 bedtime',
      () {
        final nowEvening = DateTime(2026, 9, 23, 22, 30);

        final result = service.calculateSmartAdjustments(
          regimes: [permanentRegime],
          now: nowEvening,
          astronomicalSunrise: phases.sunrise,
          useWindDown: true,
        );

        expect(result.isWindDownActive, isTrue);
        expect(result.windDownFactor, lessThan(1.0));
        expect(result.windDownTemperatureOffset, lessThan(0));
      },
    );

    test(
      'At 08:00 (morning, 1h after wake-up), TimeShift produces positive factor',
      () {
        final nowMorning = DateTime(2026, 9, 23, 8, 0);

        final result = service.calculateSmartAdjustments(
          regimes: [permanentRegime],
          now: nowMorning,
          astronomicalSunrise: phases.sunrise,
          useTimeShift: true,
        );

        // 1 hour after wake-up (7:00 -> 8:00), timeShiftFactor must be active (> 0)
        expect(result.timeShiftFactor, greaterThan(0.0));
      },
    );

    test(
      'Virtual cycle resolves wake time accurately when now is before wake-up without DST drift',
      () {
        // Bedtime 23:00, Wake 07:00. Now is 05:00 AM on Sept 23 (before 07:00 wake-up).
        // Effective wake time must be yesterday (Sept 22 at 07:00).
        final nowEarly = DateTime(2026, 9, 23, 5, 0);

        final result = service.calculateSmartAdjustments(
          regimes: [permanentRegime],
          now: nowEarly,
          astronomicalSunrise: phases.sunrise,
          useSleepPressure: true,
        );

        // At 05:00 AM, 22 hours since yesterday's 07:00 wake-up -> sleep pressure is active
        expect(result.sleepPressureFactor, lessThanOrEqualTo(1.0));
      },
    );

    test(
      'SmartCircadianService prioritizes isPermanent regime over newer dynamic isCurrent regime',
      () {
        // Dynamic regime from yesterday with late bedtime (01:00 AM)
        final dynamicRegime = SleepRegime(
          id: 'regime_dynamic_yesterday',
          startDate: DateTime(2026, 9, 22),
          endDate: DateTime(2026, 9, 23),
          averageBedtimeNormalized: 780, // 01:00 AM
          averageBedtimeFormatted: '01:00',
          averageWakeTimeNormalized: 1260, // 09:00 AM
          averageWakeTimeFormatted: '09:00',
          windowStart: '01:00',
          windowEnd: '01:00',
          anomalyDates: const [],
          dayCount: 1,
          nights: [
            NightGroup(
              date: DateTime(2026, 9, 22),
              aggregatedSession: SleepSession(
                id: 'agg_dyn',
                startTime: DateTime(2026, 9, 22, 1, 0),
                endTime: DateTime(2026, 9, 22, 9, 0),
              ),
            ),
          ],
          isFloating: false,
          isCurrent: true,
          isPermanent: false,
        );

        // At 22:30 (30 mins before permanent bedtime of 23:00):
        // If permanentRegime is chosen -> wind-down must be active (isWindDownActive == true).
        // If dynamicRegime (bedtime 01:00 AM) was incorrectly chosen -> wind-down would NOT be active (150 mins away).
        final nowEvening = DateTime(2026, 9, 23, 22, 30);
        final result = service.calculateSmartAdjustments(
          regimes: [dynamicRegime, permanentRegime],
          now: nowEvening,
          astronomicalSunrise: phases.sunrise,
          useWindDown: true,
        );

        expect(result.isWindDownActive, isTrue);
      },
    );
  });

  group('SleepState & SleepNotifier (Auto-Yielding & Permanent Management)', () {
    test(
      'SleepState.isSleepingAt calculates recurring sleeping window correctly',
      () {
        final permSession = SleepSession(
          id: 'perm_night',
          startTime: DateTime(2026, 9, 1, 23, 0),
          endTime: DateTime(2026, 9, 2, 7, 0),
          isPermanent: true,
        );

        final state = SleepState(sessions: [permSession]);

        // Standard night: 23:00 - 07:00
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 2, 0)), isTrue);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 14, 0)), isFalse);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 22, 59)), isFalse);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 23, 0)), isTrue);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 6, 59)), isTrue);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 7, 0)), isFalse);
      },
    );

    test(
      'SleepState.isSleepingAt handles day-sleeper (crossing noon) correctly',
      () {
        // Sleep from 08:00 AM to 16:00 (4:00 PM)
        final daySession = SleepSession(
          id: 'perm_day',
          startTime: DateTime(2026, 9, 1, 8, 0),
          endTime: DateTime(2026, 9, 1, 16, 0),
          isPermanent: true,
        );

        final state = SleepState(sessions: [daySession]);

        expect(state.isSleepingAt(DateTime(2026, 9, 25, 12, 0)), isTrue);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 15, 59)), isTrue);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 16, 0)), isFalse);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 20, 0)), isFalse);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 7, 59)), isFalse);
        expect(state.isSleepingAt(DateTime(2026, 9, 25, 8, 0)), isTrue);
      },
    );

    test(
      'SleepNotifier setSessionPermanent toggles flag and resets others',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final s1 = SleepSession(
          id: 's1',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: false,
        );
        final s2 = SleepSession(
          id: 's2',
          startTime: DateTime(2026, 9, 21, 23, 0),
          endTime: DateTime(2026, 9, 22, 7, 0),
          isPermanent: false,
        );

        await notifier.addManualSession(s1);
        await notifier.addManualSession(s2);

        // Set s1 as permanent
        await notifier.setSessionPermanent('s1', true);
        var currentSessions = container.read(sleepProvider).sessions;
        expect(
          currentSessions.firstWhere((s) => s.id == 's1').isPermanent,
          isTrue,
        );

        // Set s2 as permanent -> s1 must be reset to false
        await notifier.setSessionPermanent('s2', true);
        currentSessions = container.read(sleepProvider).sessions;
        expect(
          currentSessions.firstWhere((s) => s.id == 's2').isPermanent,
          isTrue,
        );
        expect(
          currentSessions.firstWhere((s) => s.id == 's1').isPermanent,
          isFalse,
        );

        // Unset permanent on s2
        await notifier.setSessionPermanent('s2', false);
        currentSessions = container.read(sleepProvider).sessions;
        expect(
          currentSessions.firstWhere((s) => s.id == 's2').isPermanent,
          isFalse,
        );
      },
    );

    test(
      'SleepNotifier updateSessionsFromIpc auto-yields permanent status',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final permSession = SleepSession(
          id: 'perm_legacy',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: true,
        );

        await notifier.addManualSession(permSession);
        expect(
          container.read(sleepProvider).sessions.first.isPermanent,
          isTrue,
        );

        // Fresh session comes from IPC
        final freshIpcSession = SleepSession(
          id: 'ipc_fresh',
          startTime: DateTime(2026, 9, 22, 23, 0),
          endTime: DateTime(2026, 9, 23, 7, 0),
          source: 'local_api',
        );

        await notifier.updateSessionsFromIpc([freshIpcSession]);

        final sessions = container.read(sleepProvider).sessions;
        final oldSession = sessions.firstWhere((s) => s.id == 'perm_legacy');
        // The permanent flag on the historical session must be auto-cleared
        expect(oldSession.isPermanent, isFalse);
      },
    );

    test(
      'SleepNotifier updateSessionsFromIpc does NOT yield permanent status on empty IPC update',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final permSession = SleepSession(
          id: 'perm_keep',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: true,
        );

        await notifier.addManualSession(permSession);
        expect(
          container.read(sleepProvider).sessions.first.isPermanent,
          isTrue,
        );

        // Empty IPC list received
        await notifier.updateSessionsFromIpc([]);

        final sessions = container.read(sleepProvider).sessions;
        expect(
          sessions.firstWhere((s) => s.id == 'perm_keep').isPermanent,
          isTrue,
        );
      },
    );

    test(
      'SleepNotifier consolidateNightSessions preserves isPermanent and resets others',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final otherPerm = SleepSession(
          id: 'other_perm',
          startTime: DateTime(2026, 9, 18, 23, 0),
          endTime: DateTime(2026, 9, 19, 7, 0),
          isPermanent: true,
        );
        final frag1 = SleepSession(
          id: 'frag1',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 2, 0),
          isPermanent: false,
        );
        final frag2 = SleepSession(
          id: 'frag2',
          startTime: DateTime(2026, 9, 21, 3, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: false,
        );

        await notifier.addManualSession(otherPerm);
        await notifier.addManualSession(frag1);
        await notifier.addManualSession(frag2);

        final consolidated = SleepSession(
          id: 'frag1',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: true,
          source: 'manual',
        );

        await notifier.consolidateNightSessions(
          oldSessionIds: ['frag1', 'frag2'],
          newSession: consolidated,
        );

        final sessions = container.read(sleepProvider).sessions;
        final res = sessions.firstWhere((s) => s.id == 'frag1');
        expect(res.isPermanent, isTrue);

        final prev = sessions.firstWhere((s) => s.id == 'other_perm');
        expect(prev.isPermanent, isFalse);
      },
    );

    test(
      'SleepNotifier setSessionPermanent upgrades session source to manual',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final gfSession = SleepSession(
          id: 'gf_session_1',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          source: 'google_fit',
          isPermanent: false,
        );

        await notifier.addManualSession(gfSession);

        await notifier.setSessionPermanent('gf_session_1', true);
        final sessions = container.read(sleepProvider).sessions;
        final updated = sessions.firstWhere((s) => s.id == 'gf_session_1');

        expect(updated.isPermanent, isTrue);
        expect(updated.source, 'manual');
      },
    );

    test(
      'SleepNotifier updateSessionsFromIpc does NOT yield permanent status on duplicate/repeated sessions',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);

        final permSession = SleepSession(
          id: 'perm_ipc_test',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          isPermanent: true,
        );

        final existingSession = SleepSession(
          id: 'existing_ipc',
          startTime: DateTime(2026, 9, 19, 23, 0),
          endTime: DateTime(2026, 9, 20, 7, 0),
          source: 'local_api',
        );

        await notifier.addManualSession(permSession);
        await notifier.addManualSession(existingSession);

        // Re-sending the exact same existing session must NOT cause permanent status to yield
        await notifier.updateSessionsFromIpc([existingSession]);

        final sessions = container.read(sleepProvider).sessions;
        final perm = sessions.firstWhere((s) => s.id == 'perm_ipc_test');
        expect(perm.isPermanent, isTrue);
      },
    );

    test(
      'SleepService fetchSleepData and SleepNotifier syncWithGoogleFit preserve permanent status when no fresh live data arrives',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sleepProvider.notifier);
        final service = container.read(sleepServiceProvider);

        final permSession = SleepSession(
          id: 'perm_sync_test',
          startTime: DateTime(2026, 9, 20, 23, 0),
          endTime: DateTime(2026, 9, 21, 7, 0),
          source: 'manual',
          isPermanent: true,
        );

        await notifier.addManualSession(permSession);

        // Fetch sleep data (fallback/cache check)
        final result = await service.fetchSleepData(forceNetwork: false);
        final perm = result.sessions.firstWhere(
          (s) => s.id == 'perm_sync_test',
        );
        expect(perm.isPermanent, isTrue);
        expect(result.liveSessionsCount, 0);

        // Sync with Google Fit
        await notifier.syncWithGoogleFit(forceSync: false);

        final currentSessions = container.read(sleepProvider).sessions;
        expect(
          currentSessions
              .firstWhere((s) => s.id == 'perm_sync_test')
              .isPermanent,
          isTrue,
        );
      },
    );
  });
}
