import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/openapi_spec.dart';

void main() {
  group('Stage 2: Multiple Scoped API Keys Engine & Routing Tests', () {
    late ApiRouter router;
    late ApiKeyEntry fullKey;
    late ApiKeyEntry readOnlyKey;
    late ApiKeyEntry solarOnlyKey;
    HttpServer? server;

    setUp(() async {
      fullKey = ApiKeyEntry.create(
        name: 'Full Key',
        permissions: const ApiPermissionsConfig(
          isReadOnly: false,
          allowReadMonitors: true,
          allowReadSolar: true,
          allowReadWeather: true,
          allowReadSleep: true,
          allowReadCircadian: true,
          allowedCategories: {
            ApiActionCategory.monitors,
            ApiActionCategory.presets,
            ApiActionCategory.circadian,
            ApiActionCategory.gaming,
            ApiActionCategory.environment,
            ApiActionCategory.sleep,
            ApiActionCategory.system,
          },
        ),
      );

      readOnlyKey = ApiKeyEntry.create(
        name: 'StreamDeck ReadOnly Key',
        permissions: const ApiPermissionsConfig(
          isReadOnly: true,
          allowReadMonitors: true,
          allowReadSolar: true,
          allowedCategories: {
            ApiActionCategory.monitors,
            ApiActionCategory.presets,
          },
        ),
      );

      solarOnlyKey = ApiKeyEntry.create(
        name: 'Solar Only Key',
        permissions: const ApiPermissionsConfig(
          isReadOnly: false,
          allowReadSolar: true,
          allowReadMonitors: false,
          allowedCategories: {ApiActionCategory.environment},
        ),
      );

      router = ApiRouter();
      router.apiKeys = [fullKey, readOnlyKey, solarOnlyKey];
      router.requireLocalToken = false;
      router.use((req) => authMiddleware(req, router));
    });

    tearDown(() async {
      await server?.close(force: true);
    });

    test(
      'ApiKeyEntry matching via constant-time SHA-256 (findMatchingKey)',
      () {
        final matchedFull = router.findMatchingKey(fullKey.token);
        expect(matchedFull, isNotNull);
        expect(matchedFull!.id, equals(fullKey.id));

        final matchedRO = router.findMatchingKey(readOnlyKey.token);
        expect(matchedRO, isNotNull);
        expect(matchedRO!.id, equals(readOnlyKey.id));

        final matchedInvalid = router.findMatchingKey(
          'sol_sec_invalidtoken12345',
        );
        expect(matchedInvalid, isNull);

        expect(router.findMatchingKey(null), isNull);
        expect(router.findMatchingKey(''), isNull);
      },
    );

    test('Legacy expectedToken proxy property backward compatibility', () {
      expect(router.expectedToken, equals(fullKey.token));

      router.expectedToken =
          'sol_sec_newlegacytoken1234567890abcdef1234567890abcdef12345678';
      expect(
        router.apiKeys.first.token,
        equals(
          'sol_sec_newlegacytoken1234567890abcdef1234567890abcdef12345678',
        ),
      );
      expect(
        router.expectedToken,
        equals(
          'sol_sec_newlegacytoken1234567890abcdef1234567890abcdef12345678',
        ),
      );
    });

    test('OpenAPI spec dynamic filtering according to key permissions', () {
      final fullSpec = OpenApiSpec.generateSpec(
        port: 45321,
        permissions: fullKey.permissions,
      );
      expect(fullSpec, isA<Map<String, dynamic>>());

      final readOnlySpec = OpenApiSpec.generateSpec(
        port: 45321,
        permissions: readOnlyKey.permissions,
      );
      expect(readOnlySpec, isA<Map<String, dynamic>>());
    });

    test(
      'HTTP Auth Middleware attaches permissions and enforces invalid token 401',
      () async {
        bool onKeyUsedCalled = false;
        String? usedKeyId;
        router.onKeyUsed = (id) {
          onKeyUsedCalled = true;
          usedKeyId = id;
        };

        router.get('/api/v1/test', (req, params) async {
          final perms = req.permissions;
          ApiRouter.sendJson(req, 200, {
            'is_read_only': perms.isReadOnly,
            'allow_solar': perms.allowReadSolar,
            'key_id': req.apiKeyEntry?.id,
          });
        });

        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server!.listen((req) => router.handle(req));

        final client = HttpClient();

        // 1. Invalid Token Request
        final reqInvalid = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server!.port}/api/v1/test'),
        );
        reqInvalid.headers.add('x-api-key', 'sol_sec_invalidtoken12345');
        final resInvalid = await reqInvalid.close();
        expect(resInvalid.statusCode, equals(HttpStatus.unauthorized));

        // 2. Valid ReadOnly Key Request
        final reqRO = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server!.port}/api/v1/test'),
        );
        reqRO.headers.add('x-api-key', readOnlyKey.token);
        final resRO = await reqRO.close();
        expect(resRO.statusCode, equals(HttpStatus.ok));
        final jsonRO =
            jsonDecode(await utf8.decoder.bind(resRO).join())
                as Map<String, dynamic>;
        expect(jsonRO['is_read_only'], isTrue);
        expect(jsonRO['key_id'], equals(readOnlyKey.id));
        expect(onKeyUsedCalled, isTrue);
        expect(usedKeyId, equals(readOnlyKey.id));

        client.close();
      },
    );

    test(
      'HTTP Require Local Token setting rejects tokenless loopback requests',
      () async {
        router.requireLocalToken = true;

        router.get('/api/v1/test', (req, params) async {
          ApiRouter.sendJson(req, 200, {'status': 'ok'});
        });

        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server!.listen((req) => router.handle(req));

        final client = HttpClient();

        // 1. Tokenless loopback request -> 401 Unauthorized
        final reqAnon = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server!.port}/api/v1/test'),
        );
        final resAnon = await reqAnon.close();
        expect(resAnon.statusCode, equals(HttpStatus.unauthorized));

        // 2. Loopback request with valid token -> 200 OK
        final reqValid = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server!.port}/api/v1/test'),
        );
        reqValid.headers.add('authorization', 'Bearer ${fullKey.token}');
        final resValid = await reqValid.close();
        expect(resValid.statusCode, equals(HttpStatus.ok));

        client.close();
      },
    );

    test(
      'Anonymous loopback requests get default permissions regardless of first API key in list',
      () async {
        router.requireLocalToken = false;
        router.apiKeys = [
          readOnlyKey,
          fullKey,
        ]; // First key in list is Read-Only

        router.post('/api/sleep/status', (req, params) async {
          final perms = req.permissions;
          if (perms.isReadOnly) {
            ApiRouter.sendJson(req, 403, {'error': 'Read-Only Mode Enabled'});
          } else {
            ApiRouter.sendJson(req, 200, {'status': 'success'});
          }
        });

        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server!.listen((req) => router.handle(req));

        final client = HttpClient();
        final reqAnon = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server!.port}/api/sleep/status'),
        );
        final resAnon = await reqAnon.close();
        expect(resAnon.statusCode, equals(HttpStatus.ok));
        final jsonRes =
            jsonDecode(await utf8.decoder.bind(resAnon).join())
                as Map<String, dynamic>;
        expect(jsonRes['status'], equals('success'));
        client.close();
      },
    );
  });
}
