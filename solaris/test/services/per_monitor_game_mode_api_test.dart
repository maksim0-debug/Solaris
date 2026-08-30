import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/monitor_service.dart';

class MockMonitorService extends Fake implements MonitorService {
  final List<MonitorInfo> _monitors;
  MockMonitorService(this._monitors);

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async => _monitors;
}

class FakeMonitorListNotifier extends MonitorListNotifier {
  final List<MonitorInfo> _monitors;
  FakeMonitorListNotifier(this._monitors);

  @override
  Future<List<MonitorInfo>> build() async => _monitors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-Monitor Game Mode API Integration Tests', () {
    late ProviderContainer container;
    late HttpServer server;
    late ApiRouter router;
    late HttpClient client;
    late String serverUrl;

    final mockMonitors = [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'Generic PnP Monitor',
        deviceName: r'\\.\DISPLAY1',
        friendlyName: 'LG Gaming OLED',
        deviceIdHash: 'a1b2',
        isPrimary: true,
      ),
      MonitorInfo(
        id: r'\\.\DISPLAY2',
        name: 'Generic PnP Monitor',
        deviceName: r'\\.\DISPLAY2',
        friendlyName: 'Dell Workstation',
        deviceIdHash: 'c3d4',
        isPrimary: false,
      ),
    ];

    setUp(() async {
      HttpOverrides.global = null;
      container = ProviderContainer(
        overrides: [
          monitorServiceProvider.overrideWithValue(
            MockMonitorService(mockMonitors),
          ),
          monitorListProvider.overrideWith(
            () => FakeMonitorListNotifier(mockMonitors),
          ),
        ],
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';

      router = ApiRouter();
      final controlHandler = ApiControlHandler(container);
      final monitorsHandler = ApiMonitorsHandler(container);

      router.post(
        '/api/v1/control',
        (req, params) => controlHandler.handleControl(req, params),
      );
      router.get(
        '/api/v1/monitors',
        (req, params) => monitorsHandler.handleGetMonitors(req, params),
      );
      router.get(
        '/api/v1/monitors/:slug',
        (req, params) => monitorsHandler.handleGetMonitorBySlug(req, params),
      );
      router.post(
        '/api/v1/monitors/:slug/game-mode',
        (req, params) => monitorsHandler.handleSetMonitorGameMode(req, params),
      );

      server.listen((HttpRequest request) async {
        final handled = await router.handle(request);
        if (!handled) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      });

      client = HttpClient();
      await container.read(settingsProvider.future);
      await container.read(monitorListProvider.future);
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test('GET /api/v1/monitors includes game_mode field for each monitor', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/monitors'));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(body['count'], equals(2));
      final monitors = body['monitors'] as List<dynamic>;

      expect(monitors[0]['game_mode'], isNotNull);
      expect(monitors[0]['game_mode']['enabled'], isTrue);
      expect(monitors[0]['game_mode']['active'], isFalse);

      expect(monitors[1]['game_mode'], isNotNull);
      expect(monitors[1]['game_mode']['enabled'], isTrue);
      expect(monitors[1]['game_mode']['active'], isFalse);
    });

    test('POST /api/v1/monitors/:slug/game-mode modifies target monitor only', () async {
      // Disable Game Mode for display-2
      final req = await client.postUrl(
        Uri.parse('$serverUrl/api/v1/monitors/display-2/game-mode'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'enabled': false}));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(body['status'], equals('ok'));
      expect(body['game_mode']['enabled'], isFalse);

      // Verify display-1 is still enabled
      final req1 = await client.getUrl(
        Uri.parse('$serverUrl/api/v1/monitors/display-1'),
      );
      final res1 = await req1.close();
      final body1 = jsonDecode(await res1.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(body1['game_mode']['enabled'], isTrue);

      // Verify display-2 is disabled
      final req2 = await client.getUrl(
        Uri.parse('$serverUrl/api/v1/monitors/display-2'),
      );
      final res2 = await req2.close();
      final body2 = jsonDecode(await res2.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(body2['game_mode']['enabled'], isFalse);
    });

    test('POST /api/v1/control set_game_mode with monitor parameter', () async {
      // Use control action to disable game mode on display-1
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'action': 'set_game_mode',
          'enabled': false,
          'monitor': 'display-1',
        }),
      );
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      // Verify state in container
      final map = container.read(settingsProvider).value!;
      expect(map[r'\\.\DISPLAY1']?.isGameModeEnabled, isFalse);
    });
  });
}
