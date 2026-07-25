import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/local_ipc_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/websocket_service.dart';
import 'package:solaris/services/windows_power_listener.dart';

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

  group('Phase 5 E2E Verification: WebSocket Engine & Windows Power Management', () {
    late ProviderContainer container;
    late LocalIpcService ipcService;
    late int port;
    const String authToken = 'test-token-123';

    setUp(() async {
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
        apiAccessToken: authToken,
      );

      container = ProviderContainer(
        overrides: [
          locationStreamProvider.overrideWith((ref) => Stream.value(dummyPosition)),
          monitorServiceProvider.overrideWithValue(MockMonitorService()),
          settingsProvider.overrideWith(() => FakeSettingsNotifier(testSettings)),
        ],
      );

      ipcService = container.read(localIpcServiceProvider.notifier);
      await ipcService.start();
      port = container.read(localIpcServiceProvider).port!;
    });

    tearDown(() async {
      await ipcService.stop();
      container.dispose();
    });

    test('1. WebSocket Connection & Initial Snapshot Handshake', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());

      final snapshotCompleter = Completer<Map<String, dynamic>>();
      final stream = clientSocket.asBroadcastStream();

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'snapshot' && !snapshotCompleter.isCompleted) {
            snapshotCompleter.complete(jsonMap);
          }
        }
      });

      final snapshot = await snapshotCompleter.future.timeout(const Duration(seconds: 5));
      expect(snapshot['type'], equals('snapshot'));
      expect(snapshot['data'], isA<Map<String, dynamic>>());
      expect(snapshot['data']['version'], isNotNull);

      await clientSocket.close();
    });

    test('2. WebSocket App Ping / Pong Protocol', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());

      final pongCompleter = Completer<Map<String, dynamic>>();
      final stream = clientSocket.asBroadcastStream();

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'pong' && !pongCompleter.isCompleted) {
            pongCompleter.complete(jsonMap);
          }
        }
      });

      clientSocket.add(jsonEncode({'type': 'ping'}));
      final pong = await pongCompleter.future.timeout(const Duration(seconds: 5));

      expect(pong['type'], equals('pong'));
      expect(pong['timestamp'], isNotNull);

      await clientSocket.close();
    });

    test('3. Selective Subscriptions Protocol (type: subscribe)', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());

      final subAckCompleter = Completer<Map<String, dynamic>>();
      final stream = clientSocket.asBroadcastStream();

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'subscribed' && !subAckCompleter.isCompleted) {
            subAckCompleter.complete(jsonMap);
          }
        }
      });

      clientSocket.add(jsonEncode({
        'type': 'subscribe',
        'modules': ['monitors', 'solar'],
      }));

      final ack = await subAckCompleter.future.timeout(const Duration(seconds: 5));
      expect(ack['type'], equals('subscribed'));
      expect(ack['active_modules'], contains('monitors'));
      expect(ack['active_modules'], contains('solar'));

      await clientSocket.close();
    });

    test('4. WebSocket Command Execution with Correlation ID (cmd_id)', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());

      final cmdCompleter = Completer<Map<String, dynamic>>();
      final stream = clientSocket.asBroadcastStream();

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'response' && jsonMap['cmd_id'] == 'req-phase5-202') {
            cmdCompleter.complete(jsonMap);
          }
        }
      });

      clientSocket.add(jsonEncode({
        'type': 'command',
        'cmd_id': 'req-phase5-202',
        'action': 'set_auto_brightness',
        'enabled': true,
      }));

      final response = await cmdCompleter.future.timeout(const Duration(seconds: 5));
      expect(response['type'], equals('response'));
      expect(response['cmd_id'], equals('req-phase5-202'));
      expect(response['status'], equals('ok'));
      expect(response['action'], equals('set_auto_brightness'));

      await clientSocket.close();
    });

    test('5. CSWSH Guard & Untrusted Origin Rejection when Auth is required', () async {
      final WebSocketService wsService = container.read(webSocketServiceProvider);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      try {
        final router = ApiRouter()..expectedToken = 'secret-token-123';
        server.listen((req) async {
          await wsService.handleUpgrade(
            req,
            router: router,
            isLanEnabled: false,
          );
        });

        final client = HttpClient();
        final req = await client.get('localhost', server.port, '/api/v1/ws');
        req.headers.set('Origin', 'https://malicious-site.com');
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.unauthorized));
        client.close();
      } finally {
        await server.close(force: true);
      }
    });

    test('6. WindowsPowerListener Suspend and Resume Workflow', () async {
      final WindowsPowerListener listener = container.read(windowsPowerListenerProvider);
      expect(listener.isSuspended, isFalse);

      // Handle Suspend (S3/S4)
      await listener.handleSystemSuspend();
      expect(listener.isSuspended, isTrue);

      // Handle Resume
      await listener.handleSystemResume();
      expect(listener.isSuspended, isFalse);
    });

    test('7. WindowsPowerListener Hardware Error & Display Change Events', () async {
      final WindowsPowerListener listener = container.read(windowsPowerListenerProvider);

      expect(() => listener.handleHardwareError('I2C Bus NACK Timeout'), returnsNormally);
      expect(() => listener.handleDisplayChange(), returnsNormally);
    });

    test('8. WebhookEventType enum includes Phase 5 system events', () {
      expect(WebhookEventType.onSystemResume.wireName, equals('on_system_resume'));
      expect(WebhookEventType.onHardwareError.wireName, equals('on_hardware_error'));
    });
  });
}
