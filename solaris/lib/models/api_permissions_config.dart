import 'package:flutter/foundation.dart';

enum ApiActionCategory {
  monitors,    // set_brightness, set_temperature, set_monitor_offset
  presets,     // set_brightness_preset, set_temperature_preset, set_user_preset, cycle_preset
  circadian,   // set_auto_brightness, set_auto_temperature, set_smart_circadian, set_smart_circadian_submodules
  gaming,      // set_game_mode, set_game_mode_brightness, manage_game_mode_whitelist
  environment, // set_weather_adjustment, set_weather_temperature_adjustment, set_weather_intensity, set_manual_location, set_weather_provider, trigger_sun_sync
  sleep,       // push_sleep_status
  system;      // clear_failed_webhooks, set_map_animations

  String toJson() => name;
  factory ApiActionCategory.fromJson(String json) => ApiActionCategory.values.firstWhere(
        (e) => e.name == json,
        orElse: () => ApiActionCategory.system,
      );
}

class ApiPermissionsConfig {
  final bool allowReadMonitors;
  final bool allowReadSolar;
  final bool allowReadWeather;
  final bool allowReadSleep;
  final bool allowReadCircadian;

  final bool isReadOnly;
  final Set<ApiActionCategory> allowedCategories;

  const ApiPermissionsConfig({
    this.allowReadMonitors = true,
    this.allowReadSolar = true,
    this.allowReadWeather = true,
    this.allowReadSleep = true,
    this.allowReadCircadian = true,
    this.isReadOnly = false,
    this.allowedCategories = const {
      ApiActionCategory.monitors,
      ApiActionCategory.presets,
      ApiActionCategory.circadian,
      ApiActionCategory.gaming,
      ApiActionCategory.environment,
      ApiActionCategory.sleep,
      ApiActionCategory.system,
    },
  });

  /// Full mapping of action string (including aliases and shorthand actions) to ApiActionCategory
  static ApiActionCategory? getCategoryForAction(String action) {
    switch (action) {
      case 'set_brightness':
      case 'set_temperature':
      case 'set_monitor_offset':
        return ApiActionCategory.monitors;

      case 'set_brightness_preset':
      case 'set_temperature_preset':
      case 'set_user_preset':
      case 'cycle_preset':
      case 'brightest':
      case 'bright':
      case 'dim':
      case 'dimmest':
      case 'coolest':
      case 'cool':
      case 'warm':
      case 'warmest':
        return ApiActionCategory.presets;

      case 'set_auto_brightness':
      case 'toggle_auto_brightness':
      case 'set_auto_temperature':
      case 'toggle_auto_temperature':
      case 'set_color_temperature_enabled':
      case 'set_smart_circadian':
      case 'set_smart_circadian_submodules':
        return ApiActionCategory.circadian;

      case 'set_game_mode':
      case 'set_game_mode_brightness':
      case 'manage_game_mode_whitelist':
        return ApiActionCategory.gaming;

      case 'set_weather_adjustment':
      case 'set_weather_temperature_adjustment':
      case 'set_weather_intensity':
      case 'set_manual_location':
      case 'set_weather_provider':
      case 'trigger_sun_sync':
      case 'openmeteo':
      case 'weatherapi':
      case 'auto':
        return ApiActionCategory.environment;

      case 'push_sleep_status':
        return ApiActionCategory.sleep;

      case 'clear_failed_webhooks':
      case 'set_map_animations':
        return ApiActionCategory.system;

      default:
        return null;
    }
  }

  bool isActionAllowed(String action) {
    if (isReadOnly) return false;
    final category = getCategoryForAction(action);
    if (category == null) return false;
    return allowedCategories.contains(category);
  }

  Map<String, dynamic> toJson() => {
        'allowReadMonitors': allowReadMonitors,
        'allowReadSolar': allowReadSolar,
        'allowReadWeather': allowReadWeather,
        'allowReadSleep': allowReadSleep,
        'allowReadCircadian': allowReadCircadian,
        'isReadOnly': isReadOnly,
        'allowedCategories': allowedCategories.map((c) => c.toJson()).toList(),
      };

  factory ApiPermissionsConfig.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['allowedCategories'] as List<dynamic>?;
    Set<ApiActionCategory> categories;
    if (rawCategories != null) {
      categories = rawCategories
          .map((e) => ApiActionCategory.fromJson(e.toString()))
          .toSet();
    } else {
      categories = ApiActionCategory.values.toSet();
    }

    return ApiPermissionsConfig(
      allowReadMonitors: json['allowReadMonitors'] as bool? ?? true,
      allowReadSolar: json['allowReadSolar'] as bool? ?? true,
      allowReadWeather: json['allowReadWeather'] as bool? ?? true,
      allowReadSleep: json['allowReadSleep'] as bool? ?? true,
      allowReadCircadian: json['allowReadCircadian'] as bool? ?? true,
      isReadOnly: json['isReadOnly'] as bool? ?? false,
      allowedCategories: categories,
    );
  }

  ApiPermissionsConfig copyWith({
    bool? allowReadMonitors,
    bool? allowReadSolar,
    bool? allowReadWeather,
    bool? allowReadSleep,
    bool? allowReadCircadian,
    bool? isReadOnly,
    Set<ApiActionCategory>? allowedCategories,
  }) {
    return ApiPermissionsConfig(
      allowReadMonitors: allowReadMonitors ?? this.allowReadMonitors,
      allowReadSolar: allowReadSolar ?? this.allowReadSolar,
      allowReadWeather: allowReadWeather ?? this.allowReadWeather,
      allowReadSleep: allowReadSleep ?? this.allowReadSleep,
      allowReadCircadian: allowReadCircadian ?? this.allowReadCircadian,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      allowedCategories: allowedCategories ?? this.allowedCategories,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiPermissionsConfig &&
        other.allowReadMonitors == allowReadMonitors &&
        other.allowReadSolar == allowReadSolar &&
        other.allowReadWeather == allowReadWeather &&
        other.allowReadSleep == allowReadSleep &&
        other.allowReadCircadian == allowReadCircadian &&
        other.isReadOnly == isReadOnly &&
        setEquals(other.allowedCategories, allowedCategories);
  }

  @override
  int get hashCode => Object.hash(
        allowReadMonitors,
        allowReadSolar,
        allowReadWeather,
        allowReadSleep,
        allowReadCircadian,
        isReadOnly,
        Object.hashAll(allowedCategories),
      );
}
