import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_permissions_filter.dart';

void main() {
  group('Phase 1: Zero-Trust Comprehensive BDD & Security Audit Suite', () {
    // ------------------------------------------------------------------------
    // SECTION 1: BDD Scenarios (Given / When / Then)
    // ------------------------------------------------------------------------
    group('BDD Specifications', () {
      test('Given default ApiPermissionsConfig, When initialized, Then full access is granted', () {
        // Given
        const config = ApiPermissionsConfig();

        // When / Then
        expect(config.allowReadMonitors, isTrue);
        expect(config.allowReadSolar, isTrue);
        expect(config.allowReadWeather, isTrue);
        expect(config.allowReadSleep, isTrue);
        expect(config.allowReadCircadian, isTrue);
        expect(config.isReadOnly, isFalse);
        expect(config.allowedCategories, hasLength(7));
        expect(config.allowedCategories, containsAll(ApiActionCategory.values));
      });

      test('Given JSON missing apiPermissions key, When deserializing SettingsState, Then fallback to full access', () {
        // Given
        final rawJson = <String, dynamic>{
          'localIpcServerPort': 8080,
        };

        // When
        final state = SettingsState.fromJson(rawJson);

        // Then
        expect(state.apiPermissions, equals(const ApiPermissionsConfig()));
        expect(state.apiPermissions.isReadOnly, isFalse);
        expect(state.apiPermissions.allowedCategories, hasLength(7));
      });

      test('Given isReadOnly = true, When checking any action, Then isActionAllowed returns false', () {
        // Given
        const config = ApiPermissionsConfig(isReadOnly: true);
        final actionsToTest = [
          'set_brightness',
          'set_temperature',
          'brightest',
          'set_smart_circadian',
          'set_game_mode',
          'set_weather_adjustment',
          'push_sleep_status',
          'clear_failed_webhooks',
        ];

        // When & Then
        for (final action in actionsToTest) {
          expect(config.isActionAllowed(action), isFalse, reason: 'Action $action must be prohibited in Read-Only mode');
        }
      });

      test('Given specific category disabled, When evaluating isActionAllowed, Then return false for that category only', () {
        // Given
        const config = ApiPermissionsConfig(
          allowedCategories: {
            ApiActionCategory.monitors,
            ApiActionCategory.presets,
          },
        );

        // When / Then
        expect(config.isActionAllowed('set_brightness'), isTrue);
        expect(config.isActionAllowed('brightest'), isTrue);
        expect(config.isActionAllowed('set_game_mode'), isFalse);
        expect(config.isActionAllowed('push_sleep_status'), isFalse);
        expect(config.isActionAllowed('clear_failed_webhooks'), isFalse);
      });

      test('Given allowReadWeather = false, When filtering automation map, Then weather_* keys are completely removed', () {
        // Given
        const config = ApiPermissionsConfig(allowReadWeather: false);
        final rawAutomation = <String, dynamic>{
          'weather_brightness_adjustment': 15.0,
          'weather_temperature_adjustment': -200,
          'weather_adjustment_intensity': 0.8,
          'game_mode': false,
          'auto_brightness': true,
        };

        // When
        final filtered = ApiPermissionsFilter.filterAutomation(rawAutomation, config);

        // Then
        expect(filtered.containsKey('weather_brightness_adjustment'), isFalse);
        expect(filtered.containsKey('weather_temperature_adjustment'), isFalse);
        expect(filtered.containsKey('weather_adjustment_intensity'), isFalse);
        expect(filtered['game_mode'], isFalse);
        expect(filtered['auto_brightness'], isTrue);
      });

      test('Given allowReadCircadian = false, When filtering automation map, Then circadian & smart_circadian keys are removed', () {
        // Given
        const config = ApiPermissionsConfig(allowReadCircadian: false);
        final rawAutomation = <String, dynamic>{
          'smart_circadian': {'phase': 'day'},
          'circadian_target': 6500,
          'smart_circadian_offset': 100,
          'game_mode': true,
        };

        // When
        final filtered = ApiPermissionsFilter.filterAutomation(rawAutomation, config);

        // Then
        expect(filtered.containsKey('smart_circadian'), isFalse);
        expect(filtered.containsKey('circadian_target'), isFalse);
        expect(filtered.containsKey('smart_circadian_offset'), isFalse);
        expect(filtered['game_mode'], isTrue);
      });

      test('Given allowReadCircadian = true AND allowReadSleep = false, When filtering smart_circadian, Then sleep pressure & debt are stripped', () {
        // Given
        const config = ApiPermissionsConfig(
          allowReadCircadian: true,
          allowReadSleep: false,
        );
        final rawCircadian = <String, dynamic>{
          'phase': 'evening',
          'sleep_pressure': 0.75,
          'sleep_debt': 45,
          'submodules': {
            'sleep_pressure_master': true,
            'sleep_debt_master': true,
            'circadian_master': true,
          },
        };

        // When
        final filtered = ApiPermissionsFilter.filterSmartCircadian(rawCircadian, config);

        // Then
        expect(filtered, isNotNull);
        expect(filtered!.containsKey('sleep_pressure'), isFalse);
        expect(filtered.containsKey('sleep_debt'), isFalse);
        expect(filtered['phase'], equals('evening'));

        final submodules = filtered['submodules'] as Map<String, dynamic>;
        expect(submodules.containsKey('sleep_pressure_master'), isFalse);
        expect(submodules.containsKey('sleep_debt_master'), isFalse);
        expect(submodules['circadian_master'], isTrue);
      });

      test('Given both allowReadMonitors and allowReadCircadian false, When filtering presets, Then return null', () {
        // Given
        const config = ApiPermissionsConfig(
          allowReadMonitors: false,
          allowReadCircadian: false,
        );
        final rawPresets = <String, dynamic>{
          'brightness': {'bright': 100},
          'temperature': {'warm': 3000},
        };

        // When
        final filtered = ApiPermissionsFilter.filterPresets(rawPresets, config);

        // Then
        expect(filtered, isNull);
      });
    });

    // ------------------------------------------------------------------------
    // SECTION 2: Exhaustive 30+ Action to Category Mapping Verification
    // ------------------------------------------------------------------------
    group('Exhaustive Action Category Mapping Audit', () {
      final expectedMappings = <String, ApiActionCategory>{
        // Monitors category
        'set_brightness': ApiActionCategory.monitors,
        'set_temperature': ApiActionCategory.monitors,
        'set_monitor_offset': ApiActionCategory.monitors,

        // Presets category & aliases
        'set_brightness_preset': ApiActionCategory.presets,
        'set_temperature_preset': ApiActionCategory.presets,
        'set_user_preset': ApiActionCategory.presets,
        'cycle_preset': ApiActionCategory.presets,
        'brightest': ApiActionCategory.presets,
        'bright': ApiActionCategory.presets,
        'dim': ApiActionCategory.presets,
        'dimmest': ApiActionCategory.presets,
        'coolest': ApiActionCategory.presets,
        'cool': ApiActionCategory.presets,
        'warm': ApiActionCategory.presets,
        'warmest': ApiActionCategory.presets,

        // Circadian category
        'set_auto_brightness': ApiActionCategory.circadian,
        'toggle_auto_brightness': ApiActionCategory.circadian,
        'set_auto_temperature': ApiActionCategory.circadian,
        'toggle_auto_temperature': ApiActionCategory.circadian,
        'set_color_temperature_enabled': ApiActionCategory.circadian,
        'set_smart_circadian': ApiActionCategory.circadian,
        'set_smart_circadian_submodules': ApiActionCategory.circadian,

        // Gaming category
        'set_game_mode': ApiActionCategory.gaming,
        'set_game_mode_brightness': ApiActionCategory.gaming,
        'manage_game_mode_whitelist': ApiActionCategory.gaming,

        // Environment category & aliases
        'set_weather_adjustment': ApiActionCategory.environment,
        'set_weather_temperature_adjustment': ApiActionCategory.environment,
        'set_weather_intensity': ApiActionCategory.environment,
        'set_manual_location': ApiActionCategory.environment,
        'set_weather_provider': ApiActionCategory.environment,
        'trigger_sun_sync': ApiActionCategory.environment,
        'openmeteo': ApiActionCategory.environment,
        'weatherapi': ApiActionCategory.environment,
        'auto': ApiActionCategory.environment,

        // Sleep category
        'push_sleep_status': ApiActionCategory.sleep,

        // System category
        'clear_failed_webhooks': ApiActionCategory.system,
        'set_map_animations': ApiActionCategory.system,
      };

      test('Verifies mapping for all 34 specified actions and aliases', () {
        expectedMappings.forEach((action, expectedCategory) {
          final mapped = ApiPermissionsConfig.getCategoryForAction(action);
          expect(mapped, equals(expectedCategory), reason: 'Action "$action" must map to ${expectedCategory.name}');
        });
      });

      test('Verifies unrecognized actions map to null', () {
        final invalidActions = [
          'delete_database',
          'grant_admin',
          'exec_cmd',
          '',
          '   ',
          'SET_BRIGHTNESS', // Case sensitivity check
        ];

        for (final invalidAction in invalidActions) {
          expect(ApiPermissionsConfig.getCategoryForAction(invalidAction), isNull);
        }
      });
    });

    // ------------------------------------------------------------------------
    // SECTION 3: 2^5 = 32 Combinatorial Grid Verification
    // ------------------------------------------------------------------------
    group('32-Combination Combinatorial Read Flag Grid Test', () {
      test('Evaluates all 32 boolean permutations of 5 read flags for filterAutomation', () {
        final sampleData = <String, dynamic>{
          'weather_brightness_adjustment': 10.0,
          'smart_circadian': {'sleep_pressure': 0.5},
          'circadian_offset': 100,
          'auto_brightness': true,
          'auto_temperature': true,
          'color_temperature_hardware_enabled': true,
          'game_mode': true,
          'multi_monitor_offset': 5.0,
          'map_animations': true,
        };

        for (int i = 0; i < 32; i++) {
          final allowMonitors = (i & 1) != 0;
          final allowSolar = (i & 2) != 0;
          final allowWeather = (i & 4) != 0;
          final allowSleep = (i & 8) != 0;
          final allowCircadian = (i & 16) != 0;

          final config = ApiPermissionsConfig(
            allowReadMonitors: allowMonitors,
            allowReadSolar: allowSolar,
            allowReadWeather: allowWeather,
            allowReadSleep: allowSleep,
            allowReadCircadian: allowCircadian,
          );

          final filtered = ApiPermissionsFilter.filterAutomation(sampleData, config);

          // Assertions
          if (!allowWeather) {
            expect(filtered.keys.any((k) => k.startsWith('weather_')), isFalse,
                reason: 'Iteration $i: Weather keys must be stripped');
          }

          if (!allowCircadian) {
            expect(filtered.containsKey('smart_circadian'), isFalse,
                reason: 'Iteration $i: smart_circadian must be stripped');
            expect(filtered.keys.any((k) => k.startsWith('circadian_')), isFalse,
                reason: 'Iteration $i: circadian_ keys must be stripped');
          }

          if (!allowCircadian && !allowMonitors) {
            expect(filtered.containsKey('auto_brightness'), isFalse);
            expect(filtered.containsKey('auto_temperature'), isFalse);
            expect(filtered.containsKey('color_temperature_hardware_enabled'), isFalse);
          }

          if (!allowMonitors) {
            expect(filtered.containsKey('game_mode'), isFalse);
            expect(filtered.containsKey('multi_monitor_offset'), isFalse);
          }
        }
      });
    });

    // ------------------------------------------------------------------------
    // SECTION 4: Property-Based Testing (PBT) Invariants
    // ------------------------------------------------------------------------
    group('Property-Based Testing (PBT) Invariants', () {
      final random = Random(42);

      test('PBT Invariant 1: No weather keys survive when allowReadWeather is false', () {
        for (int run = 0; run < 100; run++) {
          final allowWeather = false;
          final config = ApiPermissionsConfig(
            allowReadWeather: allowWeather,
            allowReadMonitors: random.nextBool(),
            allowReadSolar: random.nextBool(),
            allowReadSleep: random.nextBool(),
            allowReadCircadian: random.nextBool(),
          );

          final randomMap = <String, dynamic>{
            'weather_temp_${random.nextInt(100)}': random.nextDouble(),
            'weather_brightness_${random.nextInt(100)}': random.nextInt(100),
            'other_key_${random.nextInt(100)}': 'val',
          };

          final filtered = ApiPermissionsFilter.filterAutomation(randomMap, config);
          final hasWeatherKeys = filtered.keys.any((k) => k.startsWith('weather_'));
          expect(hasWeatherKeys, isFalse, reason: 'Run $run: Invariant violated!');
        }
      });

      test('PBT Invariant 2: No sleep metrics survive in smart_circadian when allowReadSleep is false', () {
        for (int run = 0; run < 100; run++) {
          final config = ApiPermissionsConfig(
            allowReadCircadian: true,
            allowReadSleep: false,
            allowReadMonitors: random.nextBool(),
          );

          final randomCircadian = <String, dynamic>{
            'phase': 'day_${random.nextInt(10)}',
            'sleep_pressure': random.nextDouble(),
            'sleep_debt': random.nextInt(100),
            'submodules': {
              'sleep_pressure_master': random.nextBool(),
              'sleep_debt_master': random.nextBool(),
              'random_submodule': random.nextInt(50),
            },
          };

          final filtered = ApiPermissionsFilter.filterSmartCircadian(randomCircadian, config);
          expect(filtered, isNotNull);
          expect(filtered!.containsKey('sleep_pressure'), isFalse);
          expect(filtered.containsKey('sleep_debt'), isFalse);

          if (filtered['submodules'] is Map<String, dynamic>) {
            final subs = filtered['submodules'] as Map<String, dynamic>;
            expect(subs.containsKey('sleep_pressure_master'), isFalse);
            expect(subs.containsKey('sleep_debt_master'), isFalse);
          }
        }
      });

      test('PBT Invariant 3: Serialization/Deserialization Roundtrip Identical Equality', () {
        for (int run = 0; run < 100; run++) {
          final categories = ApiActionCategory.values
              .where((_) => random.nextBool())
              .toSet();

          final config = ApiPermissionsConfig(
            allowReadMonitors: random.nextBool(),
            allowReadSolar: random.nextBool(),
            allowReadWeather: random.nextBool(),
            allowReadSleep: random.nextBool(),
            allowReadCircadian: random.nextBool(),
            isReadOnly: random.nextBool(),
            allowedCategories: categories,
          );

          final json = config.toJson();
          final restored = ApiPermissionsConfig.fromJson(json);

          expect(restored, equals(config));
          expect(restored.hashCode, equals(config.hashCode));
        }
      });
    });

    // ------------------------------------------------------------------------
    // SECTION 5: Mutation & Edge-Case Robustness Audit
    // ------------------------------------------------------------------------
    group('Edge-Case & Robustness Audit', () {
      test('Handles empty maps gracefully without exceptions', () {
        const config = ApiPermissionsConfig(
          allowReadMonitors: false,
          allowReadWeather: false,
          allowReadCircadian: false,
        );

        final filteredAutomation = ApiPermissionsFilter.filterAutomation({}, config);
        expect(filteredAutomation, isEmpty);

        final filteredPresets = ApiPermissionsFilter.filterPresets({}, config);
        expect(filteredPresets, isNull);
      });

      test('Handles malformed submodules type in smart_circadian without crashing', () {
        const config = ApiPermissionsConfig(
          allowReadCircadian: true,
          allowReadSleep: false,
        );

        final malformedCircadian = <String, dynamic>{
          'phase': 'night',
          'sleep_pressure': 0.9,
          'submodules': 'invalid_string_instead_of_map', // Edge case malformed JSON
        };

        final filtered = ApiPermissionsFilter.filterSmartCircadian(malformedCircadian, config);
        expect(filtered, isNotNull);
        expect(filtered!.containsKey('sleep_pressure'), isFalse);
        expect(filtered['submodules'], equals('invalid_string_instead_of_map'));
      });

      test('ApiPermissionsChecker handles null category safely', () {
        const config = ApiPermissionsConfig();
        final result = ApiPermissionsChecker.checkCategory(config, null);

        expect(result.isAllowed, isFalse);
        expect(result.title, equals('Unknown Action Category'));
      });

      test('ApiPermissionsCategory.fromJson handles unknown string gracefully by defaulting to system', () {
        final category = ApiActionCategory.fromJson('non_existent_category_name');
        expect(category, equals(ApiActionCategory.system));
      });
    });
  });
}
