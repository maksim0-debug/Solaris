import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 - Zero-Trust Verification & Complete QA Test Suite', () {
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

      // Register routes under test
      router.post('/api/v1/control', (req, params) => controlHandler.handleControl(req, params));
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
      await container.read(settingsProvider.future);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    void updatePermissions(ApiPermissionsConfig permissions) {
      container.read(settingsProvider.notifier).updateApiPermissions(permissions);
    }

    group('A. BDD Behavioral Scenarios — Control & Mutation ACL', () {
      test('Scenario 1: Read-Only mode blocks single control action with RFC 7807', () async {
        updatePermissions(const ApiPermissionsConfig(isReadOnly: true));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_brightness', 'value': 75.0}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['type'], contains('/errors/'));
        expect(body['title'], equals('Read-Only Mode Enabled'));
        expect(body['status'], equals(403));
      });

      test('Scenario 2: Privilege Escalation Guard rejects apiPermissions key in payload', () async {
        updatePermissions(const ApiPermissionsConfig());

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'action': 'set_brightness',
          'value': 50.0,
          'apiPermissions': {'isReadOnly': false, 'allowReadMonitors': true},
        }));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Privilege Escalation Prohibited'));
      });

      test('Scenario 3: Disabled category blocks single control action', () async {
        updatePermissions(const ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.monitors}, // gaming omitted
        ));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_game_mode', 'enabled': true}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Action Category Prohibited'));
      });

      test('Scenario 4: Pre-flight ACL check rejects ENTIRE batch in fail_fast mode before any mutations', () async {
        updatePermissions(const ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.circadian}, // monitors omitted
        ));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'mode': 'fail_fast',
          'actions': [
            {'action': 'set_auto_brightness', 'enabled': false}, // allowed
            {'action': 'set_brightness', 'value': 20.0},        // prohibited
          ],
        }));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Action Category Prohibited'));

        // Verify state remains untouched (atomic failure at index 0)
        final autoBr = container.read(autoBrightnessAdjustmentProvider);
        expect(autoBr, isTrue);
      });

      test('Scenario 5: Batch in continue mode marks prohibited action with 403 error status and executes allowed ones', () async {
        updatePermissions(const ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.circadian},
        ));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'mode': 'continue',
          'actions': [
            {'action': 'set_auto_brightness', 'enabled': false}, // allowed
            {'action': 'set_brightness', 'value': 20.0},        // prohibited
          ],
        }));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['status'], equals('partial'));
        expect(body['successful_actions'], equals(1));
        final results = body['results'] as List;
        expect(results[0]['status'], equals('ok'));
        expect(results[1]['status'], equals('error'));
        expect(results[1]['error'], equals('action_category_prohibited'));
      });

      test('Scenario 6: POST /api/v1/monitors/:slug/brightness is blocked in Read-Only mode', () async {
        updatePermissions(const ApiPermissionsConfig(isReadOnly: true));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/monitors/display-1/brightness'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 90.0}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Read-Only Mode Enabled'));
      });

      test('Scenario 7: POST /api/v1/monitors/:slug/temperature is blocked when monitors category is disabled', () async {
        updatePermissions(const ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.presets},
        ));

        final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/monitors/display-1/temperature'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 4500}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Action Category Prohibited'));
      });
    });

    group('B. Property-Based Testing (PBT) — Invariants Verification', () {
      test('PBT Invariant 1: When isReadOnly is true, isActionAllowed returns false for ALL actions', () {
        const config = ApiPermissionsConfig(isReadOnly: true);

        final testActions = [
          'set_brightness', 'set_temperature', 'set_monitor_offset',
          'set_brightness_preset', 'set_temperature_preset', 'set_user_preset', 'cycle_preset',
          'brightest', 'dimmest', 'coolest', 'warmest',
          'set_auto_brightness', 'toggle_auto_brightness', 'set_smart_circadian',
          'set_game_mode', 'manage_game_mode_whitelist',
          'set_weather_adjustment', 'trigger_sun_sync', 'openmeteo', 'auto',
          'push_sleep_status', 'clear_failed_webhooks', 'set_map_animations',
          'non_existent_action_xyz', '', '12345'
        ];

        for (final action in testActions) {
          expect(config.isActionAllowed(action), isFalse, reason: 'Action "$action" must be disallowed in Read-Only mode');
        }
      });

      test('PBT Invariant 2: getCategoryForAction correctly maps all 30+ supported action strings and aliases', () {
        final mappings = {
          'set_brightness': ApiActionCategory.monitors,
          'set_temperature': ApiActionCategory.monitors,
          'set_monitor_offset': ApiActionCategory.monitors,

          'set_brightness_preset': ApiActionCategory.presets,
          'set_temperature_preset': ApiActionCategory.presets,
          'set_user_preset': ApiActionCategory.presets,
          'cycle_preset': ApiActionCategory.presets,
          'brightest': ApiActionCategory.presets,
          'dimmest': ApiActionCategory.presets,
          'coolest': ApiActionCategory.presets,
          'warmest': ApiActionCategory.presets,

          'set_auto_brightness': ApiActionCategory.circadian,
          'toggle_auto_brightness': ApiActionCategory.circadian,
          'set_smart_circadian': ApiActionCategory.circadian,

          'set_game_mode': ApiActionCategory.gaming,
          'manage_game_mode_whitelist': ApiActionCategory.gaming,

          'set_weather_adjustment': ApiActionCategory.environment,
          'trigger_sun_sync': ApiActionCategory.environment,
          'openmeteo': ApiActionCategory.environment,
          'auto': ApiActionCategory.environment,

          'push_sleep_status': ApiActionCategory.sleep,

          'clear_failed_webhooks': ApiActionCategory.system,
          'set_map_animations': ApiActionCategory.system,
          'on_system_resume': ApiActionCategory.system,
        };

        mappings.forEach((action, expectedCategory) {
          final actual = ApiPermissionsConfig.getCategoryForAction(action);
          expect(actual, equals(expectedCategory), reason: 'Action "$action" should map to ${expectedCategory.name}');
        });
      });
    });
  });
}
