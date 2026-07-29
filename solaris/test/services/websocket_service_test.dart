import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/local_ipc_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/websocket_service.dart';

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

class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState customSettings;
  FakeSettingsNotifier(this.customSettings);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': customSettings};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    final testSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-token-123',
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith(
          (ref) => Stream.value(dummyPosition),
        ),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => FakeSettingsNotifier(testSettings)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'WebSocketService initializes correctly with connectedClientsCount 0',
    () {
      final WebSocketService wsService = container.read(
        webSocketServiceProvider,
      );
      expect(wsService.connectedClientsCount, equals(0));
    },
  );

  test(
    'WebSocketService broadcastModule and closeAll complete without errors when no clients',
    () {
      final WebSocketService wsService = container.read(
        webSocketServiceProvider,
      );
      expect(
        () => wsService.broadcastModule('solar', {'elevation': 12.5}),
        returnsNormally,
      );
      expect(
        () => wsService.broadcastEvent('on_sunset', {'test': true}),
        returnsNormally,
      );
      expect(() => wsService.closeAll(), returnsNormally);
    },
  );

  test(
    'WebSocket Upgrade, Snapshot hand-shake and Echo Ping/Pong over LocalIpcService HTTP Server',
    () async {
      final LocalIpcService ipcService = container.read(
        localIpcServiceProvider.notifier,
      );
      await ipcService.start();

      final state = container.read(localIpcServiceProvider);
      expect(state.isRunning, isTrue);
      final port = state.port!;

      final wsUri = Uri.parse(
        'ws://127.0.0.1:$port/api/v1/ws?token=test-token-123',
      );
      final clientSocket = await WebSocket.connect(wsUri.toString());

      final snapshotCompleter = Completer<Map<String, dynamic>>();
      final pongCompleter = Completer<Map<String, dynamic>>();

      final stream = clientSocket.asBroadcastStream();

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'snapshot' && !snapshotCompleter.isCompleted) {
            snapshotCompleter.complete(jsonMap);
          } else if (jsonMap['type'] == 'pong' && !pongCompleter.isCompleted) {
            pongCompleter.complete(jsonMap);
          }
        }
      });

      final snapshot = await snapshotCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(snapshot['type'], equals('snapshot'));
      expect(snapshot.containsKey('data'), isTrue);

      // Send Ping frame
      clientSocket.add(jsonEncode({'type': 'ping'}));
      final pongResp = await pongCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(pongResp['type'], equals('pong'));

      await clientSocket.close();
      await ipcService.stop();
    },
  );

  test('WebSocket Command Execution with Correlation ID (cmd_id)', () async {
    final LocalIpcService ipcService = container.read(
      localIpcServiceProvider.notifier,
    );
    await ipcService.start();

    final port = container.read(localIpcServiceProvider).port!;
    final clientSocket = await WebSocket.connect(
      'ws://127.0.0.1:$port/api/v1/ws?token=test-token-123',
    );

    final cmdCompleter = Completer<Map<String, dynamic>>();
    final stream = clientSocket.asBroadcastStream();

    stream.listen((message) {
      if (message is String) {
        final jsonMap = jsonDecode(message) as Map<String, dynamic>;
        if (jsonMap['type'] == 'response' &&
            jsonMap['cmd_id'] == 'req-test-101') {
          cmdCompleter.complete(jsonMap);
        }
      }
    });

    clientSocket.add(
      jsonEncode({
        'type': 'command',
        'cmd_id': 'req-test-101',
        'action': 'set_auto_brightness',
        'enabled': false,
      }),
    );

    final response = await cmdCompleter.future.timeout(
      const Duration(seconds: 5),
    );
    expect(response['type'], equals('response'));
    expect(response['cmd_id'], equals('req-test-101'));
    expect(response['status'], equals('ok'));

    await clientSocket.close();
    await ipcService.stop();
  });
}
