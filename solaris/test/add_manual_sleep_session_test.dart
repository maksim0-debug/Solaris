import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers/sleep_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
  });

  group('Manual Sleep Session Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('addManualSession adds manual sleep session to state', () async {
      final notifier = container.read(sleepProvider.notifier);

      final manualSession = SleepSession(
        id: 'manual_1',
        startTime: DateTime(2026, 7, 25, 23, 0),
        endTime: DateTime(2026, 7, 26, 7, 0),
        title: 'Kyiv Night Sleep',
        description: 'Added manually',
        source: 'manual',
      );

      await notifier.addManualSession(manualSession);

      final state = container.read(sleepProvider);
      expect(state.sessions.length, 1);
      expect(state.sessions.first.id, 'manual_1');
      expect(state.sessions.first.source, 'manual');
      expect(state.sessions.first.title, 'Kyiv Night Sleep');
    });

    test('Manual session overrides overlapping Google Fit session', () async {
      final notifier = container.read(sleepProvider.notifier);

      // 1. Add Google Fit Session
      final googleFitSession = SleepSession(
        id: 'google_fit_1',
        startTime: DateTime(2026, 7, 25, 23, 15),
        endTime: DateTime(2026, 7, 26, 6, 45),
        title: 'Google Fit Sleep',
        source: 'google_fit',
      );

      await notifier.updateSessionsFromIpc([googleFitSession]);
      expect(container.read(sleepProvider).sessions.length, 1);

      // 2. Add overlapping Manual Session
      final manualSession = SleepSession(
        id: 'manual_2',
        startTime: DateTime(2026, 7, 25, 23, 0),
        endTime: DateTime(2026, 7, 26, 7, 0),
        title: 'Kyiv Accurate Manual Sleep',
        source: 'manual',
      );

      await notifier.addManualSession(manualSession);

      // 3. Verify Google Fit session is discarded due to overlap, and manual session remains
      final state = container.read(sleepProvider);
      expect(state.sessions.length, 1);
      expect(state.sessions.first.id, 'manual_2');
      expect(state.sessions.first.source, 'manual');
    });

    test('Manual session persists on disk even after SleepService.fetchSleepData', () async {
      final notifier = container.read(sleepProvider.notifier);
      final service = container.read(sleepServiceProvider);

      final manualSession = SleepSession(
        id: 'manual_persisted_1',
        startTime: DateTime(2026, 7, 25, 23, 0),
        endTime: DateTime(2026, 7, 26, 7, 0),
        title: 'Kyiv Persisted Sleep',
        source: 'manual',
      );

      await notifier.addManualSession(manualSession);

      // Verify it's cached on disk initially
      final cachedInitial = await service.loadCachedSleepData();
      expect(cachedInitial.map((s) => s.id), contains('manual_persisted_1'));

      // Perform fetchSleepData (which falls back to cache or merges network data)
      final result = await service.fetchSleepData(forceNetwork: false);
      expect(result.sessions.map((s) => s.id), contains('manual_persisted_1'));

      // Verify manual session is STILL present in disk cache after fetchSleepData
      final cachedAfter = await service.loadCachedSleepData();
      expect(cachedAfter.map((s) => s.id), contains('manual_persisted_1'));
    });
  });
}

