import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
  });

  group('Sleep Deletion and Ignored List Tests', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer();
      final ignoredFile = File('./ignored_sleep_sessions.json');
      if (await ignoredFile.exists()) {
        await ignoredFile.delete();
      }
      final cacheFile = File('./sleep_data_cache.json');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    });

    tearDown(() {
      container.dispose();
    });

    test('deleteSessions removes sessions from state', () async {
      final notifier = container.read(sleepProvider.notifier);

      final session1 = SleepSession(
        id: 's1',
        startTime: DateTime(2026, 7, 25, 18, 4),
        endTime: DateTime(2026, 7, 26, 0, 18),
        source: 'local_api',
      );
      final session2 = SleepSession(
        id: 's2',
        startTime: DateTime(2026, 7, 26, 1, 0),
        endTime: DateTime(2026, 7, 26, 9, 0),
        source: 'local_api',
      );

      await notifier.updateSessionsFromIpc([session1, session2]);
      expect(container.read(sleepProvider).sessions.length, 2);

      await notifier.deleteSession('s1', doNotSync: false);

      final state = container.read(sleepProvider);
      expect(state.sessions.length, 1);
      expect(state.sessions.first.id, 's2');
    });

    test('deleteSessions with doNotSync=true blacklists session from future syncs', () async {
      final notifier = container.read(sleepProvider.notifier);
      final sleepService = SleepService();

      final session1 = SleepSession(
        id: 'blacklisted_s1',
        startTime: DateTime(2026, 7, 25, 18, 4),
        endTime: DateTime(2026, 7, 26, 0, 18),
        source: 'google_fit',
      );

      await notifier.updateSessionsFromIpc([session1]);
      expect(container.read(sleepProvider).sessions.length, 1);

      // Delete with doNotSync = true
      await notifier.deleteSession('blacklisted_s1', doNotSync: true);

      expect(container.read(sleepProvider).sessions, isEmpty);

      // Check that it's in the ignored list
      final ignored = await sleepService.loadIgnoredSessionIds();
      expect(ignored.contains('blacklisted_s1'), isTrue);

      // Try updating from IPC with the same blacklisted session again
      await notifier.updateSessionsFromIpc([session1]);
      // Should remain empty because session is blacklisted
      expect(container.read(sleepProvider).sessions, isEmpty);
    });

    test('deleteSessions with doNotSync=false allows session in future syncs', () async {
      final notifier = container.read(sleepProvider.notifier);

      final session1 = SleepSession(
        id: 'resyncable_s1',
        startTime: DateTime(2026, 7, 25, 18, 4),
        endTime: DateTime(2026, 7, 26, 0, 18),
        source: 'google_fit',
      );

      await notifier.updateSessionsFromIpc([session1]);
      await notifier.deleteSession('resyncable_s1', doNotSync: false);

      expect(container.read(sleepProvider).sessions, isEmpty);

      // Try updating from IPC with the session again
      await notifier.updateSessionsFromIpc([session1]);
      // Should be re-added
      expect(container.read(sleepProvider).sessions.length, 1);
    });
  });
}
