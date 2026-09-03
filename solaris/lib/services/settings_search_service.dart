import 'package:string_similarity/string_similarity.dart';
import 'package:solaris/models/setting_item.dart';
import 'package:solaris/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class SettingsSearchService {
  final BuildContext context;

  SettingsSearchService(this.context);

  List<SettingItem> _getDatabase() {
    final l10n = AppLocalizations.of(context)!;

    return [
      // Dashboard
      SettingItem(
        id: 'brightness_control',
        title: l10n.brightness,
        description: l10n.descZenithManual,
        tags: _splitTags(l10n.tags_brightness),
        screen: AppScreen.dashboard,
        anchorId: 'brightness_control',
      ),
      SettingItem(
        id: 'auto_brightness',
        title: l10n.autoBrightness,
        description: l10n.descDeepNightAuto,
        tags: _splitTags(l10n.tags_auto_brightness),
        screen: AppScreen.dashboard,
        anchorId: 'auto_brightness',
      ),
      SettingItem(
        id: 'auto_temperature',
        title: l10n.autoTemperature,
        description: l10n.blueLightFilterSubtitle,
        tags: _splitTags(l10n.tags_auto_temperature),
        screen: AppScreen.dashboard,
        anchorId: 'auto_temperature',
      ),
      SettingItem(
        id: 'color_temperature',
        title: l10n.blueLightFilter,
        description: l10n.blueLightFilterSubtitle,
        tags: _splitTags(l10n.tags_auto_temperature),
        screen: AppScreen.dashboard,
        anchorId: 'color_temperature',
      ),
      SettingItem(
        id: 'multi_monitor_offsets',
        title: l10n.multiMonitorOffsets,
        description: l10n.multiMonitorOffsetsSubtitle,
        tags: _splitTags(l10n.tags_multi_monitor),
        screen: AppScreen.dashboard,
        anchorId: 'multi_monitor_offsets',
      ),

      // Schedule
      SettingItem(
        id: 'schedule_view',
        title: l10n.schedule,
        description: l10n.luminosityProfile,
        tags: _splitTags(l10n.tags_schedule),
        screen: AppScreen.schedule,
        anchorId: 'schedule_view',
      ),

      // Sleep / Smart Circadian
      SettingItem(
        id: 'sleep_data',
        title: l10n.sleep,
        description: l10n.sleepSubtitle,
        tags: _splitTags(l10n.tags_sleep),
        screen: AppScreen.sleep,
        anchorId: 'sleep_regimes',
      ),
      SettingItem(
        id: 'smart_circadian',
        title: l10n.smartCircadianTitle,
        description: l10n.smartCircadianSubtitle,
        tags: _splitTags(l10n.tags_smart_circadian),
        screen: AppScreen.sleep,
        anchorId: 'circadian_regulation',
      ),
      SettingItem(
        id: 'wind_down',
        title: l10n.featureWindDown,
        description: l10n.featureWindDownSubtitle,
        tags: _splitTags(l10n.tags_wind_down),
        screen: AppScreen.sleep,
        anchorId: 'wind_down',
      ),
      SettingItem(
        id: 'sleep_analysis_settings',
        title: l10n.sleepAnalysisSettings,
        description: l10n.toleranceWindowDesc,
        tags: _splitTags(l10n.tags_sleep_analysis),
        screen: AppScreen.sleep,
        anchorId: 'sleep_analysis',
      ),
      SettingItem(
        id: 'google_fit_sync',
        title: l10n.googleFitSync,
        description: l10n.sleepDataSubtitle,
        tags: _splitTags(l10n.tags_google_fit),
        screen: AppScreen.sleep,
        anchorId: 'google_fit',
      ),
      SettingItem(
        id: 'time_shift',
        title: l10n.featureTimeShift,
        description: l10n.featureTimeShiftSubtitle,
        tags: _splitTags(l10n.tags_time_shift),
        screen: AppScreen.sleep,
        anchorId: 'time_shift',
      ),
      SettingItem(
        id: 'sleep_pressure',
        title: l10n.featureSleepPressure,
        description: l10n.featureSleepPressureSubtitle,
        tags: _splitTags(l10n.tags_sleep_pressure),
        screen: AppScreen.sleep,
        anchorId: 'sleep_pressure',
      ),
      SettingItem(
        id: 'sleep_debt',
        title: l10n.featureSleepDebt,
        description: l10n.featureSleepDebtSubtitle,
        tags: _splitTags(l10n.tags_sleep_debt),
        screen: AppScreen.sleep,
        anchorId: 'sleep_debt',
      ),
      SettingItem(
        id: 'local_sleep_integration',
        title: l10n.sleepIntegrationTitle,
        description: l10n.sleepIntegrationSubtitle,
        tags: _splitTags(l10n.tags_local_sleep_integration),
        screen: AppScreen.sleep,
        anchorId: 'local_sleep_integration',
      ),

      // Settings
      SettingItem(
        id: 'app_overrides',
        title: l10n.appOverridesTitle,
        description: l10n.appOverridesSubtitle,
        tags: _splitTags(l10n.tags_app_overrides),
        screen: AppScreen.settings,
        anchorId: 'app_overrides',
      ),
      SettingItem(
        id: 'app_override_exit_delay',
        title: l10n.appOverrideExitDelay,
        description: l10n.appOverrideExitDelaySubtitle,
        tags: _splitTags(l10n.tags_app_override_exit_delay),
        screen: AppScreen.appOverrides,
        anchorId: 'app_override_exit_delay',
      ),
      SettingItem(
        id: 'app_override_user_rules',
        title: l10n.userRulesSection,
        description: l10n.appOverridesSubtitle,
        tags: _splitTags(l10n.tags_app_override_rules),
        screen: AppScreen.appOverrides,
        anchorId: 'app_override_user_rules',
      ),
      SettingItem(
        id: 'app_override_builtin_rules',
        title: l10n.builtinRulesSection(6),
        description: l10n.appOverridesSubtitle,
        tags: _splitTags(l10n.tags_app_override_rules),
        screen: AppScreen.appOverrides,
        anchorId: 'app_override_builtin_rules',
      ),
      SettingItem(
        id: 'game_mode',
        title: l10n.enableGameMode,
        description: l10n.enableGameModeSubtitle,
        tags: _splitTags(l10n.tags_game_mode),
        screen: AppScreen.settings,
        anchorId: 'game_mode',
      ),
      SettingItem(
        id: 'game_mode_target_displays',
        title: l10n.gameModeTargetDisplays,
        description: l10n.gameModeTargetDisplaysSubtitle,
        tags: _splitTags(l10n.tags_game_mode_target_displays),
        screen: AppScreen.settings,
        anchorId: 'game_mode_target_displays',
      ),
      SettingItem(
        id: 'game_mode_temp_toggle',
        title: l10n.enableGameModeTemperature,
        description: l10n.enableGameModeTemperatureSubtitle,
        tags: _splitTags(l10n.tags_game_mode_temp),
        screen: AppScreen.settings,
        anchorId: 'game_mode_temp_toggle',
      ),
      SettingItem(
        id: 'game_mode_temp',
        title: l10n.lockedTemperature,
        description: l10n.enableGameModeTemperatureSubtitle,
        tags: _splitTags(l10n.tags_game_mode_temp),
        screen: AppScreen.settings,
        anchorId: 'game_mode_temp',
      ),
      SettingItem(
        id: 'game_mode_brightness',
        title: l10n.lockedBrightness,
        description: l10n.enableGameModeSubtitle,
        tags: _splitTags(l10n.tags_game_mode_brightness),
        screen: AppScreen.settings,
        anchorId: 'game_mode_brightness',
      ),
      SettingItem(
        id: 'game_mode_exit_delay',
        title: l10n.gameModeExitDelay,
        description: l10n.gameModeExitDelaySubtitle,
        tags: _splitTags(l10n.tags_game_mode_exit_delay),
        screen: AppScreen.settings,
        anchorId: 'game_mode_exit_delay',
      ),
      SettingItem(
        id: 'game_mode_whitelist',
        title: l10n.whitelist,
        description: l10n.whitelistSubtitle,
        tags: _splitTags(l10n.tags_game_mode_whitelist),
        screen: AppScreen.settings,
        anchorId: 'game_mode_whitelist',
      ),
      SettingItem(
        id: 'game_mode_blacklist',
        title: l10n.blacklist,
        description: l10n.blacklistSubtitle,
        tags: _splitTags(l10n.tags_game_mode_blacklist),
        screen: AppScreen.settings,
        anchorId: 'game_mode_blacklist',
      ),
      SettingItem(
        id: 'smart_exclusions',
        title: l10n.circadianLimits,
        description: l10n.circadianLimitsSubtitle,
        tags: _splitTags(l10n.tags_circadian_limits),
        screen: AppScreen.settings,
        anchorId: 'circadian_limits',
      ),
      SettingItem(
        id: 'autorun',
        title: l10n.autorun,
        description: l10n.autorunSubtitle,
        tags: _splitTags(l10n.tags_autorun),
        screen: AppScreen.settings,
        anchorId: 'autorun',
      ),
      SettingItem(
        id: 'auto_updates',
        title: l10n.autoUpdatesTitle,
        description: l10n.autoUpdatesSubtitle,
        tags: _splitTags(l10n.tags_auto_updates),
        screen: AppScreen.settings,
        anchorId: 'updates',
      ),
      SettingItem(
        id: 'weather',
        title: l10n.weatherAdjustmentTitle,
        description: l10n.weatherAdjustmentSubtitle,
        tags: _splitTags(l10n.tags_weather),
        screen: AppScreen.settings,
        anchorId: 'weather_adjustment',
      ),
      SettingItem(
        id: 'weather_provider',
        title: l10n.weatherProvider,
        description: l10n.weatherAdjustmentSubtitle,
        tags: _splitTags(l10n.tags_weather),
        screen: AppScreen.settings,
        anchorId: 'weather_provider',
      ),
      SettingItem(
        id: 'weather_brightness',
        title: l10n.weatherBrightnessAdjustmentTitle,
        description: l10n.weatherBrightnessAdjustmentSubtitle,
        tags: _splitTags(l10n.tags_weather_brightness),
        screen: AppScreen.settings,
        anchorId: 'weather_brightness',
      ),
      SettingItem(
        id: 'weather_temperature',
        title: l10n.weatherTemperatureAdjustmentTitle,
        description: l10n.weatherTemperatureAdjustmentSubtitle,
        tags: _splitTags(l10n.tags_weather_temperature),
        screen: AppScreen.settings,
        anchorId: 'weather_temperature',
      ),
      SettingItem(
        id: 'weather_intensity',
        title: l10n.weatherIntensity,
        description: l10n.weatherAdjustmentSubtitle,
        tags: _splitTags(l10n.tags_weather),
        screen: AppScreen.settings,
        anchorId: 'weather_intensity',
      ),
      SettingItem(
        id: 'weather_animations',
        title: l10n.weatherAnimations,
        description: l10n.weatherSettingsSubtitle,
        tags: _splitTags(l10n.tags_weather_animations),
        screen: AppScreen.location,
        anchorId: 'weather_animations',
      ),
      SettingItem(
        id: 'hotkeys',
        title: l10n.globalHotkeys,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys',
      ),
      SettingItem(
        id: 'hotkeys_next_preset',
        title: l10n.nextPreset,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys_next_preset',
      ),
      SettingItem(
        id: 'hotkeys_prev_preset',
        title: l10n.prevPreset,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys_prev_preset',
      ),
      SettingItem(
        id: 'hotkeys_brightness_up',
        title: l10n.increaseBrightness,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys_brightness_up',
      ),
      SettingItem(
        id: 'hotkeys_brightness_down',
        title: l10n.decreaseBrightness,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys_brightness_down',
      ),
      SettingItem(
        id: 'hotkeys_auto_brightness_toggle',
        title: l10n.toggleAutoBrightness,
        description: l10n.globalHotkeysSubtitle,
        tags: _splitTags(l10n.tags_hotkeys),
        screen: AppScreen.settings,
        anchorId: 'hotkeys_auto_brightness_toggle',
      ),
      SettingItem(
        id: 'language',
        title: l10n.language,
        description: l10n.language,
        tags: _splitTags(l10n.tags_language),
        screen: AppScreen.settings,
        anchorId: 'language',
      ),
      SettingItem(
        id: 'solaris_api',
        title: l10n.apiTitle,
        description: l10n.apiNetworkAccessMode,
        tags: _splitTags(l10n.tags_solaris_api),
        screen: AppScreen.settings,
        anchorId: 'solaris_api',
      ),
      SettingItem(
        id: 'api_lan_access',
        title: l10n.apiNetworkAccessMode,
        description: l10n.apiNetworkAccessMode,
        tags: _splitTags(l10n.tags_solaris_api),
        screen: AppScreen.settings,
        anchorId: 'api_lan_access',
      ),
      SettingItem(
        id: 'api_port',
        title: l10n.apiServerPort,
        description: l10n.apiTitle,
        tags: _splitTags(l10n.tags_solaris_api),
        screen: AppScreen.settings,
        anchorId: 'api_port',
      ),
      SettingItem(
        id: 'api_require_token',
        title: l10n.requireLocalTokenLabel,
        description: l10n.requireLocalTokenSubtitle,
        tags: _splitTags(l10n.tags_solaris_api),
        screen: AppScreen.settings,
        anchorId: 'api_require_token',
      ),
      SettingItem(
        id: 'api_keys',
        title: l10n.apiKeysManagementDialogTitle,
        description: l10n.apiKeysManagementSubtitle,
        tags: _splitTags(l10n.tags_api_keys),
        screen: AppScreen.settings,
        anchorId: 'api_keys',
      ),
      SettingItem(
        id: 'webhooks',
        title: l10n.webhooksTitle,
        description: l10n.webhooksSubtitle(0, 0),
        tags: _splitTags(l10n.tags_webhooks),
        screen: AppScreen.settings,
        anchorId: 'webhooks',
      ),

      // Location
      SettingItem(
        id: 'location_region',
        title: l10n.location,
        description: l10n.locationSubtitle,
        tags: _splitTags(l10n.tags_location),
        screen: AppScreen.location,
        anchorId: 'location_region',
      ),
      SettingItem(
        id: 'location_auto',
        title: l10n.autoDetect(''),
        description: l10n.autoDetectSubtitle,
        tags: _splitTags(l10n.tags_location_auto),
        screen: AppScreen.location,
        anchorId: 'location_auto',
      ),
      SettingItem(
        id: 'location_lat',
        title: l10n.latitude,
        description: l10n.manualCoordinateEntry,
        tags: _splitTags(l10n.tags_location),
        screen: AppScreen.location,
        anchorId: 'location_lat',
      ),
      SettingItem(
        id: 'location_lng',
        title: l10n.longitude,
        description: l10n.manualCoordinateEntry,
        tags: _splitTags(l10n.tags_location),
        screen: AppScreen.location,
        anchorId: 'location_lng',
      ),

      // Legal
      SettingItem(
        id: 'legal_info',
        title: l10n.legal,
        description: l10n.disclaimerTitle,
        tags: _splitTags(l10n.tags_legal),
        screen: AppScreen.dashboard,
        anchorId: 'legal_info',
      ),
    ];
  }

  List<String> _splitTags(String tags) {
    if (tags.isEmpty) return [];
    return tags.split(',').map((e) => e.trim().toLowerCase()).toList();
  }

  List<SettingItem> search(String query) {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.trim().toLowerCase();
    final database = _getDatabase();
    List<Map<String, dynamic>> scoredResults = [];

    for (var item in database) {
      double maxScore = 0.0;

      // 1. Exact or partial title match
      final titleLower = item.title.toLowerCase();
      if (titleLower.contains(normalizedQuery)) {
        maxScore = 100.0;
      } else {
        // Fuzzy title match
        maxScore = titleLower.similarityTo(normalizedQuery) * 100;
      }

      // 2. Tags match
      for (var tag in item.tags) {
        if (tag.contains(normalizedQuery)) {
          if (maxScore < 90) maxScore = 90.0;
        } else {
          double tagScore = tag.similarityTo(normalizedQuery) * 100;
          if (tagScore > maxScore) {
            maxScore = tagScore;
          }
        }
      }

      // 3. Description match
      if (item.description.toLowerCase().contains(normalizedQuery)) {
        if (maxScore < 40) maxScore = 40.0;
      }

      if (maxScore > 35.0) {
        // Threshold for relevance
        scoredResults.add({'item': item, 'score': maxScore});
      }
    }

    scoredResults.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return scoredResults.map((e) => e['item'] as SettingItem).toList();
  }
}

final settingsSearchServiceProvider =
    Provider.family<SettingsSearchService, BuildContext>((ref, context) {
      return SettingsSearchService(context);
    });
