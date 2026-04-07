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
    
    // In a real app, these tags would be in ARB files as well.
    // I'll add them to ARB later, but for now I'll use placeholders that call l10n.
    // Wait, the user specifically asked for them to be in ARB.
    // So I should define keys in ARB like "tags_brightness" and access them here.
    
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

      // Settings
      SettingItem(
        id: 'game_mode',
        title: l10n.enableGameMode,
        description: l10n.enableGameModeSubtitle,
        tags: _splitTags(l10n.tags_game_mode),
        screen: AppScreen.settings,
        anchorId: 'game_mode',
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
        anchorId: 'weather_adjustment',
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
        id: 'language',
        title: l10n.language,
        description: l10n.language,
        tags: _splitTags(l10n.tags_language),
        screen: AppScreen.settings,
        anchorId: 'language',
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
        description: l10n.gpsSubtitle,
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

      if (maxScore > 35.0) { // Threshold for relevance
        scoredResults.add({
          'item': item,
          'score': maxScore,
        });
      }
    }

    scoredResults.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scoredResults.map((e) => e['item'] as SettingItem).toList();
  }
}

final settingsSearchServiceProvider = Provider.family<SettingsSearchService, BuildContext>((ref, context) {
  return SettingsSearchService(context);
});
