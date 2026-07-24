import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 - Status, Monitors & Query Endpoints Filtering Tests', () {
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
      final monitorsHandler = ApiMonitorsHandler(container);

      // Register Phase 4 routes under test
      router.get('/api/v1/health', (req, params) => statusHandler.handleHealth(req, params));
      router.get('/api/v1/status', (req, params) => statusHandler.handleStatus(req, params));
      router.get('/api/v1/solar', (req, params) => statusHandler.handleSolar(req, params));
      router.get('/api/v1/presets', (req, params) => statusHandler.handlePresets(req, params));
      router.get('/api/v1/sleep/sessions', (req, params) => statusHandler.handleSleepSessions(req, params));
      router.get('/api/v1/monitors', (req, params) => monitorsHandler.handleGetMonitors(req, params));
      router.get('/api/v1/monitors/:slug', (req, params) => monitorsHandler.handleGetMonitorBySlug(req, params));

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
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    void updatePermissions(ApiPermissionsConfig permissions) {
      container.read(settingsProvider.notifier).updateApiPermissions(permissions);
    }

    test('1. GET /api/v1/health remains 100% public even with read-only and all flags disabled', () async {
      updatePermissions(const ApiPermissionsConfig(
        isReadOnly: true,
        allowReadMonitors: false,
        allowReadSolar: false,
        allowReadWeather: false,
        allowReadSleep: false,
        allowReadCircadian: false,
        allowedCategories: {},
      ));

      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/health'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['status'], equals('ok'));
      expect(body.containsKey('version'), isTrue);
      expect(body.containsKey('uptime_seconds'), isTrue);
    });

    test('2. GET /api/v1/status filters weather, solar, monitors and server sections based on flags', () async {
      updatePermissions(const ApiPermissionsConfig(
        allowReadWeather: false,
        allowReadSolar: false,
        allowReadMonitors: false,
        allowedCategories: {
          ApiActionCategory.monitors,
          ApiActionCategory.presets,
        },
      ));

      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());

      // Disabled sections must be removed
      expect(body.containsKey('weather'), isFalse);
      expect(body.containsKey('solar'), isFalse);
      expect(body.containsKey('monitors'), isFalse);
      expect(body.containsKey('server'), isFalse);

      // Automation object must be present but weather keys removed
      expect(body.containsKey('automation'), isTrue);
      final automation = body['automation'] as Map<String, dynamic>;
      expect(automation.keys.any((k) => k.startsWith('weather_')), isFalse);
      expect(automation.containsKey('map_animations'), isFalse); // system category disabled
    });

    test('3. GET /api/v1/status sub-filters smart_circadian when allowReadSleep is false', () async {
      updatePermissions(const ApiPermissionsConfig(
        allowReadCircadian: true,
        allowReadSleep: false,
      ));

      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/status'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());

      expect(body.containsKey('sleep'), isFalse);
      expect(body.containsKey('smart_circadian'), isTrue);

      final circadian = body['smart_circadian'] as Map<String, dynamic>;
      expect(circadian.containsKey('sleep_pressure'), isFalse);
      expect(circadian.containsKey('sleep_debt'), isFalse);
      final submodules = circadian['submodules'] as Map<String, dynamic>;
      expect(submodules.containsKey('sleep_pressure_master'), isFalse);
      expect(submodules.containsKey('sleep_debt_master'), isFalse);
    });

    test('4. GET /api/v1/solar returns 403 when allowReadSolar is false', () async {
      updatePermissions(const ApiPermissionsConfig(allowReadSolar: false));

      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/solar'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['title'], equals('Read Access Prohibited'));
    });

    test('5. GET /api/v1/presets masks sections and returns 403 when both flags are disabled', () async {
      // Partially disabled
      updatePermissions(const ApiPermissionsConfig(
        allowReadMonitors: false,
        allowReadCircadian: true,
      ));

      var req = await client.getUrl(Uri.parse('$serverUrl/api/v1/presets'));
      var resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.ok));
      var body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body.containsKey('temperature'), isTrue);
      expect(body.containsKey('brightness'), isFalse);

      // Both disabled
      updatePermissions(const ApiPermissionsConfig(
        allowReadMonitors: false,
        allowReadCircadian: false,
      ));

      req = await client.getUrl(Uri.parse('$serverUrl/api/v1/presets'));
      resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.forbidden));
      body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['title'], equals('Read Access Prohibited'));
    });

    test('6. GET /api/v1/monitors and GET /api/v1/monitors/:slug return 403 when allowReadMonitors is false', () async {
      updatePermissions(const ApiPermissionsConfig(allowReadMonitors: false));

      // GET /monitors
      var req = await client.getUrl(Uri.parse('$serverUrl/api/v1/monitors'));
      var resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.forbidden));

      // GET /monitors/display-1
      req = await client.getUrl(Uri.parse('$serverUrl/api/v1/monitors/display-1'));
      resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.forbidden));
    });

    test('7. GET /api/v1/sleep/sessions returns 403 when allowReadSleep is false', () async {
      updatePermissions(const ApiPermissionsConfig(allowReadSleep: false));

      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/sleep/sessions'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['title'], equals('Read Access Prohibited'));
    });
  });
}
