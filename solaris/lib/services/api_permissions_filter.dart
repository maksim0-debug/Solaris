import 'package:solaris/models/api_permissions_config.dart';

class ApiPermissionsFilter {
  /// Masking the automation node according to data read flags and categories
  static Map<String, dynamic> filterAutomation(
    Map<String, dynamic> raw,
    ApiPermissionsConfig permissions,
  ) {
    final copy = Map<String, dynamic>.from(raw);

    // Weather automation keys
    if (!permissions.allowReadWeather) {
      copy.removeWhere((k, _) => k.startsWith('weather_'));
    }

    // Circadian automation keys
    if (!permissions.allowReadCircadian) {
      copy.remove('smart_circadian');
      copy.removeWhere(
        (k, _) =>
            k.startsWith('circadian_') || k.startsWith('smart_circadian_'),
      );
    } else {
      // If allowReadCircadian is true, check sub-node smart_circadian for sleep metrics
      if (copy.containsKey('smart_circadian') &&
          copy['smart_circadian'] is Map<String, dynamic>) {
        final scFiltered = filterSmartCircadian(
          copy['smart_circadian'] as Map<String, dynamic>,
          permissions,
        );
        if (scFiltered != null) {
          copy['smart_circadian'] = scFiltered;
        } else {
          copy.remove('smart_circadian');
        }
      }
    }

    // Linked circadian and monitor flags
    if (!permissions.allowReadCircadian && !permissions.allowReadMonitors) {
      copy.remove('auto_brightness');
      copy.remove('auto_temperature');
      copy.remove('color_temperature_hardware_enabled');
    }

    // Game mode and monitor offsets
    if (!permissions.allowReadMonitors) {
      copy.remove('game_mode');
      copy.remove('multi_monitor_offset');
    }

    // System map animations
    if (!permissions.allowedCategories.contains(ApiActionCategory.system)) {
      copy.remove('map_animations');
    }

    return copy;
  }

  /// Masking the smart_circadian node (removes sleep_pressure and sleep_debt if allowReadSleep is false)
  static Map<String, dynamic>? filterSmartCircadian(
    Map<String, dynamic> raw,
    ApiPermissionsConfig permissions,
  ) {
    if (!permissions.allowReadCircadian) return null;
    final copy = Map<String, dynamic>.from(raw);

    if (!permissions.allowReadSleep) {
      copy.remove('sleep_pressure');
      copy.remove('sleep_debt');
      if (copy.containsKey('submodules') &&
          copy['submodules'] is Map<String, dynamic>) {
        final submodules = copy['submodules'] as Map<String, dynamic>;
        final subCopy = Map<String, dynamic>.from(submodules);
        subCopy.remove('sleep_pressure_master');
        subCopy.remove('sleep_debt_master');
        copy['submodules'] = subCopy;
      }
    }
    return copy;
  }

  /// Masking the presets node
  static Map<String, dynamic>? filterPresets(
    Map<String, dynamic> raw,
    ApiPermissionsConfig permissions,
  ) {
    final copy = Map<String, dynamic>.from(raw);
    if (!permissions.allowReadMonitors) {
      copy.remove('brightness');
    }
    if (!permissions.allowReadCircadian) {
      copy.remove('temperature');
    }
    if (copy.isEmpty) return null;
    return copy;
  }
}
