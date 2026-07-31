import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';

void main() {
  group('Stage 1: ApiPermissionsConfig Per-Action Precision & Canonicalization', () {
    test(
      'getAllCanonicalActions returns exactly 28 unique canonical actions',
      () {
        final canonicalActions = ApiPermissionsConfig.getAllCanonicalActions();
        expect(canonicalActions.length, equals(28));
      },
    );

    test('getActionsForCategory correctly maps all 7 categories', () {
      final monitors = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.monitors,
      );
      expect(
        monitors,
        equals(['set_brightness', 'set_temperature', 'set_monitor_offset']),
      );

      final presets = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.presets,
      );
      expect(
        presets,
        equals([
          'set_brightness_preset',
          'set_temperature_preset',
          'set_user_preset',
          'cycle_preset',
          'get_app_overrides',
          'manage_app_overrides',
          'reset_builtin_app_overrides',
        ]),
      );

      final circadian = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.circadian,
      );
      expect(
        circadian,
        equals([
          'set_auto_brightness',
          'set_auto_temperature',
          'set_smart_circadian',
          'set_smart_circadian_submodules',
        ]),
      );

      final gaming = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.gaming,
      );
      expect(
        gaming,
        equals([
          'set_game_mode',
          'set_game_mode_brightness',
          'manage_game_mode_whitelist',
        ]),
      );

      final environment = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.environment,
      );
      expect(
        environment,
        equals([
          'set_weather_adjustment',
          'set_weather_temperature_adjustment',
          'set_weather_intensity',
          'set_manual_location',
          'set_weather_provider',
          'trigger_sun_sync',
        ]),
      );

      final sleep = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.sleep,
      );
      expect(sleep, equals(['push_sleep_status']));

      final system = ApiPermissionsConfig.getActionsForCategory(
        ApiActionCategory.system,
      );
      expect(
        system,
        equals([
          'manage_webhooks',
          'set_map_animations',
          'on_system_resume',
          'on_hardware_error',
        ]),
      );
    });

    test('getCanonicalAction normalizes aliases correctly', () {
      expect(
        ApiPermissionsConfig.getCanonicalAction('set_monitor_brightness'),
        equals('set_brightness'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('set_monitor_temperature'),
        equals('set_temperature'),
      );

      expect(
        ApiPermissionsConfig.getCanonicalAction('brightest'),
        equals('set_brightness_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('bright'),
        equals('set_brightness_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('dim'),
        equals('set_brightness_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('dimmest'),
        equals('set_brightness_preset'),
      );

      expect(
        ApiPermissionsConfig.getCanonicalAction('coolest'),
        equals('set_temperature_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('cool'),
        equals('set_temperature_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('warm'),
        equals('set_temperature_preset'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('warmest'),
        equals('set_temperature_preset'),
      );

      expect(
        ApiPermissionsConfig.getCanonicalAction('toggle_auto_brightness'),
        equals('set_auto_brightness'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('toggle_auto_temperature'),
        equals('set_auto_temperature'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction(
          'set_color_temperature_enabled',
        ),
        equals('set_auto_temperature'),
      );

      expect(
        ApiPermissionsConfig.getCanonicalAction('openmeteo'),
        equals('set_weather_provider'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('weatherapi'),
        equals('set_weather_provider'),
      );
      expect(
        ApiPermissionsConfig.getCanonicalAction('auto'),
        equals('set_weather_provider'),
      );

      expect(
        ApiPermissionsConfig.getCanonicalAction('clear_failed_webhooks'),
        equals('manage_webhooks'),
      );

      // Unknown actions remain untouched
      expect(
        ApiPermissionsConfig.getCanonicalAction('custom_action'),
        equals('custom_action'),
      );
    });

    test(
      'isActionAllowed works with allowedActions == null (full category access)',
      () {
        const config = ApiPermissionsConfig(allowedActions: null);

        expect(config.isActionAllowed('set_brightness'), isTrue);
        expect(config.isActionAllowed('set_temperature'), isTrue);
        expect(config.isActionAllowed('brightest'), isTrue);
        expect(config.isActionAllowed('push_sleep_status'), isTrue);
      },
    );

    test('isActionAllowed respects granular per-action permissions', () {
      final config = ApiPermissionsConfig(
        allowedActions: {'set_brightness', 'set_brightness_preset'},
      );

      // Explicitly allowed canonical action
      expect(config.isActionAllowed('set_brightness'), isTrue);
      // Explicitly allowed alias
      expect(config.isActionAllowed('brightest'), isTrue);

      // Disallowed action in allowed category
      expect(config.isActionAllowed('set_temperature'), isFalse);
      expect(config.isActionAllowed('set_monitor_offset'), isFalse);
      expect(config.isActionAllowed('warmest'), isFalse);
    });

    test('isActionAllowed denies all actions when isReadOnly is true', () {
      final config = ApiPermissionsConfig(
        isReadOnly: true,
        allowedActions: {'set_brightness'},
      );

      expect(config.isActionAllowed('set_brightness'), isFalse);
    });

    test(
      'isActionAllowed denies action if category is disabled, even if action is in allowedActions',
      () {
        final config = ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.presets},
          allowedActions: {'set_brightness', 'set_brightness_preset'},
        );

        // Presets category is allowed
        expect(config.isActionAllowed('set_brightness_preset'), isTrue);

        // Monitors category is disabled, so set_brightness must be denied
        expect(config.isActionAllowed('set_brightness'), isFalse);
      },
    );

    test(
      'toJson auto-resets allowedActions to null if all 28 canonical actions are present',
      () {
        final allActions = ApiPermissionsConfig.getAllCanonicalActions();
        final config = ApiPermissionsConfig(allowedActions: allActions);

        final json = config.toJson();
        expect(json.containsKey('allowedActions'), isFalse);
      },
    );

    test(
      'toJson serializes allowedActions as List when granular selection is used',
      () {
        final config = ApiPermissionsConfig(
          allowedActions: {'set_brightness', 'set_auto_brightness'},
        );

        final json = config.toJson();
        expect(json['allowedActions'], isA<List<dynamic>>());
        final list = (json['allowedActions'] as List<dynamic>).cast<String>();
        expect(list, containsAll(['set_brightness', 'set_auto_brightness']));
        expect(list.length, equals(2));
      },
    );

    test(
      'fromJson auto-resets allowedActions to null if all 28 canonical actions are passed',
      () {
        final allActions = ApiPermissionsConfig.getAllCanonicalActions()
            .toList();
        final json = {'allowedActions': allActions};

        final restored = ApiPermissionsConfig.fromJson(json);
        expect(restored.allowedActions, isNull);
      },
    );

    test('fromJson handles type safety and invalid actions gracefully', () {
      final json = {
        'allowedCategories': 'invalid_non_list_type',
        'allowedActions': [
          'set_brightness',
          'set_monitor_temperature', // Alias for set_temperature
          'invalid_non_canonical_action_xyz',
          12345, // Non-string element
        ],
      };

      final restored = ApiPermissionsConfig.fromJson(json);
      expect(
        restored.allowedCategories,
        equals(ApiActionCategory.values.toSet()),
      );
      expect(restored.allowedActions, isNotNull);
      expect(restored.allowedActions, contains('set_brightness'));
      expect(
        restored.allowedActions,
        contains('set_temperature'),
      ); // Normalized from set_monitor_temperature
      expect(restored.allowedActions!.length, equals(2));
    });

    test(
      'copyWith sentinel logic allows clearing allowedActions back to null',
      () {
        final initial = ApiPermissionsConfig(
          allowedActions: {'set_brightness'},
        );

        // Preserves allowedActions when omitted
        final modified1 = initial.copyWith(allowReadMonitors: false);
        expect(modified1.allowedActions, equals({'set_brightness'}));

        // Explicitly resets allowedActions to null
        final modified2 = initial.copyWith(allowedActions: null);
        expect(modified2.allowedActions, isNull);

        // Updates allowedActions to a new set
        final modified3 = initial.copyWith(allowedActions: {'set_temperature'});
        expect(modified3.allowedActions, equals({'set_temperature'}));
      },
    );

    test('operator == and hashCode handle allowedActions correctly', () {
      final config1 = ApiPermissionsConfig(
        allowedActions: {'set_brightness', 'set_temperature'},
      );
      final config2 = ApiPermissionsConfig(
        allowedActions: {'set_temperature', 'set_brightness'},
      );
      final config3 = ApiPermissionsConfig(allowedActions: {'set_brightness'});
      final config4 = ApiPermissionsConfig(allowedActions: null);

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));

      expect(config1, isNot(equals(config3)));
      expect(config1, isNot(equals(config4)));
    });
  });
}
