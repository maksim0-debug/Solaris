import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ApiControlHandler & ApiMonitorsHandler Integration Tests', () {
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
      final controlHandler = ApiControlHandler(container);
      final monitorsHandler = ApiMonitorsHandler(container);

      router.post('/api/v1/control', (req, params) => controlHandler.handleControl(req, params));
      router.get('/api/v1/monitors', (req, params) => monitorsHandler.handleGetMonitors(req, params));
      router.get('/api/v1/monitors/:slug', (req, params) => monitorsHandler.handleGetMonitorBySlug(req, params));
      router.post('/api/v1/monitors/:slug/brightness', (req, params) => monitorsHandler.handleSetMonitorBrightness(req, params));
      router.post('/api/v1/monitors/:slug/temperature', (req, params) => monitorsHandler.handleSetMonitorTemperature(req, params));

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
      await Future<void>.delayed(const Duration(milliseconds: 600));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test('POST /api/v1/control set_brightness returns 202 Accepted', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'action': 'set_brightness',
        'value': 75.0,
      }));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.accepted));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('accepted'));
      expect(json['action'], equals('set_brightness'));
      expect(json['queued']['value'], equals(75.0));

      await Future.microtask(() {});
      final isAutoBr = container.read(autoBrightnessAdjustmentProvider);
      expect(isAutoBr, isFalse);
    });

    test('POST /api/v1/control set_auto_brightness returns 200 OK', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'action': 'set_auto_brightness',
        'enabled': true,
      }));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('ok'));
      expect(json['applied']['enabled'], isTrue);

      final isAutoBr = container.read(autoBrightnessAdjustmentProvider);
      expect(isAutoBr, isTrue);
    });

    test('POST /api/v1/control set_temperature returns 202 Accepted', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'action': 'set_temperature',
        'value': 4500,
      }));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.accepted));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('accepted'));
      expect(json['action'], equals('set_temperature'));
    });

    test('POST /api/v1/control Batch Action fail_fast mode executes actions', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'mode': 'fail_fast',
        'actions': [
          {'action': 'set_auto_brightness', 'enabled': false},
          {'action': 'set_brightness_preset', 'preset': 'dim'},
          {'action': 'set_game_mode', 'enabled': true},
        ],
      }));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('completed'));
      expect(json['total_actions'], equals(3));
      expect(json['successful_actions'], equals(3));
      expect((json['results'] as List).length, equals(3));
    });

    test('POST /api/v1/control with unknown action returns 422 Unprocessable Entity', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'action': 'unknown_action_xyz',
      }));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(resp.headers.value('Content-Type'), equals('application/problem+json'));
    });

    test('GET /api/v1/monitors returns monitor list structure', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/monitors'));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['count'], isNotNull);
      expect(json['monitors'], isNotNull);
    });

    test('POST /api/v1/monitors/display-1/brightness returns 202 Accepted', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/monitors/display-1/brightness'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'value': 60.0}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.accepted));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('accepted'));
      expect(json['slug'], equals('display-1'));
    });
  });
}
