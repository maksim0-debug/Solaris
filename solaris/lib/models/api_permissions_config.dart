import 'package:flutter/foundation.dart';

enum ApiActionCategory {
  monitors, // set_brightness, set_temperature, set_monitor_offset
  presets, // set_brightness_preset, set_temperature_preset, set_user_preset, cycle_preset
  circadian, // set_auto_brightness, set_auto_temperature, set_smart_circadian, set_smart_circadian_submodules
  gaming, // set_game_mode, set_game_mode_brightness, manage_game_mode_whitelist
  environment, // set_weather_adjustment, set_weather_temperature_adjustment, set_weather_intensity, set_manual_location, set_weather_provider, trigger_sun_sync
  sleep, // push_sleep_status
  system; // manage_webhooks, set_map_animations, on_system_resume, on_hardware_error

  String toJson() => name;
  factory ApiActionCategory.fromJson(String json) =>
      ApiActionCategory.values.firstWhere(
        (e) => e.name == json,
        orElse: () => ApiActionCategory.system,
      );
}

class _Sentinel {
  const _Sentinel();
}

class ApiPermissionsConfig {
  final bool allowReadMonitors;
  final bool allowReadSolar;
  final bool allowReadWeather;
  final bool allowReadSleep;
  final bool allowReadCircadian;

  final bool isReadOnly;
  final Set<ApiActionCategory> allowedCategories;
  final Set<String>?
  allowedActions; // null = all actions in category allowed (100% backward compatible)

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
    this.allowedActions,
  });

  /// Total available read categories (5 in total: Monitors, Solar, Weather, Sleep, Circadian)
  static const int totalReadCategories = 5;

  /// Returns the number of enabled read categories (out of 5)
  int get activeReadCategoriesCount {
    var count = 0;
    if (allowReadMonitors) count++;
    if (allowReadSolar) count++;
    if (allowReadWeather) count++;
    if (allowReadSleep) count++;
    if (allowReadCircadian) count++;
    return count;
  }

  /// Normalizes incoming action or alias into a canonical action key
  static String getCanonicalAction(String action) {
    switch (action) {
      case 'set_monitor_brightness':
        return 'set_brightness';

      case 'set_monitor_temperature':
        return 'set_temperature';

      case 'brightest':
      case 'bright':
      case 'dim':
      case 'dimmest':
        return 'set_brightness_preset';

      case 'coolest':
      case 'cool':
      case 'warm':
      case 'warmest':
        return 'set_temperature_preset';

      case 'toggle_auto_brightness':
        return 'set_auto_brightness';

      case 'toggle_auto_temperature':
      case 'set_color_temperature_enabled':
        return 'set_auto_temperature';

      case 'openmeteo':
      case 'weatherapi':
      case 'auto':
        return 'set_weather_provider';

      case 'clear_failed_webhooks':
        return 'manage_webhooks';

      default:
        return action;
    }
  }

  /// Gets all canonical actions for a specific category (28 canonical actions in total)
  static List<String> getActionsForCategory(ApiActionCategory category) {
    switch (category) {
      case ApiActionCategory.monitors:
        return const [
          'set_brightness',
          'set_temperature',
          'set_monitor_offset',
        ];
      case ApiActionCategory.presets:
        return const [
          'set_brightness_preset',
          'set_temperature_preset',
          'set_user_preset',
          'cycle_preset',
          'get_app_overrides',
          'manage_app_overrides',
          'reset_builtin_app_overrides',
        ];
      case ApiActionCategory.circadian:
        return const [
          'set_auto_brightness',
          'set_auto_temperature',
          'set_smart_circadian',
          'set_smart_circadian_submodules',
        ];
      case ApiActionCategory.gaming:
        return const [
          'set_game_mode',
          'set_game_mode_brightness',
          'manage_game_mode_whitelist',
        ];
      case ApiActionCategory.environment:
        return const [
          'set_weather_adjustment',
          'set_weather_temperature_adjustment',
          'set_weather_intensity',
          'set_manual_location',
          'set_weather_provider',
          'trigger_sun_sync',
        ];
      case ApiActionCategory.sleep:
        return const ['push_sleep_status'];
      case ApiActionCategory.system:
        return const [
          'manage_webhooks',
          'set_map_animations',
          'on_system_resume',
          'on_hardware_error',
        ];
    }
  }

  /// Returns all 28 canonical actions across all categories
  static Set<String> getAllCanonicalActions() {
    return ApiActionCategory.values
        .expand((c) => getActionsForCategory(c))
        .toSet();
  }

  /// Full mapping of action string (including aliases and shorthand actions) to ApiActionCategory
  static ApiActionCategory? getCategoryForAction(String action) {
    final canonical = getCanonicalAction(action);
    switch (canonical) {
      case 'set_brightness':
      case 'set_temperature':
      case 'set_monitor_offset':
        return ApiActionCategory.monitors;

      case 'set_brightness_preset':
      case 'set_temperature_preset':
      case 'set_user_preset':
      case 'cycle_preset':
      case 'get_app_overrides':
      case 'manage_app_overrides':
      case 'reset_builtin_app_overrides':
        return ApiActionCategory.presets;

      case 'set_auto_brightness':
      case 'set_auto_temperature':
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
        return ApiActionCategory.environment;

      case 'push_sleep_status':
        return ApiActionCategory.sleep;

      case 'manage_webhooks':
      case 'set_map_animations':
      case 'on_system_resume':
      case 'on_hardware_error':
        return ApiActionCategory.system;

      default:
        return null;
    }
  }

  bool isActionAllowed(String action) {
    if (isReadOnly) return false;
    final category = getCategoryForAction(action);
    if (category == null) return false;
    if (!allowedCategories.contains(category)) return false;

    if (allowedActions == null) return true; // Full category access

    final canonical = getCanonicalAction(action);
    return allowedActions!.contains(canonical);
  }

  Map<String, dynamic> toJson() {
    final validCanonical = allowedCategories
        .expand((cat) => getActionsForCategory(cat))
        .toSet();
    // Sanitize: filter out any non-canonical or orphaned actions from disabled categories and auto-reset to null if all actions present
    final Set<String>? filteredActions = allowedActions?.intersection(
      validCanonical,
    );
    final Set<String>? sanitizedActions =
        (filteredActions != null &&
            filteredActions.length < getAllCanonicalActions().length)
        ? filteredActions
        : null;

    return {
      'allowReadMonitors': allowReadMonitors,
      'allowReadSolar': allowReadSolar,
      'allowReadWeather': allowReadWeather,
      'allowReadSleep': allowReadSleep,
      'allowReadCircadian': allowReadCircadian,
      'isReadOnly': isReadOnly,
      'allowedCategories': allowedCategories.map((c) => c.toJson()).toList(),
      if (sanitizedActions != null) 'allowedActions': sanitizedActions.toList(),
    };
  }

  factory ApiPermissionsConfig.fromJson(Map<String, dynamic> json) {
    // Type-safe deserialization prevents TypeError crashes if JSON contains corrupted non-List types
    final rawCategories = json['allowedCategories'];
    Set<ApiActionCategory> categories;
    if (rawCategories is List) {
      categories = rawCategories
          .map((e) => ApiActionCategory.fromJson(e.toString()))
          .toSet();
    } else {
      categories = ApiActionCategory.values.toSet();
    }

    final rawActions = json['allowedActions'];
    Set<String>? allowedActions;
    if (rawActions is List) {
      final validCanonical = getAllCanonicalActions();
      final parsed = rawActions
          .map((e) => getCanonicalAction(e.toString()))
          .where((e) => validCanonical.contains(e))
          .toSet();
      // Automatic reset to null if all canonical actions are enabled for clean storage
      allowedActions = (parsed.length >= validCanonical.length) ? null : parsed;
    } else {
      allowedActions = null;
    }

    return ApiPermissionsConfig(
      allowReadMonitors: json['allowReadMonitors'] as bool? ?? true,
      allowReadSolar: json['allowReadSolar'] as bool? ?? true,
      allowReadWeather: json['allowReadWeather'] as bool? ?? true,
      allowReadSleep: json['allowReadSleep'] as bool? ?? true,
      allowReadCircadian: json['allowReadCircadian'] as bool? ?? true,
      isReadOnly: json['isReadOnly'] as bool? ?? false,
      allowedCategories: categories,
      allowedActions: allowedActions,
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
    Object? allowedActions = _sentinel,
  }) {
    return ApiPermissionsConfig(
      allowReadMonitors: allowReadMonitors ?? this.allowReadMonitors,
      allowReadSolar: allowReadSolar ?? this.allowReadSolar,
      allowReadWeather: allowReadWeather ?? this.allowReadWeather,
      allowReadSleep: allowReadSleep ?? this.allowReadSleep,
      allowReadCircadian: allowReadCircadian ?? this.allowReadCircadian,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      allowedCategories: allowedCategories ?? this.allowedCategories,
      allowedActions: identical(allowedActions, _sentinel)
          ? this.allowedActions
          : allowedActions as Set<String>?,
    );
  }

  static const _sentinel = _Sentinel();

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
        setEquals(other.allowedCategories, allowedCategories) &&
        ((other.allowedActions == null && allowedActions == null) ||
            (other.allowedActions != null &&
                allowedActions != null &&
                setEquals(other.allowedActions, allowedActions)));
  }

  @override
  int get hashCode => Object.hash(
    allowReadMonitors,
    allowReadSolar,
    allowReadWeather,
    allowReadSleep,
    allowReadCircadian,
    isReadOnly,
    Object.hashAll(allowedCategories.map((c) => c.index).toList()..sort()),
    allowedActions != null
        ? Object.hashAll(allowedActions!.toList()..sort())
        : null,
  );
}
