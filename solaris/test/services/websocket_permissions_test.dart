import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';

class MockMonitorService extends MonitorService {
  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1\Monitor0',
        name: 'LG 27GL850',
        friendlyName: 'LG UltraGear',
        deviceName: r'\\.\DISPLAY1\Monitor0',
        deviceIdHash: 'a1f9b2c3',
        isPrimary: true,
        realBrightness: 80,
        realTemperature: 5000,
      ),
    ];
  }
}

class TestSettingsNotifier extends SettingsNotifier {
  final SettingsState initialState;
  TestSettingsNotifier(this.initialState);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': initialState};
  }

  void updatePermissions(ApiPermissionsConfig newPermissions) {
    state = AsyncData({'all': state.value!['all']!.copyWith(apiPermissions: newPermissions)});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyPosition = Position(
    latitude: 50.4501,
    longitude: 30.5234,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  late ProviderContainer container;

  setUp(() {
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('Phase 2 WebSocket: Initial Snapshot filtering according to API permissions', () async {
    final customPermissions = const ApiPermissionsConfig(
      allowReadSolar: false,
      allowReadWeather: false,
      allowReadMonitors: true,
      allowReadSleep: false,
      allowReadCircadian: true,
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: customPermissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final snapshotCompleter = Completer<Map<String, dynamic>>();
    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'snapshot') {
          snapshotCompleter.complete(jsonMap);
        }
      }
    });

    final snapshotMsg = await snapshotCompleter.future.timeout(const Duration(seconds: 5));
    final data = snapshotMsg['data'] as Map<String, dynamic>;

    expect(data.containsKey('solar'), isFalse);
    expect(data.containsKey('weather'), isFalse);
    expect(data.containsKey('monitors'), isTrue);

    final automation = data['automation'] as Map<String, dynamic>;
    expect(automation.keys.any((k) => k.startsWith('weather_')), isFalse);

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Selective subscription denial for disabled read flags', () async {
    final customPermissions = const ApiPermissionsConfig(
      allowReadSleep: false,
      allowReadMonitors: true,
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: customPermissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final deniedCompleter = Completer<Map<String, dynamic>>();
    final subscribedCompleter = Completer<Map<String, dynamic>>();

    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'subscription_denied') {
          deniedCompleter.complete(jsonMap);
        } else if (jsonMap['type'] == 'subscribed') {
          subscribedCompleter.complete(jsonMap);
        }
      }
    });

    clientSocket.add(jsonEncode({
      'type': 'subscribe',
      'modules': ['monitors', 'sleep'],
    }));

    final deniedMsg = await deniedCompleter.future.timeout(const Duration(seconds: 5));
    expect(deniedMsg['type'], equals('subscription_denied'));
    expect(deniedMsg['module'], equals('sleep'));

    final subMsg = await subscribedCompleter.future.timeout(const Duration(seconds: 5));
    final active = (subMsg['active_modules'] as List<dynamic>).cast<String>();
    expect(active, contains('monitors'));
    expect(active, isNot(contains('sleep')));

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Runtime ACL subscription audit notifies client with subscription_revoked', () async {
    final notifier = TestSettingsNotifier(SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: const ApiPermissionsConfig(allowReadSleep: true),
    ));

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => notifier),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final revokedCompleter = Completer<Map<String, dynamic>>();

    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'subscription_revoked') {
          revokedCompleter.complete(jsonMap);
        }
      }
    });

    clientSocket.add(jsonEncode({
      'type': 'subscribe',
      'modules': ['sleep'],
    }));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Toggle allowReadSleep to false in runtime
    notifier.updatePermissions(const ApiPermissionsConfig(allowReadSleep: false));

    final revokedMsg = await revokedCompleter.future.timeout(const Duration(seconds: 5));
    expect(revokedMsg['type'], equals('subscription_revoked'));
    expect(revokedMsg['module'], equals('sleep'));

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Command privilege escalation attempt is rejected', () async {
    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: const ApiPermissionsConfig(),
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final responseCompleter = Completer<Map<String, dynamic>>();

    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'response') {
          responseCompleter.complete(jsonMap);
        }
      }
    });

    clientSocket.add(jsonEncode({
      'type': 'command',
      'cmd_id': 'cmd-esc-001',
      'action': 'set_brightness',
      'value': 50,
      'apiPermissions': {'isReadOnly': false},
    }));

    final resp = await responseCompleter.future.timeout(const Duration(seconds: 5));
    expect(resp['type'], equals('response'));
    expect(resp['error'], equals('Forbidden'));
    expect(resp['message'], contains('strictly prohibited'));

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Complete isolation when all read permissions are disabled', () async {
    final noReadPermissions = const ApiPermissionsConfig(
      allowReadMonitors: false,
      allowReadSolar: false,
      allowReadWeather: false,
      allowReadSleep: false,
      allowReadCircadian: false,
      allowedCategories: {},
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: noReadPermissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final snapshotCompleter = Completer<Map<String, dynamic>>();
    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'snapshot') {
          snapshotCompleter.complete(jsonMap);
        }
      }
    });

    final snapshotMsg = await snapshotCompleter.future.timeout(const Duration(seconds: 5));
    final data = snapshotMsg['data'] as Map<String, dynamic>;

    expect(data.containsKey('solar'), isFalse);
    expect(data.containsKey('weather'), isFalse);
    expect(data.containsKey('monitors'), isFalse);
    expect(data.containsKey('sleep'), isFalse);

    final automation = data['automation'] as Map<String, dynamic>;
    expect(automation.containsKey('weather_brightness_adjustment'), isFalse);
    expect(automation.containsKey('smart_circadian'), isFalse);
    expect(automation.containsKey('game_mode'), isFalse);
    expect(automation.containsKey('map_animations'), isFalse);

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Dynamic broadcast filtering masks smart_circadian sleep pressure and debt', () async {
    final permissions = const ApiPermissionsConfig(
      allowReadCircadian: true,
      allowReadSleep: false,
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: permissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final snapshotCompleter = Completer<void>();
    final updateCompleter = Completer<Map<String, dynamic>>();

    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'snapshot') {
          snapshotCompleter.complete();
        } else if (jsonMap['type'] == 'update' && jsonMap['module'] == 'smart_circadian') {
          updateCompleter.complete(jsonMap);
        }
      }
    });

    await snapshotCompleter.future.timeout(const Duration(seconds: 5));

    final wsService = container.read(webSocketServiceProvider);
    wsService.broadcastModule('smart_circadian', {
      'enabled': true,
      'phase': 'day',
      'sleep_pressure': 0.75,
      'sleep_debt': 1.5,
      'submodules': {
        'circadian_master': true,
        'sleep_pressure_master': true,
        'sleep_debt_master': true,
      }
    });

    final updateMsg = await updateCompleter.future.timeout(const Duration(seconds: 5));
    final data = updateMsg['data'] as Map<String, dynamic>;

    expect(data.containsKey('sleep_pressure'), isFalse);
    expect(data.containsKey('sleep_debt'), isFalse);
    expect(data['submodules'].containsKey('sleep_pressure_master'), isFalse);
    expect(data['submodules'].containsKey('sleep_debt_master'), isFalse);
    expect(data['submodules']['circadian_master'], isTrue);

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Event broadcast rejected when category is disabled', () async {
    final permissions = const ApiPermissionsConfig(
      allowedCategories: {ApiActionCategory.monitors}, // system category omitted
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: permissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final snapshotCompleter = Completer<void>();
    bool receivedEvent = false;

    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'snapshot') {
          snapshotCompleter.complete();
        } else if (jsonMap['type'] == 'event' && jsonMap['event'] == 'on_hardware_error') {
          receivedEvent = true;
        }
      }
    });

    await snapshotCompleter.future.timeout(const Duration(seconds: 5));

    final wsService = container.read(webSocketServiceProvider);
    wsService.broadcastEvent('on_hardware_error', {'error': 'DDC/CI timeout'});

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(receivedEvent, isFalse);

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Command ACL rejects action when category is not allowed or read-only', () async {
    final permissions = const ApiPermissionsConfig(
      isReadOnly: false,
      allowedCategories: {ApiActionCategory.monitors}, // sleep category omitted
    );

    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: permissions,
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());

    final responseCompleter = Completer<Map<String, dynamic>>();
    clientSocket.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'response') {
          responseCompleter.complete(jsonMap);
        }
      }
    });

    clientSocket.add(jsonEncode({
      'type': 'command',
      'cmd_id': 'cmd-dis-002',
      'action': 'push_sleep_status',
      'is_sleeping': true,
    }));

    final resp = await responseCompleter.future.timeout(const Duration(seconds: 5));
    expect(resp['type'], equals('response'));
    expect(resp['error'], equals('Forbidden'));
    expect(resp['status'], equals('error'));

    await clientSocket.close();
    await ipcService.stop();
  });

  test('Phase 2 WebSocket: Zero Memory Leak & Client Disconnect Cleanup', () async {
    final initialSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-ws-token-123',
      apiPermissions: const ApiPermissionsConfig(),
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
    );

    final ipcService = container.read(localIpcServiceProvider.notifier);
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final wsService = container.read(webSocketServiceProvider);
    expect(wsService.connectedClientsCount, equals(0));

    final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=test-ws-token-123');
    final clientSocket = await WebSocket.connect(wsUri.toString());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(wsService.connectedClientsCount, equals(1));

    await clientSocket.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(wsService.connectedClientsCount, equals(0));

    await ipcService.stop();
  });
}
