import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:solaris/services/api_app_overrides_handler.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ApiAppOverridesHandler Phase 4 Zero-Trust Integration & ACL Tests', () {
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
      final handler = ApiAppOverridesHandler(container);

      router.get(
        '/api/v1/app-overrides',
        (req, params) => handler.handleGetAppOverrides(req, params),
      );
      router.get(
        '/api/v1/app-overrides/active',
        (req, params) => handler.handleGetActiveOverride(req, params),
      );
      router.post(
        '/api/v1/app-overrides',
        (req, params) => handler.handleCreateOrUpdateAppOverride(req, params),
      );
      router.post(
        '/api/v1/app-overrides/reset-builtin',
        (req, params) => handler.handleResetBuiltInAppOverrides(req, params),
      );
      router.delete(
        '/api/v1/app-overrides/:exe',
        (req, params) => handler.handleDeleteAppOverride(req, params),
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test(
      'GET /api/v1/app-overrides returns default 6 built-in rules and exit_delay_seconds',
      () async {
        final req = await client.getUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['total'], equals(6));
        expect(json['exit_delay_seconds'], equals(30));
        final List<dynamic> rules = json['app_overrides'] as List<dynamic>;
        expect(rules.length, equals(6));
        expect(rules.first['exeName'], equals('photoshop.exe'));
      },
    );

    test(
      'GET /api/v1/app-overrides/active returns current active process and applied rule',
      () async {
        container
            .read(activeProcessServiceProvider.notifier)
            .updateActiveProcessManually(
              'photoshop.exe',
              title: 'Adobe Photoshop 2026',
            );

        final req = await client.getUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides/active'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['active_process'], equals('photoshop.exe'));
        expect(json['window_title'], equals('Adobe Photoshop 2026'));
        expect(json['is_gaming'], isFalse);
        expect(json['applied_override'], isNotNull);
        expect(json['applied_override']['exeName'], equals('photoshop.exe'));
        expect(json['evaluated_temperature'], equals(6500));
      },
    );

    test(
      'POST /api/v1/app-overrides creates a new custom rule and updates settingsProvider',
      () async {
        const customRule = AppOverrideRule(
          exeName: 'code.exe',
          appDisplayName: 'VS Code',
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 5000.0,
        );

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(customRule.toJson()));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['status'], equals('ok'));
        expect(json['app_override']['exeName'], equals('code.exe'));

        final settings = container.read(settingsProvider).value?['all'];
        expect(settings, isNotNull);
        final added = settings!.appOverrides.firstWhere(
          (r) => r.exeName == 'code.exe',
        );
        expect(added.fixedTemperature, equals(5000.0));
      },
    );

    test(
      'POST /api/v1/app-overrides rejects path traversal attempt with RFC 7807 400 Bad Request',
      () async {
        final maliciousPayload = {
          'exeName': '../cmd.exe',
          'appDisplayName': 'Malicious Process',
        };

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(maliciousPayload));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.badRequest));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(
          json['type'],
          equals('https://solaris.local/errors/app-overrides-error'),
        );
        expect(json['title'], equals('Validation Error'));
        expect(
          json['detail'],
          contains('path traversal characters are strictly prohibited'),
        );
      },
    );

    test(
      'POST /api/v1/app-overrides rejects non-.exe extensions with RFC 7807 400 Bad Request',
      () async {
        final invalidPayload = {
          'exeName': 'script.bat',
          'appDisplayName': 'Batch File',
        };

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(invalidPayload));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.badRequest));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['title'], equals('Validation Error'));
        expect(
          json['detail'],
          contains('must be a valid executable filename ending in .exe'),
        );
      },
    );

    test(
      'POST /api/v1/app-overrides rejects empty body with RFC 7807 400 Bad Request',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        req.headers.contentType = ContentType.json;
        req.write('   ');
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.badRequest));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['title'], equals('Bad Request'));
        expect(json['detail'], contains('Request body cannot be empty'));
      },
    );

    test(
      'DELETE /api/v1/app-overrides/:exe removes rule successfully',
      () async {
        container
            .read(settingsProvider.notifier)
            .addAppOverride(
              const AppOverrideRule(
                exeName: 'blender.exe',
                appDisplayName: 'Blender 3D',
              ),
            );

        final req = await client.deleteUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides/blender.exe'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(json['status'], equals('ok'));
        expect(json['deleted_exe'], equals('blender.exe'));

        final settings = container.read(settingsProvider).value?['all'];
        final exists = settings!.appOverrides.any(
          (r) => r.exeName == 'blender.exe',
        );
        expect(exists, isFalse);
      },
    );

    test(
      'DELETE /api/v1/app-overrides/:exe with path traversal returns 400 Bad Request',
      () async {
        final req = await client.deleteUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides/..%2Fcmd.exe'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.badRequest));
      },
    );

    test(
      'POST /api/v1/app-overrides/reset-builtin resets built-in rules to factory defaults',
      () async {
        container
            .read(settingsProvider.notifier)
            .removeAppOverride('photoshop.exe');

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides/reset-builtin'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));

        final settings = container.read(settingsProvider).value?['all'];
        final psRule = settings!.appOverrides.firstWhere(
          (r) => r.exeName == 'photoshop.exe',
        );
        expect(psRule.isBuiltIn, isTrue);
        expect(psRule.fixedTemperature, equals(6500.0));
      },
    );

    test(
      'ACL Permission enforcement: Read-only token returns 403 Forbidden RFC 7807 on POST',
      () async {
        const readOnlyPermissions = ApiPermissionsConfig(isReadOnly: true);
        container
            .read(settingsProvider.notifier)
            .updateApiPermissions(readOnlyPermissions);

        const customRule = AppOverrideRule(
          exeName: 'forbidden.exe',
          appDisplayName: 'Forbidden App',
        );

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(customRule.toJson()));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(
          json['type'],
          equals('https://solaris.local/errors/access-denied'),
        );
        expect(json['title'], equals('Read-Only Mode Enabled'));
      },
    );

    test(
      'ACL Permission enforcement: Restricting allowedActions returns 403 Forbidden when action is absent',
      () async {
        // Allow only get_app_overrides
        const restrictedPermissions = ApiPermissionsConfig(
          allowedActions: {'get_app_overrides'},
        );
        container
            .read(settingsProvider.notifier)
            .updateApiPermissions(restrictedPermissions);

        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/app-overrides/reset-builtin'),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);

        expect(
          json['type'],
          equals('https://solaris.local/errors/access-denied'),
        );
        expect(json['detail'], contains('reset_builtin_app_overrides'));
        expect(
          json['detail'],
          contains('disabled in API permissions settings'),
        );
      },
    );
  });
}
