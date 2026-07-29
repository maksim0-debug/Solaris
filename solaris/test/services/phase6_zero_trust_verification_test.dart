import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 6 - End-to-End GUI & Settings Integration Zero-Trust Verification Test Suite',
    () {
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
        final statusHandler = ApiStatusHandler(container);
        final monitorsHandler = ApiMonitorsHandler(container);

        router.get(
          '/api/v1/health',
          (req, params) => statusHandler.handleHealth(req, params),
        );
        router.get(
          '/api/v1/status',
          (req, params) => statusHandler.handleStatus(req, params),
        );
        router.post(
          '/api/v1/control',
          (req, params) => controlHandler.handleControl(req, params),
        );
        router.post(
          '/api/v1/monitors/:slug/brightness',
          (req, params) =>
              monitorsHandler.handleSetMonitorBrightness(req, params),
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
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        client.close(force: true);
        await server.close(force: true);
        container.dispose();
      });

      test(
        '1. Cascade GUI state change: Toggling isReadOnly = true in settingsProvider instantly blocks HTTP control & monitor mutations while keeping /health 100% public',
        () async {
          // Step A: Initially Full Access
          final initialReq = await client.postUrl(
            Uri.parse('$serverUrl/api/v1/control'),
          );
          initialReq.headers.contentType = ContentType.json;
          initialReq.write(
            jsonEncode({'action': 'set_auto_brightness', 'enabled': true}),
          );
          final initialResp = await initialReq.close();
          expect(initialResp.statusCode, equals(HttpStatus.ok));

          // Step B: User activates Read-Only mode in GUI (simulated by updating apiPermissions in settingsProvider)
          const readOnlyConfig = ApiPermissionsConfig(isReadOnly: true);
          container
              .read(settingsProvider.notifier)
              .updateApiPermissions(readOnlyConfig);
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Step C: Verify control action is blocked with 403 Forbidden
          final roReq = await client.postUrl(
            Uri.parse('$serverUrl/api/v1/control'),
          );
          roReq.headers.contentType = ContentType.json;
          roReq.write(
            jsonEncode({'action': 'set_auto_brightness', 'enabled': true}),
          );
          final roResp = await roReq.close();
          expect(roResp.statusCode, equals(HttpStatus.forbidden));

          final roBody = await roResp.transform(utf8.decoder).join();
          final roJson = jsonDecode(roBody);
          expect(roJson['title'], equals('Read-Only Mode Enabled'));

          // Step D: Direct monitor mutation is also blocked with 403 Forbidden
          final monReq = await client.postUrl(
            Uri.parse('$serverUrl/api/v1/monitors/display-1/brightness'),
          );
          monReq.headers.contentType = ContentType.json;
          monReq.write(jsonEncode({'brightness': 80.0}));
          final monResp = await monReq.close();
          expect(monResp.statusCode, equals(HttpStatus.forbidden));

          // Step E: Public health probe remains 100% accessible
          final healthReq = await client.getUrl(
            Uri.parse('$serverUrl/api/v1/health'),
          );
          final healthResp = await healthReq.close();
          expect(healthResp.statusCode, equals(HttpStatus.ok));
          final healthBody = await healthResp.transform(utf8.decoder).join();
          expect(jsonDecode(healthBody)['status'], equals('ok'));
        },
      );

      test(
        '2. Cascade GUI state change: Toggling read flag (allowReadWeather = false) in GUI immediately masks automation payload in GET /api/v1/status',
        () async {
          // Step A: Disable allowReadWeather in GUI
          const customConfig = ApiPermissionsConfig(allowReadWeather: false);
          container
              .read(settingsProvider.notifier)
              .updateApiPermissions(customConfig);
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Step B: Request status
          final req = await client.getUrl(
            Uri.parse('$serverUrl/api/v1/status'),
          );
          final resp = await req.close();
          expect(resp.statusCode, equals(HttpStatus.ok));

          final bodyStr = await resp.transform(utf8.decoder).join();
          final json = jsonDecode(bodyStr);

          // Verify weather section is omitted
          expect(json.containsKey('weather'), isFalse);

          // Verify automation block exists but has NO weather keys
          final automation = json['automation'] as Map<String, dynamic>?;
          expect(automation, isNotNull);
          final hasWeatherKeys = automation!.keys.any(
            (k) => k.startsWith('weather_'),
          );
          expect(hasWeatherKeys, isFalse);
        },
      );

      test(
        '3. Universal Privilege Escalation Guard: Remote payload attempting to inject apiPermissions is strictly rejected with 403 Forbidden',
        () async {
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
          final bodyStr = await resp.transform(utf8.decoder).join();
          final json = jsonDecode(bodyStr);
          expect(json['title'], equals('Privilege Escalation Prohibited'));
        },
      );
    },
  );
}
