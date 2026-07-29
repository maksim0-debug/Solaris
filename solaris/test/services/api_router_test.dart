import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_settings.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/openapi_spec.dart';

void main() {
  group('ApiRouter Unit & Constant-time Auth Tests', () {
    test(
      'constantTimeEquals securely compares tokens and handles empty tokens',
      () {
        expect(constantTimeEquals('secret123', 'secret123'), isTrue);
        expect(constantTimeEquals('secret123', 'wrongtoken'), isFalse);
        expect(constantTimeEquals('', 'secret123'), isFalse);
        expect(constantTimeEquals('secret123', ''), isFalse);
        expect(constantTimeEquals('', ''), isFalse);
        expect(constantTimeEquals('a', 'a'), isTrue);
        expect(constantTimeEquals('a', 'b'), isFalse);
      },
    );

    test('Rfc7807Error serializes correctly to JSON', () {
      final error = Rfc7807Error(
        type: 'https://solaris.local/errors/unauthorized',
        title: 'Unauthorized',
        status: HttpStatus.unauthorized,
        detail: 'Invalid API token provided.',
        instance: '/api/v1/status',
        invalidParams: {'X-API-Key': 'Token expired'},
      );

      final json = error.toJson();
      expect(json['type'], equals('https://solaris.local/errors/unauthorized'));
      expect(json['title'], equals('Unauthorized'));
      expect(json['status'], equals(HttpStatus.unauthorized));
      expect(json['detail'], equals('Invalid API token provided.'));
      expect(json['instance'], equals('/api/v1/status'));
      expect(json['invalid_params'], isNotNull);
      expect(json['timestamp'], isNotNull);

      final jsonString = error.toJsonString();
      expect(jsonString, contains('"status":401'));
      expect(jsonString, contains('"title":"Unauthorized"'));
    });

    test(
      'ApiSettings value object getters and binding address behave as expected',
      () {
        const settings1 = ApiSettings(
          port: 45321,
          isLanAccessEnabled: false,
          accessToken: 'test-token',
          rateLimitPerMinute: 120,
        );
        expect(settings1.bindAddress, equals(InternetAddress.loopbackIPv4));

        const settings2 = ApiSettings(
          port: 45321,
          isLanAccessEnabled: true,
          accessToken: 'test-token',
          rateLimitPerMinute: 120,
        );
        expect(settings2.bindAddress, equals(InternetAddress.anyIPv4));
      },
    );

    test('OpenApiSpec generates valid spec structure', () {
      final spec = OpenApiSpec.generateSpec(port: 45321);
      expect(spec['openapi'], equals('3.0.3'));
      expect(spec['info'], isNotNull);
      expect(spec['info']['title'], equals('Solaris Control API v1'));
      expect(spec['paths'], isNotNull);
      expect(spec['paths']['/api/v1/status'], isNotNull);
      expect(spec['paths']['/api/v1/health'], isNotNull);
      expect(spec['paths']['/api/v1/control'], isNotNull);
    });
  });

  group('ApiRouter HTTP Server Integration Harness', () {
    late HttpServer server;
    late ApiRouter router;
    late HttpClient client;
    late String serverUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';
      router = ApiRouter();
      router.expectedToken = 'supersecret_api_key_123';
      router.requireLocalToken = true;

      // Register standard middlewares
      router.use(securityHeadersMiddleware);
      router.use(payloadSizeGuardMiddleware);
      router.use(contentTypeGuardMiddleware);
      router.use(hostHeaderValidationMiddleware);
      router.use((req) => corsMiddleware(req, router));
      router.use((req) => authMiddleware(req, router));
      router.use(rateLimiterMiddleware);

      // Dummy routes
      router.get('/api/v1/health', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'ok'});
      });

      router.get('/api/v1/monitors/:slug', (req, params) async {
        final slug = params['slug'];
        if (slug == 'unknown') {
          ApiRouter.sendRfc7807(
            req,
            Rfc7807Error(
              type: 'about:blank',
              title: 'Not Found',
              status: HttpStatus.notFound,
              detail: 'Monitor not found',
              instance: req.uri.path,
            ),
          );
          return;
        }
        ApiRouter.sendJson(req, HttpStatus.ok, {
          'slug': slug,
          'name': 'Test Display',
        });
      });

      router.post('/api/v1/control', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'executed'});
      });

      server.listen((HttpRequest request) async {
        final handled = await router.handle(request);
        if (!handled) {
          ApiRouter.sendRfc7807(
            request,
            Rfc7807Error(
              type: 'about:blank',
              title: 'Not Found',
              status: HttpStatus.notFound,
              detail: 'Route not found',
              instance: request.uri.path,
            ),
          );
        }
      });

      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    test(
      'GET /api/v1/health responds with 200 without authentication (Public endpoint)',
      () async {
        final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/health'));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        expect(resp.headers.value('X-Content-Type-Options'), equals('nosniff'));
        expect(resp.headers.value('X-Frame-Options'), equals('SAMEORIGIN'));

        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['status'], equals('ok'));
      },
    );

    test(
      'GET /api/v1/monitors/:slug extracts path parameter correctly',
      () async {
        final req = await client.getUrl(
          Uri.parse('$serverUrl/api/v1/monitors/display-1'),
        );
        req.headers.set('X-API-Key', 'supersecret_api_key_123');
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['slug'], equals('display-1'));
        expect(json['name'], equals('Test Display'));
      },
    );

    test('GET /api/v1/monitors/unknown returns RFC 7807 404 Error', () async {
      final req = await client.getUrl(
        Uri.parse('$serverUrl/api/v1/monitors/unknown'),
      );
      req.headers.set('X-API-Key', 'supersecret_api_key_123');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.notFound));
      expect(
        resp.headers.value('Content-Type'),
        equals('application/problem+json'),
      );

      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['title'], equals('Not Found'));
      expect(json['status'], equals(404));
      expect(json['detail'], equals('Monitor not found'));
    });

    test(
      'POST without Content-Type: application/json returns 415 Unsupported Media Type',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.set('X-API-Key', 'supersecret_api_key_123');
        // Intentionally omitting application/json
        req.headers.set('Content-Type', 'text/plain');
        req.write('hello');
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.unsupportedMediaType));
        expect(
          resp.headers.value('Content-Type'),
          equals('application/problem+json'),
        );
      },
    );

    test('POST with valid Content-Type and X-API-Key succeeds', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.set('X-API-Key', 'supersecret_api_key_123');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'set_brightness', 'value': 50}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['status'], equals('executed'));
    });

    test('Request with invalid API Token returns 401 Unauthorized', () async {
      final req = await client.getUrl(
        Uri.parse('$serverUrl/api/v1/monitors/display-1'),
      );
      req.headers.set('X-API-Key', 'wrong_token');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.unauthorized));
      expect(
        resp.headers.value('Content-Type'),
        equals('application/problem+json'),
      );
    });

    test('Request with untrusted Host header returns 403 Forbidden', () async {
      final req = await client.getUrl(Uri.parse('$serverUrl/api/v1/health'));
      req.headers.set('Host', 'malicious-domain.com');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      expect(
        resp.headers.value('Content-Type'),
        equals('application/problem+json'),
      );
    });

    test('CORS OPTIONS preflight returns 204 for localhost origin', () async {
      final req = await client.openUrl(
        'OPTIONS',
        Uri.parse('$serverUrl/api/v1/control'),
      );
      req.headers.set('Origin', 'http://localhost:3000');
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.noContent));
      expect(
        resp.headers.value('Access-Control-Allow-Origin'),
        equals('http://localhost:3000'),
      );
      expect(
        resp.headers.value('Access-Control-Allow-Methods'),
        contains('POST'),
      );
    });

    test(
      'Drive-by attack with untrusted browser Origin without token is blocked with 403',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.set('Origin', 'https://evil-website.com');
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_brightness', 'value': 0}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
      },
    );
  });
}
