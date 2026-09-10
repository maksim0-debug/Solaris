import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/local_ipc_server_state.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/screens/sleep_screen.dart';
import 'package:solaris/services/local_ipc_service.dart';
import 'package:solaris/widgets/settings/api_settings_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/openapi_spec.dart';

class MockMonitorService extends MonitorService {
  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async => [];
}

class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState customSettings;
  FakeSettingsNotifier(this.customSettings);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': customSettings};
  }

  void updateState(SettingsState newState) {
    state = AsyncData({'all': newState});
  }
}

class FakeLocalIpcService extends LocalIpcService {
  final LocalIpcServerState initialState;
  FakeLocalIpcService(this.initialState);

  @override
  LocalIpcServerState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Defect 1: OpenApiSpec 503 Wiring and Sleep API Routes', () {
    test(
      'OpenAPI spec contains 503 response on Control and Sleep endpoints and schemas',
      () {
        final spec = OpenApiSpec.generateSpec(
          permissions: const ApiPermissionsConfig(),
        );
        final paths = spec['paths'] as Map<String, dynamic>;

        // 1. Health check must NOT contain 503
        expect(
          paths['/api/v1/health']['get']['responses'].containsKey('503'),
          isFalse,
        );

        // 2. Control endpoints MUST contain 503
        final controlEndpoints = [
          ('/api/v1/status', 'get'),
          ('/api/v1/solar', 'get'),
          ('/api/v1/presets', 'get'),
          ('/api/v1/monitors', 'get'),
          ('/api/v1/monitors/{slug}', 'get'),
          ('/api/v1/monitors/{slug}/brightness', 'post'),
          ('/api/v1/monitors/{slug}/temperature', 'post'),
          ('/api/v1/monitors/{slug}/game-mode', 'post'),
          ('/api/v1/control', 'post'),
          ('/api/v1/app-overrides', 'get'),
          ('/api/v1/app-overrides', 'post'),
          ('/api/v1/app-overrides/active', 'get'),
          ('/api/v1/app-overrides/reset-builtin', 'post'),
          ('/api/v1/app-overrides/{exe}', 'delete'),
          ('/api/v1/webhooks', 'get'),
          ('/api/v1/webhooks', 'post'),
          ('/api/v1/webhooks/events', 'get'),
          ('/api/v1/webhooks/dlq', 'get'),
          ('/api/v1/webhooks/dlq/retry', 'post'),
          ('/api/v1/webhooks/{id}', 'delete'),
          ('/api/v1/webhooks/{id}/test', 'post'),
        ];

        for (final (path, method) in controlEndpoints) {
          expect(
            paths[path][method]['responses'].containsKey('503'),
            isTrue,
            reason: 'Expected 503 on $method $path',
          );
        }

        // 3. Documented Sleep endpoints (both legacy and prefixed)
        final sleepEndpoints = [
          ('/api/sleep/status', 'get'),
          ('/api/sleep/status', 'post'),
          ('/api/v1/sleep/status', 'get'),
          ('/api/v1/sleep/status', 'post'),
          ('/api/sleep/sessions', 'get'),
          ('/api/sleep/sessions', 'post'),
          ('/api/v1/sleep/sessions', 'get'),
          ('/api/v1/sleep/sessions', 'post'),
        ];

        for (final (path, method) in sleepEndpoints) {
          expect(
            paths.containsKey(path),
            isTrue,
            reason: 'Expected path $path to be documented',
          );
          expect(
            paths[path].containsKey(method),
            isTrue,
            reason: 'Expected method $method on $path to be documented',
          );
          expect(
            paths[path][method]['responses'].containsKey('503'),
            isTrue,
            reason: 'Expected 503 response on $method $path',
          );
        }

        // 4. Sleep schemas registered in components.schemas
        final schemas = spec['components']['schemas'] as Map<String, dynamic>;
        expect(schemas.containsKey('SleepSession'), isTrue);
        expect(schemas.containsKey('SleepStatusResponse'), isTrue);
        expect(schemas.containsKey('SleepSessionsResponse'), isTrue);

        // 5. GET sleep sessions has ref to SleepSessionsResponse
        final sessionsGet =
            paths['/api/v1/sleep/sessions']['get']['responses']['200'];
        expect(
          sessionsGet['content']['application/json']['schema'][r'$ref'],
          '#/components/schemas/SleepSessionsResponse',
        );
      },
    );
  });

  group('Defect 2: LocalIpcService Subsystem Check & Race Conditions', () {
    setUp(() {
      HttpOverrides.global = null;
    });

    test(
      'start() does NOT bind port when neither subsystem is enabled',
      () async {
        final disabledSettings = SettingsState(
          isApiServerEnabled: false,
          isSleepIpcServerEnabled: false,
          isLocalIpcServerEnabled: false,
        );

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(disabledSettings),
            ),
            monitorServiceProvider.overrideWithValue(MockMonitorService()),
          ],
        );
        addTearDown(container.dispose);

        final ipcNotifier = container.read(localIpcServiceProvider.notifier);
        await ipcNotifier.start();

        final state = container.read(localIpcServiceProvider);
        expect(state.isRunning, isFalse);
        expect(state.port, isNull);
      },
    );

    test('start() binds port when only sleep subsystem is enabled', () async {
      final sleepSettings = SettingsState(
        isApiServerEnabled: false,
        isSleepIpcServerEnabled: true,
        apiServerPort: 45326,
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => FakeSettingsNotifier(sleepSettings),
          ),
          monitorServiceProvider.overrideWithValue(MockMonitorService()),
        ],
      );
      addTearDown(container.dispose);

      final ipcNotifier = container.read(localIpcServiceProvider.notifier);
      await ipcNotifier.start();

      final state = container.read(localIpcServiceProvider);
      expect(state.isRunning, isTrue);
      expect(state.port, isNotNull);

      await ipcNotifier.stop();
    });

    test(
      'stop() cancels in-flight start and leaves state isRunning=false',
      () async {
        final enabledSettings = SettingsState(
          isApiServerEnabled: true,
          isSleepIpcServerEnabled: false,
          apiServerPort: 45327,
        );

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(enabledSettings),
            ),
            monitorServiceProvider.overrideWithValue(MockMonitorService()),
          ],
        );
        addTearDown(container.dispose);

        final ipcNotifier = container.read(localIpcServiceProvider.notifier);
        // Start then immediately stop without awaiting start first
        final startFuture = ipcNotifier.start();
        await ipcNotifier.stop();
        await startFuture;

        final state = container.read(localIpcServiceProvider);
        expect(state.isRunning, isFalse);
      },
    );
  });

  group('Defect 3: WindowsPowerListener Subsystem Checks on Resume', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => '.',
          );
    });

    test(
      'handleSystemResume() does not restartServer or dispatch when both subsystems disabled',
      () async {
        final disabledSettings = SettingsState(
          isApiServerEnabled: false,
          isSleepIpcServerEnabled: false,
          isLocalIpcServerEnabled: false,
        );

        final dummyPosition = Position(
          latitude: 50.4495,
          longitude: 30.5253,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        final container = ProviderContainer(
          overrides: [
            locationStreamProvider.overrideWith(
              (ref) => Stream.value(dummyPosition),
            ),
            monitorServiceProvider.overrideWithValue(MockMonitorService()),
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(disabledSettings),
            ),
          ],
        );
        addTearDown(container.dispose);

        final powerListener = container.read(windowsPowerListenerProvider);
        await powerListener.handleSystemSuspend();
        expect(powerListener.isSuspended, isTrue);

        await powerListener.handleSystemResume();
        expect(powerListener.isSuspended, isFalse);

        // Verify local IPC server was NOT started
        final ipcState = container.read(localIpcServiceProvider);
        expect(ipcState.isRunning, isFalse);
      },
    );

    test(
      'handleSystemResume() restarts server when only Sleep IPC enabled',
      () async {
        final sleepOnlySettings = SettingsState(
          isApiServerEnabled: false,
          isSleepIpcServerEnabled: true,
          apiServerPort: 45328,
        );

        final dummyPosition = Position(
          latitude: 50.4495,
          longitude: 30.5253,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        final container = ProviderContainer(
          overrides: [
            locationStreamProvider.overrideWith(
              (ref) => Stream.value(dummyPosition),
            ),
            monitorServiceProvider.overrideWithValue(MockMonitorService()),
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(sleepOnlySettings),
            ),
          ],
        );
        addTearDown(container.dispose);

        final powerListener = container.read(windowsPowerListenerProvider);
        await powerListener.handleSystemSuspend();
        expect(powerListener.isSuspended, isTrue);

        await powerListener.handleSystemResume();
        expect(powerListener.isSuspended, isFalse);

        final ipcState = container.read(localIpcServiceProvider);
        expect(ipcState.isRunning, isTrue);

        await container.read(localIpcServiceProvider.notifier).stop();
      },
    );
  });

  group('Defect 4: WebhookService Cold Boot Subsystem Queue Check', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => '.',
          );
    });

    test(
      'WebhookService initializes isQueuePaused = true synchronously on cold boot when isApiServerEnabled is false',
      () {
        final disabledApiSettings = SettingsState(
          isApiServerEnabled: false,
          isSleepIpcServerEnabled: true,
        );

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(disabledApiSettings),
            ),
          ],
        );
        addTearDown(container.dispose);

        final webhookNotifier = container.read(webhookServiceProvider.notifier);
        // Zero delay: must be synchronously true immediately upon build!
        expect(webhookNotifier.isQueuePaused, isTrue);
      },
    );

    test(
      'WebhookService initializes isQueuePaused = false after loading when isApiServerEnabled is true',
      () async {
        final enabledApiSettings = SettingsState(
          isApiServerEnabled: true,
          isSleepIpcServerEnabled: true,
        );

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(enabledApiSettings),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Pre-resolve settings
        await container.read(settingsProvider.future);

        final webhookNotifier = container.read(webhookServiceProvider.notifier);
        // Allow async _initStorageAndListeners to finish
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(webhookNotifier.isQueuePaused, isFalse);
      },
    );
  });

  group('Defect 5: SleepScreen _portController and _portFocusNode Lifecycle', () {
    testWidgets(
      'SleepScreen renders TextField with FocusNode and protects user typing during rebuild',
      (WidgetTester tester) async {
        final settings = SettingsState(
          isSleepIpcServerEnabled: true,
          localIpcServerPort: 45325,
        );
        final fakeNotifier = FakeSettingsNotifier(settings);

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(() => fakeNotifier),
            monitorServiceProvider.overrideWithValue(MockMonitorService()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: Scaffold(body: SleepScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Expand the card
        final expandIcon = find.byIcon(LucideIcons.chevronDown);
        if (expandIcon.evaluate().isNotEmpty) {
          await tester.tap(expandIcon.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        // 2. Locate the port TextField
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsWidgets);

        // Find the specific port TextField with initial value 45325
        final portFieldFinder = find.widgetWithText(TextField, '45325');
        expect(portFieldFinder, findsOneWidget);

        // 3. Focus and enter text
        await tester.tap(portFieldFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(portFieldFinder, '45329');
        await tester.pump();

        // 4. Trigger an external rebuild while user is still focused
        fakeNotifier.updateState(settings.copyWith(localIpcServerPort: 45325));
        await tester.pump();

        // 5. Verify user typing '45329' was NOT overwritten because field has focus!
        expect(find.widgetWithText(TextField, '45329'), findsOneWidget);

        await container.read(localIpcServiceProvider.notifier).stop();
      },
    );
  });

  group(
    'Defect 6: ApiSettingsCard Active Port Fallback Display & Port Range Validation',
    () {
      testWidgets(
        'ApiSettingsCard displays active bound port when fallback occurs',
        (WidgetTester tester) async {
          final settings = SettingsState(
            isApiServerEnabled: true,
            apiServerPort: 45321,
          );

          final container = ProviderContainer(
            overrides: [
              settingsProvider.overrideWith(
                () => FakeSettingsNotifier(settings),
              ),
              localIpcServiceProvider.overrideWith(
                () => FakeLocalIpcService(
                  const LocalIpcServerState(isRunning: true, port: 45322),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: Locale('en'),
                home: Scaffold(
                  body: SingleChildScrollView(child: ApiSettingsCard()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Must display actual active port 45322 in status text rather than configured 45321
          expect(find.textContaining('45322'), findsOneWidget);
        },
      );

      testWidgets(
        'SleepScreen port submission rejects invalid port < 1024 and > 65535',
        (WidgetTester tester) async {
          final settings = SettingsState(
            isSleepIpcServerEnabled: true,
            localIpcServerPort: 45321,
          );
          final fakeNotifier = FakeSettingsNotifier(settings);

          final container = ProviderContainer(
            overrides: [
              settingsProvider.overrideWith(() => fakeNotifier),
              monitorServiceProvider.overrideWithValue(MockMonitorService()),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: Locale('en'),
                home: Scaffold(body: SleepScreen()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final expandIcon = find.byIcon(LucideIcons.chevronDown);
          if (expandIcon.evaluate().isNotEmpty) {
            await tester.tap(expandIcon.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }

          final portField = find.widgetWithText(TextField, '45321');
          expect(portField, findsOneWidget);

          // Submit invalid port 80 (privileged < 1024)
          await tester.tap(portField);
          await tester.pump();
          await tester.enterText(portField, '80');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();

          // Should revert back to 45321
          expect(find.widgetWithText(TextField, '45321'), findsOneWidget);

          await container.read(localIpcServiceProvider.notifier).stop();
        },
      );
    },
  );
}
