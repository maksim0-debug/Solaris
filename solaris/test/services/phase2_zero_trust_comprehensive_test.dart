import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';
import 'package:solaris/services/websocket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 - Scoped API Keys, Middleware & Routing Engine Comprehensive Zero-Trust Verification', () {
    late ProviderContainer container;
    late ApiRouter router;
    late HttpServer server;
    late WebSocketService wsService;
    late ApiControlHandler controlHandler;
    late ApiStatusHandler statusHandler;
    late String serverUrl;
    late String wsUrl;
    late HttpClient httpClient;

    setUp(() async {
      HttpOverrides.global = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '.';
        },
      );
      container = ProviderContainer();
      await container.read(settingsProvider.future);

      router = ApiRouter();
      wsService = container.read(webSocketServiceProvider);
      controlHandler = ApiControlHandler(container);
      statusHandler = ApiStatusHandler(container);

      router.use((req) => corsMiddleware(req, router));
      router.use((req) => authMiddleware(req, router));

      router.get('/api/v1/health', (req, params) => statusHandler.handleHealth(req, params));
      router.get('/api/v1/status', (req, params) => statusHandler.handleStatus(req, params));
      router.get('/api/v1/openapi.json', (req, params) => statusHandler.handleOpenApiJson(req, params));
      router.post('/api/v1/control', (req, params) => controlHandler.handleControl(req, params));

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';
      wsUrl = 'ws://localhost:${server.port}/api/v1/ws';

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/v1/ws') {
          await wsService.handleUpgrade(request, router: router, isLanEnabled: false);
          return;
        }

        final handled = await router.handle(request);
        if (!handled) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      });

      // Synchronize router state and websocket audits with settings
      final globalState = container.read(settingsProvider).value?['all'] ?? SettingsState();
      router.apiKeys = globalState.apiKeys;
      router.requireLocalToken = globalState.requireLocalToken;

      container.listen<AsyncValue<Map<String, SettingsState>>>(
        settingsProvider,
        (previous, next) {
          final nextSettings = next.value?['all'];
          if (nextSettings != null) {
            router.apiKeys = nextSettings.apiKeys;
            router.requireLocalToken = nextSettings.requireLocalToken;
          }
        },
      );

      httpClient = HttpClient();
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      httpClient.close(force: true);
      wsService.closeAll();
      await server.close(force: true);
      container.dispose();
    });

    // =========================================================================
    // 1. CONSTANT-TIME LOOKUP & APIKEYENTRY INVARIANTS
    // =========================================================================
    group('1. Constant-Time Lookup & Key Matching', () {
      test('findMatchingKey accurately resolves valid tokens and rejects invalid tokens', () {
        final key1 = ApiKeyEntry.create(name: 'Key 1');
        final key2 = ApiKeyEntry.create(name: 'Key 2');
        router.apiKeys = [key1, key2];

        expect(router.findMatchingKey(key1.token), equals(key1));
        expect(router.findMatchingKey(key2.token), equals(key2));
        expect(router.findMatchingKey('invalid_token_123'), isNull);
        expect(router.findMatchingKey(null), isNull);
        expect(router.findMatchingKey(''), isNull);
      });

      test('Single Key Protection Guard prevents deleting the last remaining API key', () {
        final notifier = container.read(settingsProvider.notifier);
        final globalState = container.read(settingsProvider).value!['all']!;
        if (globalState.apiKeys.length > 1) {
          for (int i = globalState.apiKeys.length - 1; i > 0; i--) {
            notifier.removeApiKey(globalState.apiKeys[i].id);
          }
        }

        final keys = container.read(settingsProvider).value!['all']!.apiKeys;
        expect(keys.length, equals(1));

        final soleKeyId = keys.first.id;
        final result = notifier.removeApiKey(soleKeyId);
        expect(result, isFalse, reason: 'Single Key Guard must prevent deleting the sole remaining key');

        final updatedKeys = container.read(settingsProvider).value!['all']!.apiKeys;
        expect(updatedKeys.length, equals(1));
        expect(updatedKeys.first.id, equals(soleKeyId));
      });
    });

    // =========================================================================
    // 2. HTTP AUTH & CORS MIDDLEWARE RULES
    // =========================================================================
    group('2. HTTP Auth & CORS Middleware Rules', () {
      test('OPTIONS CORS preflight bypasses auth check with 200 OK or 204 No Content', () async {
        final req = await httpClient.openUrl('OPTIONS', Uri.parse('$serverUrl/api/v1/control'));
        req.headers.set('Origin', 'http://localhost');
        final resp = await req.close();
        expect(resp.statusCode, equals(HttpStatus.noContent));
      });

      test('Invalid token on loopback is rejected with 401 Unauthorized', () async {
        final req = await httpClient.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.set('X-API-Key', 'sol_sec_invalid_token_123456');
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_auto_brightness', 'enabled': true}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.unauthorized));
        final bodyStr = await resp.transform(utf8.decoder).join();
        expect(bodyStr, contains('Invalid API token provided'));
      });

      test('Valid Scoped Key enforces permissions on mutating endpoints (403 when Read-Only)', () async {
        final readOnlyKey = ApiKeyEntry.create(
          name: 'Read Only Key',
          permissions: const ApiPermissionsConfig(isReadOnly: true),
        );
        container.read(settingsProvider.notifier).addApiKey(readOnlyKey);
        router.apiKeys = container.read(settingsProvider).value!['all']!.apiKeys;

        final req = await httpClient.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.set('X-API-Key', readOnlyKey.token);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_auto_brightness', 'enabled': true}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final bodyStr = await resp.transform(utf8.decoder).join();
        expect(bodyStr, contains('Read-Only'));
      });

      test('Require Local Token setting blocks tokenless loopback calls', () async {
        container.read(settingsProvider.notifier).updateRequireLocalToken(true);
        router.requireLocalToken = true;

        final req = await httpClient.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_auto_brightness', 'enabled': true}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.unauthorized));
      });

      test('OpenAPI spec endpoint adapts dynamically to requested API Key permissions', () async {
        final limitedKey = ApiKeyEntry.create(
          name: 'Limited Key',
          permissions: const ApiPermissionsConfig(
            allowReadSolar: true,
            allowReadMonitors: false,
          ),
        );
        container.read(settingsProvider.notifier).addApiKey(limitedKey);
        router.apiKeys = container.read(settingsProvider).value!['all']!.apiKeys;

        final req = await httpClient.getUrl(Uri.parse('$serverUrl/api/v1/openapi.json'));
        req.headers.set('X-API-Key', limitedKey.token);
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.ok));
        final specJson = jsonDecode(await resp.transform(utf8.decoder).join()) as Map<String, dynamic>;
        final paths = specJson['paths'] as Map<String, dynamic>;

        final monitorGet = (paths['/api/v1/monitors'] as Map<String, dynamic>)['get']['responses'] as Map<String, dynamic>;
        expect(monitorGet.containsKey('403'), isTrue, reason: 'Disabled category must specify 403 Forbidden response');
      });
    });

    // =========================================================================
    // 3. PRIVILEGE ESCALATION PROTECTION
    // =========================================================================
    group('3. Privilege Escalation Protection', () {
      test('POST /api/v1/control rejects payloads containing privilege escalation keys', () async {
        final validKey = ApiKeyEntry.create(name: 'Valid Key');
        container.read(settingsProvider.notifier).addApiKey(validKey);
        router.apiKeys = container.read(settingsProvider).value!['all']!.apiKeys;

        final req = await httpClient.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.set('X-API-Key', validKey.token);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'action': 'set_auto_brightness',
          'enabled': true,
          'apiKeys': [
            {'id': 'hacked', 'name': 'Admin Key'}
          ]
        }));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final bodyStr = await resp.transform(utf8.decoder).join();
        expect(bodyStr, contains('Privilege Escalation Prohibited'));
      });

      test('Batch action payload with nested escalation key is recursively blocked', () async {
        final validKey = ApiKeyEntry.create(name: 'Valid Key');
        container.read(settingsProvider.notifier).addApiKey(validKey);
        router.apiKeys = container.read(settingsProvider).value!['all']!.apiKeys;

        final req = await httpClient.postUrl(Uri.parse('$serverUrl/api/v1/control'));
        req.headers.set('X-API-Key', validKey.token);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'actions': [
            {
              'action': 'set_auto_brightness',
              'enabled': true,
              'permissions': {'isReadOnly': false}
            }
          ]
        }));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
      });
    });

    // =========================================================================
    // 4. WEBSOCKET ISOLATION & REACTIVE REVOCATION
    // =========================================================================
    group('4. WebSocket Isolation & Reactive Revocation', () {
      test('WebSocket upgrade with invalid token is immediately rejected with 401', () async {
        expect(
          () => WebSocket.connect('$wsUrl?token=invalid_ws_token_99999'),
          throwsA(isA<WebSocketException>()),
        );
      });

      test('WebSocket authenticates via Sec-WebSocket-Protocol header', () async {
        final wsKey = ApiKeyEntry.create(name: 'WS Protocol Key');
        container.read(settingsProvider.notifier).addApiKey(wsKey);
        router.apiKeys = container.read(settingsProvider).value!['all']!.apiKeys;

        final ws = await WebSocket.connect(
          wsUrl,
          protocols: ['bearer.${wsKey.token}'],
        );

        final firstMsg = await ws.first.timeout(const Duration(seconds: 2));
        final jsonMap = jsonDecode(firstMsg as String) as Map<String, dynamic>;
        expect(['snapshot', 'update'], contains(jsonMap['type']));

        await ws.close();
      });
    });
  });
}
