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

  group('Phase 3 - Control ACL, Batch Pre-flight & Endpoint Protection Tests', () {
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
      router.use((req) => authMiddleware(req, router));
      final controlHandler = ApiControlHandler(container);
      final monitorsHandler = ApiMonitorsHandler(container);

      // Register routes under test
      router.post(
        '/api/v1/control',
        (req, params) => controlHandler.handleControl(req, params),
      );
      router.post(
        '/api/v1/monitors/:slug/brightness',
        (req, params) =>
            monitorsHandler.handleSetMonitorBrightness(req, params),
      );
      router.post(
        '/api/v1/monitors/:slug/temperature',
        (req, params) =>
            monitorsHandler.handleSetMonitorTemperature(req, params),
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
      final settings = await container.read(settingsProvider.future);
      router.apiKeys = settings['all']?.apiKeys ?? [];
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    Future<void> updatePermissions(ApiPermissionsConfig permissions) async {
      container
          .read(settingsProvider.notifier)
          .updateApiPermissions(permissions);
      await Future<void>.delayed(Duration.zero);
      final stateMap = container.read(settingsProvider.notifier).state.value;
      if (stateMap != null) {
        router.apiKeys = stateMap['all']?.apiKeys ?? [];
      }
    }

    test(
      '1. Privilege Escalation Guard rejects payload containing apiPermissions',
      () async {
        await updatePermissions(
          const ApiPermissionsConfig(),
        ); // full permissions by default

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'action': 'set_brightness',
            'value': 50.0,
            'apiPermissions': {'isReadOnly': false},
          }),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Privilege Escalation Prohibited'));
      },
    );

    test('2. Read-Only mode blocks single control action', () async {
      await updatePermissions(const ApiPermissionsConfig(isReadOnly: true));

      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'set_brightness', 'value': 80.0}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['title'], equals('Read-Only Mode Enabled'));
    });

    test('3. Disabled category blocks single control action', () async {
      await updatePermissions(
        const ApiPermissionsConfig(
          allowedCategories: {
            ApiActionCategory.monitors,
            // gaming is omitted
          },
        ),
      );

      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'set_game_mode', 'enabled': true}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(body['title'], equals('Action Category Prohibited'));
    });

    test(
      '4. Batch Pre-flight ACL check rejects ENTIRE batch in fail_fast mode before any mutations',
      () async {
        updatePermissions(
          const ApiPermissionsConfig(
            allowedCategories: {
              ApiActionCategory.circadian,
              // monitors category is omitted
            },
          ),
        );

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'mode': 'fail_fast',
            'actions': [
              {
                'action': 'set_auto_brightness',
                'enabled': false,
              }, // allowed category
              {
                'action': 'set_brightness',
                'value': 20.0,
              }, // prohibited category (monitors)
            ],
          }),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Action Category Prohibited'));

        // Verify NO state mutation occurred for the first allowed item
        final autoBr = container.read(autoBrightnessAdjustmentProvider);
        expect(autoBr, isTrue); // unchanged
      },
    );

    test(
      '5. Batch in continue mode marks prohibited action with 403 and executes allowed ones',
      () async {
        updatePermissions(
          const ApiPermissionsConfig(
            allowedCategories: {
              ApiActionCategory.circadian,
              // monitors omitted
            },
          ),
        );

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'mode': 'continue',
            'actions': [
              {'action': 'set_auto_brightness', 'enabled': false}, // allowed
              {'action': 'set_brightness', 'value': 20.0}, // prohibited
            ],
          }),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['status'], equals('partial'));
        expect(body['successful_actions'], equals(1));
        final results = body['results'] as List;
        expect(results.length, equals(2));
        expect(results[0]['status'], equals('ok'));
        expect(results[1]['status'], equals('error'));
      },
    );

    test(
      '6. POST /api/v1/monitors/:slug/brightness is blocked when isReadOnly is true',
      () async {
        updatePermissions(const ApiPermissionsConfig(isReadOnly: true));

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/monitors/display-1/brightness'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 70.0}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Read-Only Mode Enabled'));
      },
    );

    test(
      '7. POST /api/v1/monitors/:slug/temperature is blocked when monitors category disabled',
      () async {
        updatePermissions(
          const ApiPermissionsConfig(
            allowedCategories: {ApiActionCategory.presets},
          ),
        );

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/monitors/display-1/temperature'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 5000}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final body = jsonDecode(await resp.transform(utf8.decoder).join());
        expect(body['title'], equals('Action Category Prohibited'));
      },
    );
  });
}
