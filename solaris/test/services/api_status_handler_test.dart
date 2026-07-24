import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';

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

  group('ApiStatusHandler & /api/v1/status Integration Tests', () {
    late ProviderContainer container;
    late HttpServer server;
    late ApiRouter router;
    late HttpClient client;
    late String serverUrl;

    setUp(() async {
      HttpOverrides.global = null;
      container = ProviderContainer();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';

      router = ApiRouter();
      final statusHandler = ApiStatusHandler(container);

      router.get('/api/v1/health', (req, params) => statusHandler.handleHealth(req, params));
      router.get('/api/v1/status', (req, params) => statusHandler.handleStatus(req, params));
      router.get('/api/v1/solar', (req, params) => statusHandler.handleSolar(req, params));
      router.get('/api/v1/presets', (req, params) => statusHandler.handlePresets(req, params));
      router.get('/api/v1/sleep/sessions', (req, params) => statusHandler.handleSleepSessions(req, params));
      router.get('/api/v1/docs', (req, params) => statusHandler.handleDocs(req, params));
      router.get('/api/v1/openapi.json', (req, params) => statusHandler.handleOpenApiJson(req, params));

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
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test('GET /api/v1/status returns 200 OK and valid JSON status without Riverpod self-dependency error', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['version'], isNotNull);
      expect(json['uptime_seconds'], isA<int>());
      expect(json['timestamp'], isNotNull);
      expect(json['monitors'], isA<List<dynamic>>());
      expect(json['automation'], isA<Map<String, dynamic>>());
      expect(json['smart_circadian'], isA<Map<String, dynamic>>());
      expect(json['sleep'], isA<Map<String, dynamic>>());
      expect(json['server'], isA<Map<String, dynamic>>());
      if (json['solar'] != null) {
        final solarJson = json['solar'] as Map<String, dynamic>;
        final nextEvent = solarJson['next_event'] as Map<String, dynamic>;
        expect(nextEvent['type'], isA<String>());
      }
    });

    test('GET /api/v1/health returns 200 OK with status ok', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/health'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['status'], equals('ok'));
      expect(json['version'], isNotNull);
      expect(json['uptime_seconds'], isA<int>());
    });

    test('GET /api/v1/presets returns system and user presets for brightness and temperature', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/presets'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['brightness'], isNotNull);
      expect(json['temperature'], isNotNull);
    });

    test('GET /api/v1/sleep/sessions returns paginated list', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/sleep/sessions?limit=10&offset=0'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['total'], isA<int>());
      expect(json['limit'], equals(10));
      expect(json['offset'], equals(0));
      expect(json['sessions'], isA<List<dynamic>>());
    });

    test('GET /api/v1/docs returns 200 OK with HTML content type', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/docs'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      expect(resp.headers.contentType?.mimeType, equals('text/html'));
      final bodyStr = await resp.transform(utf8.decoder).join();
      expect(bodyStr, contains('Solaris Control API Documentation'));
    });

    test('GET /api/v1/openapi.json returns 200 OK with valid openapi spec', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/openapi.json'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['openapi'], equals('3.0.3'));
      expect(json['paths'], isNotNull);
    });

    test('GET /api/v1/status correctly handles pushes to pushedIsSleeping without altering sessions', () async {
      final sleepNotifier = container.read(sleepProvider.notifier);
      
      // Default: pushedIsSleeping is null, sessions empty -> is_sleeping: false
      var req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      var resp = await req.close();
      var json = jsonDecode(await resp.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(json['sleep']['is_sleeping'], isFalse);

      // Push is_sleeping = true
      sleepNotifier.updatePushedSleepStatus(true);
      req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      resp = await req.close();
      json = jsonDecode(await resp.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(json['sleep']['is_sleeping'], isTrue);

      // Push is_sleeping = false
      sleepNotifier.updatePushedSleepStatus(false);
      req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      resp = await req.close();
      json = jsonDecode(await resp.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(json['sleep']['is_sleeping'], isFalse);
    });
  });

  group('LocalIpcService End-To-End /api/v1/status Test', () {
    late ProviderContainer container;
    late HttpClient client;

    setUp(() {
      HttpOverrides.global = null;
      final testSettings = SettingsState(
        isLocalIpcServerEnabled: true,
      );
      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => FakeSettingsNotifier(testSettings)),
        ],
      );
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      final ipcNotifier = container.read(localIpcServiceProvider.notifier);
      if (container.read(localIpcServiceProvider).isRunning) {
        await ipcNotifier.stop();
      }
      container.dispose();
    });

    test('LocalIpcService handles GET /api/v1/status without throwing Riverpod assertion error', () async {
      final ipcNotifier = container.read(localIpcServiceProvider.notifier);
      await ipcNotifier.start();

      final port = container.read(localIpcServiceProvider).port;
      expect(port, isNotNull);

      final req = await client.getUrl(Uri.parse('http://localhost:$port/api/v1/status'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(json['version'], isNotNull);
      expect(json['monitors'], isA<List<dynamic>>());
    });
  });
}
