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
        realBrightness: 85,
        realTemperature: 5500,
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

  group('Phase 5 Deep Zero-Trust Verification: Edge Cases & Complete Coverage', () {
    late ProviderContainer container;
    late LocalIpcService ipcService;
    late int port;
    const String authToken = 'deep-zero-trust-token-999';

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

    test('1. WebSocket Subprotocol Auth (Sec-WebSocket-Protocol: bearer.<token>)', () async {
      final client = HttpClient();
      final request = await client.openUrl('GET', Uri.parse('http://127.0.0.1:$port/api/v1/ws'));
      request.headers.set('Connection', 'Upgrade');
      request.headers.set('Upgrade', 'websocket');
      request.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
      request.headers.set('Sec-WebSocket-Version', '13');
      request.headers.set('Sec-WebSocket-Protocol', 'bearer.$authToken');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.switchingProtocols));
      
      final socket = await response.detachSocket();
      await socket.close();
      client.close();
    });

    test('2. WebSocket Subprotocol Auth with Invalid Token is Rejected (401 Unauthorized)', () async {
      final client = HttpClient();
      final request = await client.openUrl('GET', Uri.parse('http://127.0.0.1:$port/api/v1/ws'));
      request.headers.set('Connection', 'Upgrade');
      request.headers.set('Upgrade', 'websocket');
      request.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
      request.headers.set('Sec-WebSocket-Version', '13');
      request.headers.set('Sec-WebSocket-Protocol', 'bearer.invalid-token-xyz');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.unauthorized));
      client.close();
    });

    test('3. Selective Subscriptions Module Filter (client receives only subscribed modules)', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());
      final stream = clientSocket.asBroadcastStream();

      final subAckCompleter = Completer<void>();
      final receivedModules = <String>[];

      stream.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'subscribed') {
            subAckCompleter.complete();
          } else if (jsonMap['type'] == 'update') {
            receivedModules.add(jsonMap['module'] as String);
          }
        }
      });

      // Subscribe ONLY to 'solar'
      clientSocket.add(jsonEncode({
        'type': 'subscribe',
        'modules': ['solar'],
      }));

      await subAckCompleter.future.timeout(const Duration(seconds: 3));

      // Trigger broadcasts for both 'solar' and 'monitors'
      final wsService = container.read(webSocketServiceProvider);
      wsService.broadcastModule('solar', {'elevation': 45.0});
      wsService.broadcastModule('monitors', [{'id': 'mon-1'}]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(receivedModules, contains('solar'));
      expect(receivedModules, isNot(contains('monitors')));

      await clientSocket.close();
    });

    test('4. WebSocket Max Clients Limit Enforcement (20 max connections -> 503 Service Unavailable)', () async {
      final wsService = container.read(webSocketServiceProvider);
      final activeSockets = <WebSocket>[];

      for (int i = 0; i < WebSocketService.maxClients; i++) {
        final ws = await WebSocket.connect('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
        activeSockets.add(ws);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(wsService.connectedClientsCount, equals(WebSocketService.maxClients));

      // Attempt 21st connection with Upgrade headers
      final client = HttpClient();
      final req = await client.openUrl('GET', Uri.parse('http://127.0.0.1:$port/api/v1/ws?token=$authToken'));
      req.headers.set('Connection', 'Upgrade');
      req.headers.set('Upgrade', 'websocket');
      req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
      req.headers.set('Sec-WebSocket-Version', '13');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.serviceUnavailable));
      client.close();

      for (final socket in activeSockets) {
        await socket.close();
      }
    });

    test('5. Slow Consumer OOM Protection drops lagging client when buffer exceeds 512 KB', () async {
      final wsService = container.read(webSocketServiceProvider);
      final clientSocket = await WebSocket.connect('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(wsService.connectedClientsCount, equals(1));

      // Create a payload larger than 512 KB
      final hugePayload = List.generate(530 * 1024, (index) => 'A').join();
      wsService.broadcastModule('solar', {'large_data': hugePayload});

      // Second broadcast triggers Slow Consumer disconnection (> 512 KB pending)
      wsService.broadcastModule('solar', {'trigger': 'disconnect'});

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(wsService.connectedClientsCount, equals(0));

      await clientSocket.close();
    });

    test('6. Full Cycle: Hardware Error Event Propagation to WebSocket listeners', () async {
      final wsService = container.read(webSocketServiceProvider);

      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final eventCompleter = Completer<Map<String, dynamic>>();

      final subscription = clientSocket.listen((message) {
        if (message is String) {
          final jsonMap = jsonDecode(message) as Map<String, dynamic>;
          if (jsonMap['type'] == 'event' && jsonMap['event'] == 'on_hardware_error') {
            if (!eventCompleter.isCompleted) {
              eventCompleter.complete(jsonMap);
            }
          }
        }
      });

      // Dispatch hardware error
      wsService.broadcastEvent('on_hardware_error', {
        'detail': 'DDC/CI I2C Bus Fault on Display 1',
      });

      final receivedEvent = await eventCompleter.future.timeout(const Duration(seconds: 3));
      expect(receivedEvent['type'], equals('event'));
      expect(receivedEvent['event'], equals('on_hardware_error'));
      expect(receivedEvent['data']['detail'], contains('DDC/CI I2C Bus Fault'));

      await subscription.cancel();
      await clientSocket.close();
    });

    test('7. System Suspend & Resume Power Listener Workflow executes cleanly', () async {
      final powerListener = container.read(windowsPowerListenerProvider);

      expect(powerListener.isSuspended, isFalse);

      // 1. Suspend
      await powerListener.handleSystemSuspend();
      expect(powerListener.isSuspended, isTrue);

      // 2. Resume
      await powerListener.handleSystemResume();
      expect(powerListener.isSuspended, isFalse);
    });

    test('8. Graceful Shutdown closes all WebSocket connections with status code 1001 (Going Away)', () async {
      final wsUri = Uri.parse('ws://127.0.0.1:$port/api/v1/ws?token=$authToken');
      final clientSocket = await WebSocket.connect(wsUri.toString());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final closeCompleter = Completer<void>();
      clientSocket.listen(
        (_) {},
        onDone: () {
          if (!closeCompleter.isCompleted) closeCompleter.complete();
        },
      );

      // Stop server (graceful shutdown)
      await ipcService.stop();

      await closeCompleter.future.timeout(const Duration(seconds: 5));
      expect(clientSocket.closeCode, equals(1001));
    });
  });
}
