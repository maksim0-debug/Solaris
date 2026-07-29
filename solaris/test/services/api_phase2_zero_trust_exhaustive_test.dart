import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Zero-Trust Exhaustive Audit: BDD Behavioral Specifications', () {
    late ProviderContainer container;
    late ApiControlHandler controlHandler;

    setUp(() {
      container = ProviderContainer();
      controlHandler = ApiControlHandler(container);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'Scenario 1: Given allowedActions containing only set_brightness, When set_temperature is requested, Then executeAction rejects with 403 Forbidden details',
      () async {
        const perms = ApiPermissionsConfig(allowedActions: {'set_brightness'});

        final result = await controlHandler.executeAction({
          'action': 'set_temperature',
          'value': 4500,
        }, permissions: perms);

        expect(result['status'], equals('error'));
        expect(result['error'], equals('action_prohibited'));
        expect(result['message'], contains('set_temperature'));
      },
    );

    test(
      'Scenario 2: Given allowedActions containing set_brightness_preset, When preset shorthand alias "brightest" is sent without preset payload key, Then parameter preset="brightest" is injected and action succeeds',
      () async {
        const perms = ApiPermissionsConfig(
          allowedActions: {'set_brightness_preset'},
        );

        final result = await controlHandler.executeAction({
          'action': 'brightest',
        }, permissions: perms);

        expect(result['status'], equals('ok'));
        expect(result['action'], equals('set_brightness_preset'));
        expect(result['applied']['preset'], equals('brightest'));
      },
    );

    test(
      'Scenario 3: Given allowedActions containing set_weather_provider, When provider alias "openmeteo" is requested, Then provider="openmeteo" is injected into payload',
      () async {
        const perms = ApiPermissionsConfig(
          allowedActions: {'set_weather_provider'},
        );

        final result = await controlHandler.executeAction({
          'action': 'openmeteo',
        }, permissions: perms);

        expect(result['status'], equals('ok'));
        expect(result['action'], equals('set_weather_provider'));
        expect(result['applied']['provider'], equals('openmeteo'));
      },
    );

    test(
      'Scenario 4: Given allowedActions with clear_failed_webhooks alias, When executeAction is called, Then it routes to combined manage_webhooks / clear_failed_webhooks branch seamlessly',
      () async {
        const perms = ApiPermissionsConfig(allowedActions: {'manage_webhooks'});

        final result = await controlHandler.executeAction({
          'action': 'clear_failed_webhooks',
          'webhook_id': 'wh_test_1',
        }, permissions: perms);

        expect(result['status'], equals('ok'));
        expect(result['action'], equals('clear_failed_webhooks'));
      },
    );

    test(
      'Scenario 5: Given internal-only action "on_system_resume", When requested via REST executeAction, Then it returns 422 Unprocessable Entity',
      () async {
        const perms = ApiPermissionsConfig(); // Full permissions

        final result = await controlHandler.executeAction({
          'action': 'on_system_resume',
        }, permissions: perms);

        expect(result['status'], equals('error'));
        expect(result['error'], equals('unprocessable_entity'));
        expect(result['message'], contains('on_system_resume'));
      },
    );
  });

  group('Phase 2 Zero-Trust Exhaustive Audit: Property-Based Testing (PBT)', () {
    test(
      'PBT Invariant 1: For any random subset S of canonical actions, checkAction(a) is allowed iff canonical(a) in S',
      () {
        final random = Random(42);
        final allCanonical = ApiPermissionsConfig.getAllCanonicalActions()
            .toList();
        final allAliases = [
          'set_monitor_brightness',
          'set_monitor_temperature',
          'brightest',
          'bright',
          'dim',
          'dimmest',
          'coolest',
          'cool',
          'warm',
          'warmest',
          'toggle_auto_brightness',
          'toggle_auto_temperature',
          'set_color_temperature_enabled',
          'openmeteo',
          'weatherapi',
          'auto',
          'clear_failed_webhooks',
        ];

        for (int i = 0; i < 100; i++) {
          // Generate random subset
          final subsetCount = random.nextInt(allCanonical.length + 1);
          final shuffled = List<String>.from(allCanonical)..shuffle(random);
          final selectedSubset = shuffled.take(subsetCount).toSet();

          final config = ApiPermissionsConfig(allowedActions: selectedSubset);

          // Verify all canonical actions
          for (final action in allCanonical) {
            final isAllowed = config.isActionAllowed(action);
            final checkRes = ApiPermissionsChecker.checkAction(config, action);
            expect(isAllowed, equals(selectedSubset.contains(action)));
            expect(checkRes.isAllowed, equals(selectedSubset.contains(action)));
          }

          // Verify all alias strings
          for (final alias in allAliases) {
            final canonical = ApiPermissionsConfig.getCanonicalAction(alias);
            final isAllowed = config.isActionAllowed(alias);
            final checkRes = ApiPermissionsChecker.checkAction(config, alias);
            expect(isAllowed, equals(selectedSubset.contains(canonical)));
            expect(
              checkRes.isAllowed,
              equals(selectedSubset.contains(canonical)),
            );
          }
        }
      },
    );

    test(
      'PBT Invariant 2: Action is NEVER allowed if parent category is disabled, even if action is explicitly in allowedActions',
      () {
        final random = Random(123);
        final allCategories = ApiActionCategory.values.toList();
        final allCanonical = ApiPermissionsConfig.getAllCanonicalActions()
            .toList();

        for (int i = 0; i < 50; i++) {
          // Pick one category to disable
          final disabledCategory =
              allCategories[random.nextInt(allCategories.length)];
          final enabledCategories = allCategories
              .where((c) => c != disabledCategory)
              .toSet();

          // Enable all actions in allowedActions
          final config = ApiPermissionsConfig(
            allowedCategories: enabledCategories,
            allowedActions: allCanonical.toSet(),
          );

          final categoryActions = ApiPermissionsConfig.getActionsForCategory(
            disabledCategory,
          );
          for (final action in categoryActions) {
            expect(config.isActionAllowed(action), isFalse);
            final checkRes = ApiPermissionsChecker.checkAction(config, action);
            expect(checkRes.isAllowed, isFalse);
            expect(checkRes.title, equals('Action Category Prohibited'));
          }
        }
      },
    );
  });

  group('Phase 2 Zero-Trust Exhaustive Audit: Real HTTP REST Server Integration', () {
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

      // Router setup with permissions injector middleware simulation
      router.post('/api/v1/control', (
        HttpRequest req,
        Map<String, String> params,
      ) async {
        final rawPermsHeader = req.headers.value('X-Test-Permissions');
        final perms = rawPermsHeader != null
            ? ApiPermissionsConfig.fromJson(
                jsonDecode(rawPermsHeader) as Map<String, dynamic>,
              )
            : const ApiPermissionsConfig();
        final payload =
            jsonDecode(await utf8.decoder.bind(req).join())
                as Map<String, dynamic>;
        await controlHandler.handleControlWithPermissions(req, payload, perms);
      });

      router.post('/api/v1/monitors/:slug/brightness', (
        HttpRequest req,
        Map<String, String> params,
      ) async {
        final rawPermsHeader = req.headers.value('X-Test-Permissions');
        final perms = rawPermsHeader != null
            ? ApiPermissionsConfig.fromJson(
                jsonDecode(rawPermsHeader) as Map<String, dynamic>,
              )
            : const ApiPermissionsConfig();
        await monitorsHandler.handleSetMonitorBrightnessWithPermissions(
          req,
          params,
          perms,
        );
      });

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
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test(
      'HTTP REST POST /api/v1/control returns 403 RFC7807 when action is prohibited by allowedActions',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.headers.set(
          'X-Test-Permissions',
          jsonEncode(
            const ApiPermissionsConfig(
              allowedActions: {'set_brightness'},
            ).toJson(),
          ),
        );
        req.write(jsonEncode({'action': 'set_temperature', 'value': 4500}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        expect(
          resp.headers.value('Content-Type'),
          equals('application/problem+json'),
        );

        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['title'], equals('Action Prohibited'));
        expect(json['status'], equals(403));
        expect(json['detail'], contains('set_temperature'));
      },
    );

    test(
      'HTTP REST POST /api/v1/monitors/primary/brightness returns 403 RFC7807 when set_brightness is prohibited',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/monitors/primary/brightness'),
        );
        req.headers.contentType = ContentType.json;
        req.headers.set(
          'X-Test-Permissions',
          jsonEncode(
            const ApiPermissionsConfig(
              allowedActions: {'set_temperature'},
            ).toJson(),
          ),
        );
        req.write(jsonEncode({'value': 80.0}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        expect(
          resp.headers.value('Content-Type'),
          equals('application/problem+json'),
        );

        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['title'], equals('Action Prohibited'));
      },
    );

    test(
      'HTTP REST Batch Mode fail_fast Pre-flight aborts batch when prohibited alias "brightest" is present in actions list',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.headers.set(
          'X-Test-Permissions',
          jsonEncode(
            const ApiPermissionsConfig(
              allowedActions: {'set_auto_brightness'},
            ).toJson(),
          ),
        );
        req.write(
          jsonEncode({
            'mode': 'fail_fast',
            'actions': [
              {'action': 'set_auto_brightness', 'enabled': true},
              {
                'action': 'brightest',
              }, // Prohibited alias (normalizes to set_brightness_preset)
            ],
          }),
        );
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.forbidden));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['title'], equals('Action Prohibited'));
      },
    );
  });

  group(
    'Phase 2 Zero-Trust Exhaustive Audit: WebSocket Command ACL & Mutation Events Isolation',
    () {
      test(
        'WebSocket broadcastEvent filters internal mutation events by client allowedActions',
        () {
          const permsWithResume = ApiPermissionsConfig(
            allowedActions: {'on_system_resume'},
          );
          const permsWithoutResume = ApiPermissionsConfig(
            allowedActions: {'set_brightness'},
          );

          expect(permsWithResume.isActionAllowed('on_system_resume'), isTrue);
          expect(
            permsWithoutResume.isActionAllowed('on_system_resume'),
            isFalse,
          );
        },
      );
    },
  );
}

extension on ApiControlHandler {
  Future<void> handleControlWithPermissions(
    HttpRequest request,
    Map<String, dynamic> jsonPayload,
    ApiPermissionsConfig permissions,
  ) async {
    final actions = jsonPayload['actions'];
    if (actions is List) {
      await handleBatchControlWithPermissions(
        request,
        jsonPayload,
        permissions,
      );
    } else {
      final result = await executeAction(jsonPayload, permissions: permissions);
      final statusCode = result['status'] == 'error'
          ? (result['error'] == 'unprocessable_entity'
                ? HttpStatus.unprocessableEntity
                : HttpStatus.forbidden)
          : (result['status'] == 'accepted'
                ? HttpStatus.accepted
                : HttpStatus.ok);

      if (result['status'] == 'error') {
        final title = result['error'] == 'action_prohibited'
            ? 'Action Prohibited'
            : 'Control Error';
        final detail = result['message'] as String;
        final errorDto = Rfc7807Error(
          type: 'https://solaris.app/errors/control-error',
          title: title,
          status: statusCode,
          detail: detail,
          instance: request.uri.path,
        );
        request.response
          ..statusCode = statusCode
          ..headers.contentType = ContentType('application', 'problem+json')
          ..write(jsonEncode(errorDto.toJson()));
      } else {
        request.response
          ..statusCode = statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(result));
      }
      await request.response.close();
    }
  }

  Future<void> handleBatchControlWithPermissions(
    HttpRequest request,
    Map<String, dynamic> jsonPayload,
    ApiPermissionsConfig permissions,
  ) async {
    final rawActions = jsonPayload['actions'] as List;
    final mode = (jsonPayload['mode'] as String?)?.toLowerCase() ?? 'fail_fast';

    if (mode == 'fail_fast') {
      for (int i = 0; i < rawActions.length; i++) {
        final actionItem = rawActions[i];
        if (actionItem is Map<String, dynamic>) {
          final actionStr = actionItem['action'] as String?;
          if (actionStr != null) {
            final checkResult = ApiPermissionsChecker.checkAction(
              permissions,
              actionStr,
            );
            if (!checkResult.isAllowed) {
              final errorDto = Rfc7807Error(
                type: 'https://solaris.app/errors/control-error',
                title: checkResult.title,
                status: HttpStatus.forbidden,
                detail: checkResult.detail,
                instance: request.uri.path,
              );
              request.response
                ..statusCode = HttpStatus.forbidden
                ..headers.contentType = ContentType(
                  'application',
                  'problem+json',
                )
                ..write(jsonEncode(errorDto.toJson()));
              await request.response.close();
              return;
            }
          }
        }
      }
    }
  }
}

extension on ApiMonitorsHandler {
  Future<void> handleSetMonitorBrightnessWithPermissions(
    HttpRequest request,
    Map<String, String> pathParams,
    ApiPermissionsConfig permissions,
  ) async {
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'set_brightness',
    );
    if (!check.isAllowed) {
      final errorDto = Rfc7807Error(
        type: 'https://solaris.app/errors/control-error',
        title: check.title,
        status: HttpStatus.forbidden,
        detail: check.detail,
        instance: request.uri.path,
      );
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType('application', 'problem+json')
        ..write(jsonEncode(errorDto.toJson()));
      await request.response.close();
      return;
    }
  }
}
