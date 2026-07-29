import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/services/api_permissions_filter.dart';

void main() {
  group('ApiPermissionsFilter Unit Tests', () {
    final sampleAutomation = <String, dynamic>{
      'weather_brightness_adjustment': 10.0,
      'weather_temperature_adjustment': 200,
      'weather_adjustment_intensity': 0.5,
      'smart_circadian': {
        'phase': 'day',
        'sleep_pressure': 0.8,
        'sleep_debt': 15,
        'submodules': {
          'sleep_pressure_master': true,
          'sleep_debt_master': false,
          'other_setting': 100,
        },
      },
      'circadian_target_brightness': 80,
      'auto_brightness': true,
      'auto_temperature': true,
      'color_temperature_hardware_enabled': true,
      'game_mode': true,
      'multi_monitor_offset': 5.0,
      'map_animations': true,
    };

    test(
      'filterAutomation strips weather keys when allowReadWeather is false',
      () {
        const config = ApiPermissionsConfig(allowReadWeather: false);
        final filtered = ApiPermissionsFilter.filterAutomation(
          sampleAutomation,
          config,
        );

        expect(filtered.containsKey('weather_brightness_adjustment'), isFalse);
        expect(filtered.containsKey('weather_temperature_adjustment'), isFalse);
        expect(filtered.containsKey('weather_adjustment_intensity'), isFalse);
        expect(filtered.containsKey('auto_brightness'), isTrue);
      },
    );

    test(
      'filterAutomation strips circadian keys when allowReadCircadian is false',
      () {
        const config = ApiPermissionsConfig(allowReadCircadian: false);
        final filtered = ApiPermissionsFilter.filterAutomation(
          sampleAutomation,
          config,
        );

        expect(filtered.containsKey('smart_circadian'), isFalse);
        expect(filtered.containsKey('circadian_target_brightness'), isFalse);
      },
    );

    test(
      'filterAutomation strips game_mode and offsets when allowReadMonitors is false',
      () {
        const config = ApiPermissionsConfig(allowReadMonitors: false);
        final filtered = ApiPermissionsFilter.filterAutomation(
          sampleAutomation,
          config,
        );

        expect(filtered.containsKey('game_mode'), isFalse);
        expect(filtered.containsKey('multi_monitor_offset'), isFalse);
      },
    );

    test(
      'filterAutomation strips map_animations when system category is disabled',
      () {
        const config = ApiPermissionsConfig(
          allowedCategories: {
            ApiActionCategory.monitors,
            ApiActionCategory.presets,
          },
        );
        final filtered = ApiPermissionsFilter.filterAutomation(
          sampleAutomation,
          config,
        );

        expect(filtered.containsKey('map_animations'), isFalse);
      },
    );

    test(
      'filterSmartCircadian removes sleep metrics when allowReadSleep is false',
      () {
        const config = ApiPermissionsConfig(
          allowReadCircadian: true,
          allowReadSleep: false,
        );
        final rawCircadian =
            sampleAutomation['smart_circadian'] as Map<String, dynamic>;
        final filtered = ApiPermissionsFilter.filterSmartCircadian(
          rawCircadian,
          config,
        );

        expect(filtered, isNotNull);
        expect(filtered!.containsKey('sleep_pressure'), isFalse);
        expect(filtered.containsKey('sleep_debt'), isFalse);
        expect(filtered.containsKey('phase'), isTrue);

        final submodules = filtered['submodules'] as Map<String, dynamic>;
        expect(submodules.containsKey('sleep_pressure_master'), isFalse);
        expect(submodules.containsKey('sleep_debt_master'), isFalse);
        expect(submodules.containsKey('other_setting'), isTrue);
      },
    );

    test(
      'filterSmartCircadian returns null when allowReadCircadian is false',
      () {
        const config = ApiPermissionsConfig(allowReadCircadian: false);
        final rawCircadian =
            sampleAutomation['smart_circadian'] as Map<String, dynamic>;
        final filtered = ApiPermissionsFilter.filterSmartCircadian(
          rawCircadian,
          config,
        );

        expect(filtered, isNull);
      },
    );

    test(
      'filterPresets masks brightness/temperature based on monitor and circadian read flags',
      () {
        final samplePresets = <String, dynamic>{
          'brightness': {'preset1': 100},
          'temperature': {'preset1': 6500},
        };

        const noMonitorsConfig = ApiPermissionsConfig(allowReadMonitors: false);
        final res1 = ApiPermissionsFilter.filterPresets(
          samplePresets,
          noMonitorsConfig,
        );
        expect(res1, isNotNull);
        expect(res1!.containsKey('brightness'), isFalse);
        expect(res1.containsKey('temperature'), isTrue);

        const noCircadianConfig = ApiPermissionsConfig(
          allowReadCircadian: false,
        );
        final res2 = ApiPermissionsFilter.filterPresets(
          samplePresets,
          noCircadianConfig,
        );
        expect(res2, isNotNull);
        expect(res2!.containsKey('brightness'), isTrue);
        expect(res2.containsKey('temperature'), isFalse);

        const noneConfig = ApiPermissionsConfig(
          allowReadMonitors: false,
          allowReadCircadian: false,
        );
        final res3 = ApiPermissionsFilter.filterPresets(
          samplePresets,
          noneConfig,
        );
        expect(res3, isNull);
      },
    );
  });
}
