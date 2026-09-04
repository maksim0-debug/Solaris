import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers/sleep_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.'; // Use current directory for temp storage in tests
          },
        );
  });

  group('Sleep Sessions Deduplication Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state has no sessions', () {
      final state = container.read(sleepProvider);
      expect(state.sessions, isEmpty);
    });

    test(
      'Adding local_api sessions works and orders them by startTime descending',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        final session1 = SleepSession(
          id: 'session_1',
          startTime: DateTime(2026, 7, 16, 23, 0),
          endTime: DateTime(2026, 7, 17, 7, 0),
          title: 'Sleep 1',
          source: 'local_api',
        );

        final session2 = SleepSession(
          id: 'session_2',
          startTime: DateTime(2026, 7, 17, 23, 30),
          endTime: DateTime(2026, 7, 18, 7, 30),
          title: 'Sleep 2',
          source: 'local_api',
        );

        await notifier.updateSessionsFromIpc([session1, session2]);

        final state = container.read(sleepProvider);
        expect(state.sessions.length, 2);
        expect(state.sessions[0].id, 'session_2'); // Newest first
        expect(state.sessions[1].id, 'session_1');
      },
    );

    test(
      'Local API session overwrites/removes overlapping Google Fit session',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Add Google Fit session
        final fitSession = SleepSession(
          id: 'fit_session_1',
          startTime: DateTime(2026, 7, 16, 23, 15),
          endTime: DateTime(2026, 7, 17, 6, 45),
          title: 'Google Fit Sleep',
          source: 'google_fit',
        );

        await notifier.updateSessionsFromIpc([fitSession]);
        expect(container.read(sleepProvider).sessions.length, 1);
        expect(container.read(sleepProvider).sessions[0].id, 'fit_session_1');

        // 2. Add overlapping Local API session
        final localSession = SleepSession(
          id: 'local_session_1',
          startTime: DateTime(2026, 7, 16, 23, 0),
          endTime: DateTime(2026, 7, 17, 7, 0),
          title: 'Accurate Sleep',
          source: 'local_api',
        );

        await notifier.updateSessionsFromIpc([localSession]);

        // 3. Verify Google Fit session is removed because of overlap, and local is added
        final state = container.read(sleepProvider);
        expect(state.sessions.length, 1);
        expect(state.sessions[0].id, 'local_session_1');
      },
    );

    test(
      'Google Fit session is discarded if it overlaps with an existing Local API session',
      () async {
        final notifier = container.read(sleepProvider.notifier);

        // 1. Add Local API session
        final localSession = SleepSession(
          id: 'local_session_1',
          startTime: DateTime(2026, 7, 16, 23, 0),
          endTime: DateTime(2026, 7, 17, 7, 0),
          title: 'Accurate Sleep',
          source: 'local_api',
        );

        await notifier.updateSessionsFromIpc([localSession]);
        expect(container.read(sleepProvider).sessions.length, 1);

        // 2. Try to add overlapping Google Fit session (via a merge simulating Google Fit sync)
        final fitSession = SleepSession(
          id: 'fit_session_1',
          startTime: DateTime(2026, 7, 16, 23, 30),
          endTime: DateTime(2026, 7, 17, 6, 30),
          title: 'Overlapping Google Fit Sleep',
          source: 'google_fit',
        );

        await notifier.updateSessionsFromIpc([fitSession]);

        // 3. Verify Google Fit session is discarded, only local remains
        final state = container.read(sleepProvider);
        expect(state.sessions.length, 1);
        expect(state.sessions[0].id, 'local_session_1');
      },
    );

    test('Non-overlapping sessions from both sources are kept', () async {
      final notifier = container.read(sleepProvider.notifier);

      final localSession = SleepSession(
        id: 'local_session_1',
        startTime: DateTime(2026, 7, 16, 23, 0),
        endTime: DateTime(2026, 7, 17, 7, 0),
        title: 'Accurate Sleep',
        source: 'local_api',
      );

      final fitSession = SleepSession(
        id: 'fit_session_2',
        startTime: DateTime(2026, 7, 15, 22, 0),
        endTime: DateTime(2026, 7, 16, 6, 0),
        title: 'Previous Fit Sleep',
        source: 'google_fit',
      );

      await notifier.updateSessionsFromIpc([localSession, fitSession]);

      final state = container.read(sleepProvider);
      expect(state.sessions.length, 2);
      expect(state.sessions[0].id, 'local_session_1');
      expect(state.sessions[1].id, 'fit_session_2');
    });
  });
}
