import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Phase 2 E2E Verification & Comprehensive 26 Actions Test Suite', () {
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
            ..headers.contentType = ContentType('application', 'problem+json')
            ..write(jsonEncode({
              'type': 'https://solaris.app/errors/not-found',
              'title': 'Not Found',
              'status': 404,
              'detail': 'Endpoint not found',
            }));
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

    Future<HttpClientResponse> sendPost(String path, Map<String, dynamic> body) async {
      final req = await client.postUrl(Uri.parse('$serverUrl$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      return await req.close();
    }

    Future<HttpClientResponse> sendGet(String path) async {
      final req = await client.getUrl(Uri.parse('$serverUrl$path'));
      return await req.close();
    }

    test('Verification: Action 1 - set_brightness (0..100)', () async {
      final resp = await sendPost('/api/v1/control', {'action': 'set_brightness', 'value': 82.5});
      expect(resp.statusCode, equals(HttpStatus.accepted));
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(json['status'], equals('accepted'));
      expect(json['queued']['value'], equals(82.5));

      final invalidResp = await sendPost('/api/v1/control', {'action': 'set_brightness', 'value': 150.0});
      expect(invalidResp.statusCode, equals(HttpStatus.badRequest));
    });

    test('Verification: Action 2 & 3 - set_auto_brightness & toggle_auto_brightness', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_auto_brightness', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));
      expect(container.read(autoBrightnessAdjustmentProvider), isTrue);

      resp = await sendPost('/api/v1/control', {'action': 'toggle_auto_brightness'});
      expect(resp.statusCode, equals(HttpStatus.ok));
      expect(container.read(autoBrightnessAdjustmentProvider), isFalse);
    });

    test('Verification: Action 4 - set_temperature (3300..6500 Kelvin)', () async {
      final resp = await sendPost('/api/v1/control', {'action': 'set_temperature', 'value': 5500});
      expect(resp.statusCode, equals(HttpStatus.accepted));

      final invalidResp = await sendPost('/api/v1/control', {'action': 'set_temperature', 'value': 2000});
      expect(invalidResp.statusCode, equals(HttpStatus.badRequest));
    });

    test('Verification: Action 5, 6, 7 - Temperature toggles & auto-mode', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_color_temperature_enabled', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_auto_temperature', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'toggle_auto_temperature'});
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Action 8, 9, 10, 11 - Presets (brightness, temperature, user, cycle)', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_brightness_preset', 'preset': 'dim'});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_temperature_preset', 'preset': 'warm'});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_user_preset', 'id': 'preset_night_1'});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'cycle_preset', 'direction': 'next'});
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Action 12, 13, 14 - Game Mode & Whitelist', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_game_mode', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_game_mode_brightness', 'value': 90.0});
      expect(resp.statusCode, equals(HttpStatus.accepted));

      resp = await sendPost('/api/v1/control', {'action': 'manage_game_mode_whitelist', 'op': 'add', 'app': 'cyberpunk2077.exe'});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'manage_game_mode_whitelist', 'op': 'remove', 'app': 'cyberpunk2077.exe'});
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Action 15 - set_monitor_offset (-50..50)', () async {
      final resp = await sendPost('/api/v1/control', {'action': 'set_monitor_offset', 'offset': 15.0, 'monitor_id': 'all'});
      expect(resp.statusCode, equals(HttpStatus.accepted));

      final invalidResp = await sendPost('/api/v1/control', {'action': 'set_monitor_offset', 'offset': 80.0});
      expect(invalidResp.statusCode, equals(HttpStatus.badRequest));
    });

    test('Verification: Action 16, 17, 18 - Weather Adjustments & Intensity', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_weather_adjustment', 'brightness': true, 'temperature': false});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_weather_temperature_adjustment', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_weather_intensity', 'value': 0.7});
      expect(resp.statusCode, equals(HttpStatus.accepted));
    });

    test('Verification: Action 19 & 20 - Smart Circadian Master & Submodules', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'set_smart_circadian', 'enabled': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {
        'action': 'set_smart_circadian_submodules',
        'wind_down': true,
        'time_shift': false,
        'sleep_pressure': true,
        'sleep_debt': false,
      });
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Action 21, 22, 23, 24 - Map Animations, Location, Provider, Sun Sync', () async {
      var resp = await sendPost('/api/v1/control', {
        'action': 'set_map_animations',
        'rain': true,
        'snow': false,
        'thunder': true,
        'cloud': false,
      });
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_manual_location', 'latitude': 50.4495, 'longitude': 30.5253});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'set_weather_provider', 'provider': 'openMeteo'});
      expect(resp.statusCode, equals(HttpStatus.ok));

      resp = await sendPost('/api/v1/control', {'action': 'trigger_sun_sync'});
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Action 25 & 26 - Sleep status push & Clear failed webhooks', () async {
      var resp = await sendPost('/api/v1/control', {'action': 'push_sleep_status', 'is_sleeping': true});
      expect(resp.statusCode, equals(HttpStatus.ok));

      await Future<void>.delayed(Duration.zero);
      expect(container.read(sleepProvider).isCurrentlySleeping, isTrue);

      resp = await sendPost('/api/v1/control', {'action': 'clear_failed_webhooks', 'webhook_id': 'wh_12345'});
      expect(resp.statusCode, equals(HttpStatus.ok));
    });

    test('Verification: Per-Monitor endpoints and 404 for unknown slug', () async {
      var resp = await sendGet('/api/v1/monitors');
      expect(resp.statusCode, equals(HttpStatus.ok));
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(json['monitors'], isNotNull);

      resp = await sendGet('/api/v1/monitors/non_existent_slug_999');
      expect(resp.statusCode, equals(HttpStatus.notFound));
      expect(resp.headers.value('Content-Type'), equals('application/problem+json'));

      resp = await sendPost('/api/v1/monitors/display-1/brightness', {'value': 40.0});
      expect(resp.statusCode, equals(HttpStatus.accepted));

      resp = await sendPost('/api/v1/monitors/display-1/temperature', {'value': 4000});
      expect(resp.statusCode, equals(HttpStatus.accepted));
    });

    test('Verification: Fail-Fast Batch execution stops on invalid action', () async {
      final resp = await sendPost('/api/v1/control', {
        'mode': 'fail_fast',
        'actions': [
          {'action': 'set_auto_brightness', 'enabled': true},
          {'action': 'invalid_unknown_action'},
          {'action': 'set_game_mode', 'enabled': true},
        ],
      });

      expect(resp.statusCode, equals(HttpStatus.forbidden));
    });
  });
}
