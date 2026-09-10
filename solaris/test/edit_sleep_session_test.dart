import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/sleep_service.dart';
import 'package:solaris/services/regime_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );
  });

  group('Edit Sleep Session & Priority Protection Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'updateSession modifies session and enforces source to manual',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Initial Google Fit session
        final initialFit = SleepSession(
          id: 'fit_kyiv_1',
          startTime: DateTime(2026, 9, 9, 23, 0),
          endTime: DateTime(2026, 9, 10, 7, 0),
          title: 'Kyiv Sleep Initial',
          source: 'google_fit',
        );
        await notifier.updateSessionsFromIpc([initialFit]);
        expect(container.read(sleepProvider).sessions.length, 1);
        expect(
          container.read(sleepProvider).sessions.first.source,
          'google_fit',
        );

        // 2. Edit session (e.g. shift start and end times)
        final edited = SleepSession(
          id: 'fit_kyiv_1',
          startTime: DateTime(2026, 9, 9, 23, 30),
          endTime: DateTime(2026, 9, 10, 7, 45),
          title: 'Kyiv Sleep Adjusted',
          source:
              'google_fit', // UI might pass initial source, but updateSession must enforce 'manual'
        );
        await notifier.updateSession(edited);

        // 3. Verify in state
        final state = container.read(sleepProvider);
        expect(state.sessions.length, 1);
        final current = state.sessions.first;
        expect(current.id, 'fit_kyiv_1');
        expect(current.startTime, DateTime(2026, 9, 9, 23, 30));
        expect(current.endTime, DateTime(2026, 9, 10, 7, 45));
        expect(current.title, 'Kyiv Sleep Adjusted');
        expect(current.source, 'manual'); // Enforced manual priority
      },
    );

    test(
      'Edited session is NOT overwritten by incoming Google Fit or Local API sync with same ID',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Add session and edit it to manual
        final editedManual = SleepSession(
          id: 'shared_id_1',
          startTime: DateTime(2026, 9, 8, 23, 15),
          endTime: DateTime(2026, 9, 9, 7, 30),
          title: 'User Corrected Time in Kyiv',
          source: 'manual',
        );
        await notifier.addManualSession(editedManual);

        // 2. Incoming Google Fit session with same ID and raw times
        final fitIncoming = SleepSession(
          id: 'shared_id_1',
          startTime: DateTime(2026, 9, 8, 22, 45),
          endTime: DateTime(2026, 9, 9, 6, 50),
          title: 'Raw Google Fit Entry',
          source: 'google_fit',
        );
        await notifier.updateSessionsFromIpc([fitIncoming]);

        // Verify that manual version remains untouched
        final state1 = container.read(sleepProvider);
        expect(state1.sessions.length, 1);
        expect(state1.sessions.first.title, 'User Corrected Time in Kyiv');
        expect(state1.sessions.first.startTime, DateTime(2026, 9, 8, 23, 15));
        expect(state1.sessions.first.source, 'manual');

        // 3. Incoming Local API session with same ID and local_api source
        final apiIncoming = SleepSession(
          id: 'shared_id_1',
          startTime: DateTime(2026, 9, 8, 22, 50),
          endTime: DateTime(2026, 9, 9, 7, 0),
          title: 'Local API Auto Sync',
          source: 'local_api',
        );
        await notifier.updateSessionsFromIpc([apiIncoming]);

        // Verify that manual version STILL remains untouched (manual > local_api)
        final state2 = container.read(sleepProvider);
        expect(state2.sessions.length, 1);
        expect(state2.sessions.first.title, 'User Corrected Time in Kyiv');
        expect(state2.sessions.first.startTime, DateTime(2026, 9, 8, 23, 15));
        expect(state2.sessions.first.source, 'manual');
      },
    );

    test(
      'consolidateNightSessions replaces fragmented sub-sessions with a single consolidated manual session',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Two fragmented sub-sessions for the same night in Kyiv
        final seg1 = SleepSession(
          id: 'seg_1',
          startTime: DateTime(2026, 9, 9, 22, 51),
          endTime: DateTime(2026, 9, 10, 3, 30),
          title: 'Night Part 1',
          source: 'google_fit',
        );
        final seg2 = SleepSession(
          id: 'seg_2',
          startTime: DateTime(2026, 9, 10, 3, 50),
          endTime: DateTime(2026, 9, 10, 6, 58),
          title: 'Night Part 2',
          source: 'google_fit',
        );

        await notifier.updateSessionsFromIpc([seg1, seg2]);
        expect(container.read(sleepProvider).sessions.length, 2);

        // 2. Consolidate them into one continuous session
        final consolidated = SleepSession(
          id: 'manual_consolidated_kyiv',
          startTime: DateTime(2026, 9, 9, 22, 51),
          endTime: DateTime(2026, 9, 10, 6, 58),
          title: 'Consolidated Kyiv Night Sleep',
          source: 'google_fit', // Should be enforced to manual
        );

        await notifier.consolidateNightSessions(
          oldSessionIds: ['seg_1', 'seg_2'],
          newSession: consolidated,
        );

        // 3. Verify state contains only the consolidated session
        final state = container.read(sleepProvider);
        expect(state.sessions.length, 1);
        expect(state.sessions.first.id, 'manual_consolidated_kyiv');
        expect(state.sessions.first.source, 'manual');
        expect(state.sessions.first.startTime, DateTime(2026, 9, 9, 22, 51));
        expect(state.sessions.first.endTime, DateTime(2026, 9, 10, 6, 58));
        expect(
          state.sessions.first.duration,
          const Duration(hours: 8, minutes: 7),
        );

        // 4. Verify oldSessionIds were recorded in ignored list
        final sleepService = container.read(sleepServiceProvider);
        final ignored = await sleepService.loadIgnoredSessionIds();
        expect(ignored.contains('seg_1'), isTrue);
        expect(ignored.contains('seg_2'), isTrue);
      },
    );

    test(
      'Editing single segment of fragmented night does NOT cause non-overlapping adjacent segment to be dropped',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Fragmented night in Kyiv with a 30-minute awake gap (non-overlapping)
        final seg1 = SleepSession(
          id: 'kyiv_seg_1',
          startTime: DateTime(2026, 9, 9, 23, 0),
          endTime: DateTime(2026, 9, 10, 2, 30),
          title: 'First half',
          source: 'google_fit',
        );
        final seg2 = SleepSession(
          id: 'kyiv_seg_2',
          startTime: DateTime(2026, 9, 10, 3, 0),
          endTime: DateTime(2026, 9, 10, 7, 0),
          title: 'Second half',
          source: 'google_fit',
        );

        await notifier.updateSessionsFromIpc([seg1, seg2]);
        expect(container.read(sleepProvider).sessions.length, 2);

        // 2. User edits ONLY seg2 (e.g. adjusts wake-up time to 07:15)
        final editedSeg2 = SleepSession(
          id: 'kyiv_seg_2',
          startTime: DateTime(2026, 9, 10, 3, 0),
          endTime: DateTime(2026, 9, 10, 7, 15),
          title: 'Second half adjusted',
          source: 'manual',
        );
        await notifier.updateSession(editedSeg2);

        // 3. Incoming Google Fit sync re-fetches raw seg1 and seg2
        await notifier.updateSessionsFromIpc([seg1, seg2]);

        // 4. Verify BOTH seg1 and edited seg2 remain! Seg1 is NOT dropped because they do not overlap.
        final state = container.read(sleepProvider);
        expect(state.sessions.length, 2);
        final sessionIds = state.sessions.map((s) => s.id).toSet();
        expect(sessionIds, containsAll(['kyiv_seg_1', 'kyiv_seg_2']));
        final currentSeg2 = state.sessions.firstWhere(
          (s) => s.id == 'kyiv_seg_2',
        );
        expect(currentSeg2.endTime, DateTime(2026, 9, 10, 7, 15));
        expect(currentSeg2.source, 'manual');
      },
    );

    test(
      'RegimeAnalyzer handles circular spread across noon and midnight accurately',
      () {
        // Bedtimes: 23:30 (690 min from noon), 00:30 (750 min from noon) -> spread = 60
        final s1 = SleepSession(
          id: 's1',
          startTime: DateTime(2026, 9, 1, 23, 30),
          endTime: DateTime(2026, 9, 2, 7, 0),
        );
        final s2 = SleepSession(
          id: 's2',
          startTime: DateTime(2026, 9, 2, 0, 30),
          endTime: DateTime(2026, 9, 2, 8, 0),
        );
        final s3 = SleepSession(
          id: 's3',
          startTime: DateTime(2026, 9, 3, 23, 45),
          endTime: DateTime(2026, 9, 4, 7, 15),
        );

        final regimes = RegimeAnalyzer.analyze(
          [s1, s2, s3],
          settings: const RegimeSettings(maxSpread: 120, toleranceWindow: 120),
        );
        expect(regimes.isNotEmpty, isTrue);
        expect(regimes.first.nights.length, 3);
      },
    );

    test('Source priorities match manual > local_api > google_fit', () {
      expect(
        SleepService.getSourcePriority('manual'),
        greaterThan(SleepService.getSourcePriority('local_api')),
      );
      expect(
        SleepService.getSourcePriority('local_api'),
        greaterThan(SleepService.getSourcePriority('google_fit')),
      );
      expect(
        SleepService.getSourcePriority('google_fit'),
        greaterThan(SleepService.getSourcePriority('unknown')),
      );
    });

    test(
      'consolidateNightSessions protects newSession.id from being added to ignored list even if included in oldSessionIds',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        final seg1 = SleepSession(
          id: 'kyiv_reconsolidate_id',
          startTime: DateTime(2026, 9, 9, 23, 0),
          endTime: DateTime(2026, 9, 10, 3, 0),
          source: 'google_fit',
        );
        final seg2 = SleepSession(
          id: 'kyiv_seg_other',
          startTime: DateTime(2026, 9, 10, 3, 30),
          endTime: DateTime(2026, 9, 10, 7, 0),
          source: 'google_fit',
        );
        await notifier.updateSessionsFromIpc([seg1, seg2]);

        final consolidated = SleepSession(
          id: 'kyiv_reconsolidate_id', // same ID as seg1
          startTime: DateTime(2026, 9, 9, 23, 0),
          endTime: DateTime(2026, 9, 10, 7, 0),
          title: 'Reconsolidated Kyiv Session',
        );

        await notifier.consolidateNightSessions(
          oldSessionIds: ['kyiv_reconsolidate_id', 'kyiv_seg_other'],
          newSession: consolidated,
        );

        final state = container.read(sleepProvider);
        expect(state.sessions.length, 1);
        expect(state.sessions.first.id, 'kyiv_reconsolidate_id');
        expect(state.sessions.first.source, 'manual');

        final sleepService = container.read(sleepServiceProvider);
        final ignored = await sleepService.loadIgnoredSessionIds();
        expect(ignored.contains('kyiv_reconsolidate_id'), isFalse);
        expect(ignored.contains('kyiv_seg_other'), isTrue);
      },
    );
  });
}
