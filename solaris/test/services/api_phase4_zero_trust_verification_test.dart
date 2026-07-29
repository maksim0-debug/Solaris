import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Phase 4 - Zero-Trust Advanced Verification & Deep Status Filtering QA Test Suite',
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
        router.use((req) => authMiddleware(req, router));
        final statusHandler = ApiStatusHandler(container);
        final monitorsHandler = ApiMonitorsHandler(container);

        // Register Phase 4 routes under test
        router.get(
          '/api/v1/health',
          (req, params) => statusHandler.handleHealth(req, params),
        );
        router.get(
          '/api/v1/status',
          (req, params) => statusHandler.handleStatus(req, params),
        );
        router.get(
          '/api/v1/solar',
          (req, params) => statusHandler.handleSolar(req, params),
        );
        router.get(
          '/api/v1/presets',
          (req, params) => statusHandler.handlePresets(req, params),
        );
        router.get(
          '/api/v1/sleep/sessions',
          (req, params) => statusHandler.handleSleepSessions(req, params),
        );
        router.get(
          '/api/v1/monitors',
          (req, params) => monitorsHandler.handleGetMonitors(req, params),
        );
        router.get(
          '/api/v1/monitors/:slug',
          (req, params) => monitorsHandler.handleGetMonitorBySlug(req, params),
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
        final globalState = container.read(settingsProvider).value?['all'];
        if (globalState != null) {
          router.apiKeys = globalState.apiKeys;
        }
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        client.close(force: true);
        await server.close(force: true);
        container.dispose();
      });

      void updatePermissions(ApiPermissionsConfig permissions) {
        container
            .read(settingsProvider.notifier)
            .updateApiPermissions(permissions);
        final globalState = container.read(settingsProvider).value?['all'];
        if (globalState != null) {
          router.apiKeys = globalState.apiKeys;
        }
      }

      group('A. BDD Behavioral Scenarios — Status & Query Read Protection', () {
        test(
          'Scenario 1: Full Access configuration exposes all root modules in GET /api/v1/status',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(),
            ); // Default: full access

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/status'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.ok));
            final body = jsonDecode(await resp.transform(utf8.decoder).join());

            expect(body.containsKey('monitors'), isTrue);
            expect(body.containsKey('solar'), isTrue);
            expect(body.containsKey('weather'), isTrue);
            expect(body.containsKey('automation'), isTrue);
            expect(body.containsKey('smart_circadian'), isTrue);
            expect(body.containsKey('sleep'), isTrue);
            expect(body.containsKey('server'), isTrue);
          },
        );

        test(
          'Scenario 2: GET /api/v1/health remains 100% public under total Lockdown mode',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(
                isReadOnly: true,
                allowReadMonitors: false,
                allowReadSolar: false,
                allowReadWeather: false,
                allowReadSleep: false,
                allowReadCircadian: false,
                allowedCategories: {},
              ),
            );

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/health'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.ok));
            final body = jsonDecode(await resp.transform(utf8.decoder).join());
            expect(body['status'], equals('ok'));
            expect(body['version'], isNotNull);
            expect(body['uptime_seconds'], isA<int>());
          },
        );

        test(
          'Scenario 3: Granular sub-key masking in automation block when monitors & weather disabled',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(
                allowReadMonitors: false,
                allowReadWeather: false,
                allowReadCircadian: true,
              ),
            );

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/status'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.ok));
            final body = jsonDecode(await resp.transform(utf8.decoder).join());

            final automation = body['automation'] as Map<String, dynamic>;
            expect(automation.containsKey('game_mode'), isFalse);
            expect(automation.containsKey('multi_monitor_offset'), isFalse);
            expect(
              automation.keys.any((k) => k.startsWith('weather_')),
              isFalse,
            );
          },
        );

        test(
          'Scenario 4: Smart Circadian metrics stripping when allowReadSleep is false',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(
                allowReadCircadian: true,
                allowReadSleep: false,
              ),
            );

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/status'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.ok));
            final body = jsonDecode(await resp.transform(utf8.decoder).join());

            expect(body.containsKey('sleep'), isFalse);
            final circadian = body['smart_circadian'] as Map<String, dynamic>;
            expect(circadian.containsKey('sleep_pressure'), isFalse);
            expect(circadian.containsKey('sleep_debt'), isFalse);

            final submodules = circadian['submodules'] as Map<String, dynamic>;
            expect(submodules.containsKey('sleep_pressure_master'), isFalse);
            expect(submodules.containsKey('sleep_debt_master'), isFalse);
          },
        );

        test(
          'Scenario 5: RFC 7807 Header & Payload Validation on Forbidden Read Endpoint',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(allowReadSolar: false),
            );

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/solar'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.forbidden));
            expect(
              resp.headers.value('content-type'),
              contains('application/problem+json'),
            );

            final body = jsonDecode(await resp.transform(utf8.decoder).join());
            expect(body['type'], contains('/errors/'));
            expect(body['title'], equals('Read Access Prohibited'));
            expect(body['status'], equals(403));
            expect(body['detail'], contains('solar'));
          },
        );
      });

      group('B. 32-Permutation Combinatorial Grid Test for GET /api/v1/status', () {
        test(
          'Evaluates all 32 combinations of read flags to ensure zero data leakage',
          () async {
            final flags = [false, true];

            for (final rMonitors in flags) {
              for (final rSolar in flags) {
                for (final rWeather in flags) {
                  for (final rSleep in flags) {
                    for (final rCircadian in flags) {
                      final config = ApiPermissionsConfig(
                        allowReadMonitors: rMonitors,
                        allowReadSolar: rSolar,
                        allowReadWeather: rWeather,
                        allowReadSleep: rSleep,
                        allowReadCircadian: rCircadian,
                        allowedCategories: {
                          if (rMonitors) ApiActionCategory.monitors,
                          if (rSleep) ApiActionCategory.sleep,
                          ApiActionCategory.system,
                        },
                      );
                      updatePermissions(config);

                      final req = await client.getUrl(
                        Uri.parse('$serverUrl/api/v1/status'),
                      );
                      final resp = await req.close();
                      expect(resp.statusCode, equals(HttpStatus.ok));

                      final body = jsonDecode(
                        await resp.transform(utf8.decoder).join(),
                      );

                      // Assertion Invariants
                      expect(
                        body.containsKey('monitors'),
                        equals(rMonitors),
                        reason:
                            'monitors presence must match allowReadMonitors',
                      );
                      expect(
                        body.containsKey('solar'),
                        equals(rSolar),
                        reason: 'solar presence must match allowReadSolar',
                      );
                      expect(
                        body.containsKey('weather'),
                        equals(rWeather),
                        reason: 'weather presence must match allowReadWeather',
                      );
                      expect(
                        body.containsKey('sleep'),
                        equals(rSleep),
                        reason: 'sleep presence must match allowReadSleep',
                      );
                      expect(
                        body.containsKey('smart_circadian'),
                        equals(rCircadian),
                        reason:
                            'smart_circadian presence must match allowReadCircadian',
                      );

                      if (rCircadian && !rSleep) {
                        final circadian =
                            body['smart_circadian'] as Map<String, dynamic>;
                        expect(
                          circadian.containsKey('sleep_pressure'),
                          isFalse,
                        );
                        expect(circadian.containsKey('sleep_debt'), isFalse);
                      }
                    }
                  }
                }
              }
            }
          },
        );
      });

      group('C. Robustness & Security Audit', () {
        test(
          'GET /api/v1/presets returns brightness section when allowReadMonitors is true and allowReadCircadian is false',
          () async {
            updatePermissions(
              const ApiPermissionsConfig(
                allowReadMonitors: true,
                allowReadCircadian: false,
              ),
            );

            final req = await client.getUrl(
              Uri.parse('$serverUrl/api/v1/presets'),
            );
            final resp = await req.close();

            expect(resp.statusCode, equals(HttpStatus.ok));
            final body = jsonDecode(await resp.transform(utf8.decoder).join());
            expect(body.containsKey('brightness'), isTrue);
            expect(body.containsKey('temperature'), isFalse);
          },
        );
      });
    },
  );
}
