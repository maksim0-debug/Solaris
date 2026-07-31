import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';

void main() {
  group('ApiPermissionsConfig & Action Mapping Tests', () {
    test('Default constructor provides full access', () {
      const config = ApiPermissionsConfig();
      expect(config.allowReadMonitors, isTrue);
      expect(config.allowReadSolar, isTrue);
      expect(config.allowReadWeather, isTrue);
      expect(config.allowReadSleep, isTrue);
      expect(config.allowReadCircadian, isTrue);
      expect(config.isReadOnly, isFalse);
      expect(config.allowedCategories.length, equals(7));
      expect(config.activeReadCategoriesCount, equals(5));
    });

    test(
      'activeReadCategoriesCount returns correct count when some read flags are disabled',
      () {
        const config = ApiPermissionsConfig(
          allowReadMonitors: true,
          allowReadSolar: true,
          allowReadWeather: false,
          allowReadSleep: false,
          allowReadCircadian: false,
        );
        expect(config.activeReadCategoriesCount, equals(2));
      },
    );

    test('Action to Category mapping correctness', () {
      expect(
        ApiPermissionsConfig.getCategoryForAction('set_brightness'),
        equals(ApiActionCategory.monitors),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('set_temperature'),
        equals(ApiActionCategory.monitors),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('set_monitor_offset'),
        equals(ApiActionCategory.monitors),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('set_brightness_preset'),
        equals(ApiActionCategory.presets),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('brightest'),
        equals(ApiActionCategory.presets),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('warm'),
        equals(ApiActionCategory.presets),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('set_auto_brightness'),
        equals(ApiActionCategory.circadian),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('set_smart_circadian'),
        equals(ApiActionCategory.circadian),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('set_game_mode'),
        equals(ApiActionCategory.gaming),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('set_weather_adjustment'),
        equals(ApiActionCategory.environment),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('openmeteo'),
        equals(ApiActionCategory.environment),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('push_sleep_status'),
        equals(ApiActionCategory.sleep),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('clear_failed_webhooks'),
        equals(ApiActionCategory.system),
      );
      expect(
        ApiPermissionsConfig.getCategoryForAction('set_map_animations'),
        equals(ApiActionCategory.system),
      );

      expect(
        ApiPermissionsConfig.getCategoryForAction('unknown_invalid_action'),
        isNull,
      );
    });

    test('isActionAllowed returns false when isReadOnly is true', () {
      const config = ApiPermissionsConfig(isReadOnly: true);
      expect(config.isActionAllowed('set_brightness'), isFalse);
      expect(config.isActionAllowed('push_sleep_status'), isFalse);
    });

    test('isActionAllowed respects allowedCategories', () {
      const config = ApiPermissionsConfig(
        isReadOnly: false,
        allowedCategories: {ApiActionCategory.monitors},
      );
      expect(config.isActionAllowed('set_brightness'), isTrue);
      expect(config.isActionAllowed('set_game_mode'), isFalse);
    });

    test('JSON Serialization / Deserialization works correctly', () {
      const config = ApiPermissionsConfig(
        allowReadWeather: false,
        isReadOnly: true,
        allowedCategories: {
          ApiActionCategory.monitors,
          ApiActionCategory.system,
        },
      );

      final json = config.toJson();
      final restored = ApiPermissionsConfig.fromJson(json);

      expect(restored, equals(config));
      expect(restored.allowReadWeather, isFalse);
      expect(restored.isReadOnly, isTrue);
      expect(restored.allowedCategories, contains(ApiActionCategory.monitors));
      expect(restored.allowedCategories, contains(ApiActionCategory.system));
      expect(
        restored.allowedCategories,
        equals({ApiActionCategory.monitors, ApiActionCategory.system}),
      );
    });
  });

  group('SettingsState Integration Tests', () {
    test(
      'SettingsState.fromJson initializes default ApiPermissionsConfig when key is missing',
      () {
        final json = <String, dynamic>{'localIpcServerPort': 45321};

        final state = SettingsState.fromJson(json);
        expect(state.apiPermissions, equals(const ApiPermissionsConfig()));
        expect(state.apiPermissions.isReadOnly, isFalse);
        expect(state.apiPermissions.allowReadWeather, isTrue);
      },
    );

    test('SettingsState.fromJson restores apiPermissions from json', () {
      final json = <String, dynamic>{
        'apiPermissions': {
          'allowReadWeather': false,
          'isReadOnly': true,
          'allowedCategories': ['monitors'],
        },
      };

      final state = SettingsState.fromJson(json);
      expect(state.apiPermissions.allowReadWeather, isFalse);
      expect(state.apiPermissions.isReadOnly, isTrue);
      expect(
        state.apiPermissions.allowedCategories,
        equals({ApiActionCategory.monitors}),
      );
    });

    test('SettingsState.copyWith updates apiPermissions properly', () {
      final state = SettingsState();
      final updated = state.copyWith(
        apiPermissions: state.apiPermissions.copyWith(isReadOnly: true),
      );

      expect(updated.apiPermissions.isReadOnly, isTrue);
      expect(state.apiPermissions.isReadOnly, isFalse);
    });
  });
}
