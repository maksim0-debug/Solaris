import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  group('SettingsState Decoupled API Toggles & Migration', () {
    test('default state has both API toggles disabled', () {
      final state = SettingsState();
      expect(state.isApiServerEnabled, isFalse);
      expect(state.isSleepIpcServerEnabled, isFalse);
      expect(state.isLocalIpcServerEnabled, isFalse);
    });

    test('legacy isLocalIpcServerEnabled in constructor activates both', () {
      final state = SettingsState(isLocalIpcServerEnabled: true);
      expect(state.isApiServerEnabled, isTrue);
      expect(state.isSleepIpcServerEnabled, isTrue);
      expect(state.isLocalIpcServerEnabled, isTrue);
    });

    test('independent toggles in constructor', () {
      final sleepOnly = SettingsState(isSleepIpcServerEnabled: true);
      expect(sleepOnly.isSleepIpcServerEnabled, isTrue);
      expect(sleepOnly.isApiServerEnabled, isFalse);
      expect(sleepOnly.isLocalIpcServerEnabled, isTrue);

      final apiOnly = SettingsState(isApiServerEnabled: true);
      expect(apiOnly.isApiServerEnabled, isTrue);
      expect(apiOnly.isSleepIpcServerEnabled, isFalse);
      expect(apiOnly.isLocalIpcServerEnabled, isTrue);
    });

    test(
      'deserialization from legacy json migrates isLocalIpcServerEnabled',
      () {
        final json = {
          'isLocalIpcServerEnabled': true,
          'localIpcServerPort': 45321,
        };
        final state = SettingsState.fromJson(json);
        expect(state.isApiServerEnabled, isTrue);
        expect(state.isSleepIpcServerEnabled, isTrue);
        expect(state.isLocalIpcServerEnabled, isTrue);
      },
    );

    test(
      'deserialization with distinct fields preserves independent states',
      () {
        final json = {
          'isApiServerEnabled': false,
          'isSleepIpcServerEnabled': true,
          'isLocalIpcServerEnabled': true,
        };
        final state = SettingsState.fromJson(json);
        expect(state.isApiServerEnabled, isFalse);
        expect(state.isSleepIpcServerEnabled, isTrue);
        expect(state.isLocalIpcServerEnabled, isTrue);
      },
    );

    test('copyWith updates individual flags independently', () {
      final initial = SettingsState();
      final sleepOn = initial.copyWith(isSleepIpcServerEnabled: true);
      expect(sleepOn.isSleepIpcServerEnabled, isTrue);
      expect(sleepOn.isApiServerEnabled, isFalse);

      final apiOn = sleepOn.copyWith(isApiServerEnabled: true);
      expect(apiOn.isSleepIpcServerEnabled, isTrue);
      expect(apiOn.isApiServerEnabled, isTrue);

      final sleepOff = apiOn.copyWith(isSleepIpcServerEnabled: false);
      expect(sleepOff.isSleepIpcServerEnabled, isFalse);
      expect(sleepOff.isApiServerEnabled, isTrue);
    });
  });

  group('Modular Subsystem Routing & 503 RFC7807 Guards', () {
    late HttpServer server;
    late String serverUrl;
    late ApiRouter router;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';
      router = ApiRouter();
      router.requireLocalToken = false;

      router.use(securityHeadersMiddleware);
      router.use((req) => corsMiddleware(req, router));
      router.use((req) => subsystemGuardMiddleware(req, router));
      router.use((req) => authMiddleware(req, router));

      // Public health
      router.get('/api/v1/health', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {
          'status': 'ok',
          'subsystems': {
            'solaris_control': router.isApiServerEnabled,
            'sleep_integration': router.isSleepIpcServerEnabled,
          },
        });
      });

      // Control API endpoint
      router.post('/api/v1/control', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'success'});
      });

      // Sleep API endpoints (both legacy and prefixed)
      router.post('/api/sleep/sessions', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'sessions_recorded'});
      });
      router.post('/api/v1/sleep/sessions', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'sessions_recorded'});
      });
      router.post('/api/sleep/status', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'status_updated'});
      });
      router.post('/api/v1/sleep/status', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'status': 'status_updated'});
      });
      router.get('/api/sleep/status', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'is_sleeping': false});
      });
      router.get('/api/v1/sleep/status', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'is_sleeping': false});
      });
      router.get('/api/v1/sleep/sessions', (req, params) async {
        ApiRouter.sendJson(req, HttpStatus.ok, {'sessions': <dynamic>[]});
      });

      server.listen((request) async {
        final handled = await router.handle(request);
        if (!handled) {
          ApiRouter.sendRfc7807(
            request,
            Rfc7807Error(
              type: 'https://solaris.local/errors/not-found',
              title: 'Not Found',
              status: HttpStatus.notFound,
              detail: 'Route not found',
              instance: request.uri.path,
            ),
          );
        }
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'Sleep ON and Control API OFF: sleep succeeds, control returns 503, health reports subsystems',
      () async {
        router.isSleepIpcServerEnabled = true;
        router.isApiServerEnabled = false;

        // Sleep POST succeeds
        final sleepRes = await http.post(
          Uri.parse('$serverUrl/api/sleep/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([]),
        );
        expect(sleepRes.statusCode, equals(HttpStatus.ok));
        expect(
          jsonDecode(sleepRes.body)['status'],
          equals('sessions_recorded'),
        );

        // Sleep GET succeeds
        final sleepGetRes = await http.get(
          Uri.parse('$serverUrl/api/v1/sleep/sessions'),
        );
        expect(sleepGetRes.statusCode, equals(HttpStatus.ok));

        // Control API POST returns 503 Service Unavailable
        final controlRes = await http.post(
          Uri.parse('$serverUrl/api/v1/control'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'set_brightness', 'value': 50}),
        );
        expect(controlRes.statusCode, equals(HttpStatus.serviceUnavailable));
        final controlBody = jsonDecode(controlRes.body);
        expect(controlBody['title'], equals('Solaris Control API Disabled'));
        expect(
          controlBody['detail'],
          contains('Solaris Control API is currently disabled'),
        );

        // Health endpoint returns 200 OK and reports subsystems accurately
        final healthRes = await http.get(Uri.parse('$serverUrl/api/v1/health'));
        expect(healthRes.statusCode, equals(HttpStatus.ok));
        final healthBody = jsonDecode(healthRes.body);
        expect(healthBody['subsystems']['solaris_control'], isFalse);
        expect(healthBody['subsystems']['sleep_integration'], isTrue);
      },
    );

    test(
      'Sleep OFF and Control API ON: control succeeds, sleep returns 503',
      () async {
        router.isSleepIpcServerEnabled = false;
        router.isApiServerEnabled = true;

        // Control API POST succeeds
        final controlRes = await http.post(
          Uri.parse('$serverUrl/api/v1/control'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'set_brightness', 'value': 50}),
        );
        expect(controlRes.statusCode, equals(HttpStatus.ok));

        // Sleep POST returns 503
        final sleepRes = await http.post(
          Uri.parse('$serverUrl/api/sleep/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([]),
        );
        expect(sleepRes.statusCode, equals(HttpStatus.serviceUnavailable));
        final sleepBody = jsonDecode(sleepRes.body);
        expect(sleepBody['title'], equals('Sleep Integration API Disabled'));
        expect(
          sleepBody['detail'],
          contains('Sleep Integration API is currently disabled'),
        );

        // Sleep GET returns 503
        final sleepGetRes = await http.get(
          Uri.parse('$serverUrl/api/v1/sleep/sessions'),
        );
        expect(sleepGetRes.statusCode, equals(HttpStatus.serviceUnavailable));
      },
    );

    test('Both ON: both succeed', () async {
      router.isSleepIpcServerEnabled = true;
      router.isApiServerEnabled = true;

      final controlRes = await http.post(
        Uri.parse('$serverUrl/api/v1/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      expect(controlRes.statusCode, equals(HttpStatus.ok));

      final sleepRes = await http.post(
        Uri.parse('$serverUrl/api/sleep/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([]),
      );
      expect(sleepRes.statusCode, equals(HttpStatus.ok));
    });

    test('Both OFF: both return 503', () async {
      router.isSleepIpcServerEnabled = false;
      router.isApiServerEnabled = false;

      final controlRes = await http.post(
        Uri.parse('$serverUrl/api/v1/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      expect(controlRes.statusCode, equals(HttpStatus.serviceUnavailable));

      final sleepRes = await http.post(
        Uri.parse('$serverUrl/api/sleep/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([]),
      );
      expect(sleepRes.statusCode, equals(HttpStatus.serviceUnavailable));

      // Health still returns 200 OK
      final healthRes = await http.get(Uri.parse('$serverUrl/api/v1/health'));
      expect(healthRes.statusCode, equals(HttpStatus.ok));
      final healthBody = jsonDecode(healthRes.body);
      expect(healthBody['subsystems']['solaris_control'], isFalse);
      expect(healthBody['subsystems']['sleep_integration'], isFalse);
    });

    test(
      'Trailing slash requests are properly guarded and do not bypass subsystem disabled states',
      () async {
        router.isSleepIpcServerEnabled = false;
        router.isApiServerEnabled = true;

        // Trailing slash sleep POST must still return 503
        final sleepTrailingRes = await http.post(
          Uri.parse('$serverUrl/api/sleep/sessions/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([]),
        );
        expect(
          sleepTrailingRes.statusCode,
          equals(HttpStatus.serviceUnavailable),
        );

        // Trailing slash health check must still return 200 OK when Control API is off
        router.isApiServerEnabled = false;
        final healthTrailingRes = await http.get(
          Uri.parse('$serverUrl/api/v1/health/'),
        );
        expect(healthTrailingRes.statusCode, equals(HttpStatus.ok));
      },
    );

    test(
      'Prefixed sleep routes (/api/v1/sleep/*) are properly handled',
      () async {
        router.isSleepIpcServerEnabled = true;
        router.isApiServerEnabled = false;

        final sleepV1PostRes = await http.post(
          Uri.parse('$serverUrl/api/v1/sleep/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([]),
        );
        expect(sleepV1PostRes.statusCode, equals(HttpStatus.ok));

        final sleepV1StatusRes = await http.post(
          Uri.parse('$serverUrl/api/v1/sleep/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'is_sleeping': true}),
        );
        expect(sleepV1StatusRes.statusCode, equals(HttpStatus.ok));

        router.isSleepIpcServerEnabled = false;
        final sleepV1DisabledRes = await http.post(
          Uri.parse('$serverUrl/api/v1/sleep/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([]),
        );
        expect(
          sleepV1DisabledRes.statusCode,
          equals(HttpStatus.serviceUnavailable),
        );
      },
    );

    test(
      'Non-existent paths return 404 Not Found rather than 503 when Control API is disabled',
      () async {
        router.isSleepIpcServerEnabled = true;
        router.isApiServerEnabled = false;

        final notFoundRes = await http.get(Uri.parse('$serverUrl/api/unknown'));
        expect(notFoundRes.statusCode, equals(HttpStatus.notFound));
      },
    );
  });
}
