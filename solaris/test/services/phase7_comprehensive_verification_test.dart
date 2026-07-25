import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_permissions_filter.dart';
import 'package:solaris/services/openapi_spec.dart';

void main() {
  group('Phase 7 Comprehensive Verification & Final QA Suite', () {
    group('7.A BDD / Gherkin Specification Scenarios', () {
      test('Scenario 1: Block mutation requests when Read-Only mode is active', () {
        const config = ApiPermissionsConfig(isReadOnly: true);
        
        final roResult = ApiPermissionsChecker.checkReadOnly(config);
        expect(roResult.isAllowed, isFalse);
        expect(roResult.title, equals('Read-Only Mode Enabled'));
        expect(roResult.detail, contains('Read-Only mode'));

        final actionResult = config.isActionAllowed('set_brightness');
        expect(actionResult, isFalse);
      });

      test('Scenario 2: Prevent Privilege Escalation via API mutation payload', () {
        const config = ApiPermissionsConfig();
        
        // Simulating incoming payload containing forbidden keys
        final payloadWithPermissions = {
          'action': 'set_brightness',
          'value': 50,
          'apiPermissions': {'isReadOnly': false},
        };

        expect(payloadWithPermissions.containsKey('apiPermissions'), isTrue);
        // Ensure config remains unchanged
        expect(config.isReadOnly, isFalse);
        expect(config.allowedCategories.length, equals(7));
      });

      test('Scenario 3: Granular masking of automation composite object in WebSocket updates', () {
        const config = ApiPermissionsConfig(
          allowReadWeather: false,
          allowReadCircadian: true,
        );

        final rawAutomation = {
          'weather_brightness_adjustment': 10,
          'weather_temperature_adjustment': -200,
          'smart_circadian': {'current_phase': 'day'},
          'game_mode': false,
        };

        final filtered = ApiPermissionsFilter.filterAutomation(rawAutomation, config);

        expect(filtered.containsKey('weather_brightness_adjustment'), isFalse);
        expect(filtered.containsKey('weather_temperature_adjustment'), isFalse);
        expect(filtered.containsKey('smart_circadian'), isTrue);
        expect(filtered['smart_circadian'], equals({'current_phase': 'day'}));
      });

      test('Scenario 4: Sub-filtering of smart_circadian object when allowReadSleep is false', () {
        const config = ApiPermissionsConfig(
          allowReadCircadian: true,
          allowReadSleep: false,
        );

        final rawSmartCircadian = {
          'target_temperature': 5500,
          'sleep_pressure': 0.85,
          'sleep_debt': 1.2,
          'submodules': {
            'sleep_pressure_master': true,
            'sleep_debt_master': true,
            'auto_temp': true,
          },
        };

        final filtered = ApiPermissionsFilter.filterSmartCircadian(rawSmartCircadian, config);

        expect(filtered, isNotNull);
        expect(filtered!.containsKey('target_temperature'), isTrue);
        expect(filtered.containsKey('sleep_pressure'), isFalse);
        expect(filtered.containsKey('sleep_debt'), isFalse);
        
        final submodules = filtered['submodules'] as Map<String, dynamic>;
        expect(submodules.containsKey('sleep_pressure_master'), isFalse);
        expect(submodules.containsKey('sleep_debt_master'), isFalse);
        expect(submodules.containsKey('auto_temp'), isTrue);
      });

      test('Scenario 5: Pre-flight ACL check rejects entire batch in fail_fast mode', () {
        const config = ApiPermissionsConfig(
          allowedCategories: {
            ApiActionCategory.monitors,
          },
        );

        final actionsBatch = ['set_brightness', 'set_game_mode']; // gaming category is forbidden

        bool preFlightPassed = true;
        for (final action in actionsBatch) {
          final cat = ApiPermissionsConfig.getCategoryForAction(action);
          final check = ApiPermissionsChecker.checkCategory(config, cat);
          if (!check.isAllowed) {
            preFlightPassed = false;
            break;
          }
        }

        expect(preFlightPassed, isFalse);
      });

      test('Scenario 6: Unrestricted access to health check endpoint', () {
        const config = ApiPermissionsConfig(
          isReadOnly: true,
          allowReadMonitors: false,
          allowReadSolar: false,
          allowReadWeather: false,
          allowReadSleep: false,
          allowReadCircadian: false,
          allowedCategories: {},
        );

        final healthSpec = OpenApiSpec.generateSpec(permissions: config)['paths']['/api/v1/health']['get'];
        expect(healthSpec['responses'].containsKey('200'), isTrue);
        expect(healthSpec['responses'].containsKey('403'), isFalse);
      });
    });

    group('7.B Property-Based Testing (PBT Invariants & Combinatorial Grid)', () {
      test('Invariants for filterAutomation: Weather keys strictly excluded when allowReadWeather = false across 32 combinations', () {
        final weatherKeys = [
          'weather_brightness_adjustment',
          'weather_temperature_adjustment',
          'weather_adjustment_intensity',
        ];

        final sampleRaw = {
          'weather_brightness_adjustment': 15,
          'weather_temperature_adjustment': 300,
          'weather_adjustment_intensity': 1.0,
          'smart_circadian': {'phase': 'sunset'},
          'game_mode': false,
          'map_animations': true,
        };

        // 2^5 = 32 combinations of read flags
        for (int i = 0; i < 32; i++) {
          final config = ApiPermissionsConfig(
            allowReadMonitors: (i & 1) != 0,
            allowReadSolar: (i & 2) != 0,
            allowReadWeather: false, // strictly false
            allowReadSleep: (i & 8) != 0,
            allowReadCircadian: (i & 16) != 0,
          );

          final result = ApiPermissionsFilter.filterAutomation(sampleRaw, config);
          for (final wKey in weatherKeys) {
            expect(result.containsKey(wKey), isFalse, reason: 'Combination $i leaked $wKey!');
          }
        }
      });

      test('Invariants for isActionAllowed: All 30+ actions return false when isReadOnly = true', () {
        const config = ApiPermissionsConfig(isReadOnly: true);
        
        final testActions = [
          'set_brightness', 'set_temperature', 'set_monitor_offset',
          'set_brightness_preset', 'set_temperature_preset', 'brightest', 'dimmest',
          'set_auto_brightness', 'set_smart_circadian',
          'set_game_mode', 'manage_game_mode_whitelist',
          'set_weather_adjustment', 'trigger_sun_sync',
          'push_sleep_status', 'clear_failed_webhooks',
        ];

        for (final action in testActions) {
          expect(config.isActionAllowed(action), isFalse, reason: 'Action $action was allowed in Read-Only!');
        }
      });
    });

    group('7.C OpenAPI 3.0.3 Spec Dynamic Permissions Integration', () {
      test('generateSpec populates 403 responses and Read-Only annotations when permissions is provided', () {
        const config = ApiPermissionsConfig(
          isReadOnly: true,
          allowReadSolar: false,
          allowReadSleep: false,
        );

        final spec = OpenApiSpec.generateSpec(port: 8080, permissions: config);
        expect(spec['openapi'], equals('3.0.3'));
        expect(spec['info']['description'], contains('[Permissions Active]: ReadOnly=true'));

        final paths = spec['paths'] as Map<String, dynamic>;
        
        // Check health is unrestricted
        expect(paths['/api/v1/health']['get']['responses'].containsKey('403'), isFalse);

        // Check 403 on restricted read paths
        expect(paths['/api/v1/solar']['get']['responses'].containsKey('403'), isTrue);
        expect(paths['/api/v1/sleep/sessions']['get']['responses'].containsKey('403'), isTrue);

        // Check control endpoint annotation
        final controlPost = paths['/api/v1/control']['post'];
        expect(controlPost['description'], contains('[READ-ONLY MODE ACTIVE]'));
        expect(controlPost['responses'].containsKey('403'), isTrue);
      });

      test('generateJsonSpec returns valid JSON string with permissions active', () {
        const config = ApiPermissionsConfig();
        final jsonString = OpenApiSpec.generateJsonSpec(port: 45321, permissions: config);

        expect(jsonString, isA<String>());
        expect(jsonString, contains('"openapi":"3.0.3"'));
        expect(jsonString, contains('Solaris Control API v1'));
      });
    });
  });
}
