import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:timezone/timezone.dart' as tz;

final temperatureServiceProvider = Provider((ref) => TemperatureService());

class ColorTemperatureEnabledNotifier extends Notifier<bool> {
  static const _filename = 'color_temp_enabled.json';

  @override
  bool build() {
    _loadInit();
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getBool('color_temperature_enabled') ?? true;
  }

  Future<void> _loadInit() async {
    final storage = ref.read(storageServiceProvider);
    final data = await storage.load(_filename);
    if (!ref.mounted) return;
    if (data != null && data == 'true') {
      if (state != true) {
        state = true;
      }
    } else if (data != null && data == 'false') {
      if (state != false) {
        state = false;
      }
    }
  }

  void toggle() {
    set(!state);
  }

  void set(bool val) {
    state = val;
    ref
        .read(sharedPreferencesProvider)
        ?.setBool('color_temperature_enabled', val);
    ref.read(storageServiceProvider).save(_filename, val ? 'true' : 'false');
    if (!val) {
      unawaited(resetToNeutralNow());
    }
  }

  Future<void> resetToNeutralNow() async {
    final tempService = ref.read(temperatureServiceProvider);
    final monitorService = ref.read(monitorServiceProvider);
    final monitors = await ref.read(monitorListProvider.future);

    await tempService.resetTemperatureNow(
      selection: 'all',
      monitors: monitors,
      monitorService: monitorService,
      updateTemperatureCallback: (id, val) {},
    );
  }
}

final isColorTemperatureEnabledProvider =
    NotifierProvider<ColorTemperatureEnabledNotifier, bool>(
      ColorTemperatureEnabledNotifier.new,
    );

class EditingTemperatureNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool val) => state = val;
}

final editingTemperatureProvider =
    NotifierProvider<EditingTemperatureNotifier, bool>(
      EditingTemperatureNotifier.new,
    );

class TemperatureSettingsNotifier
    extends AsyncNotifier<Map<String, TemperatureState>> {
  static const _prefsKey = 'temperature_settings_map';

  @override
  Future<Map<String, TemperatureState>> build() async {
    ref.onDispose(() {
      _saveDebounceTimer?.cancel();
      _saveDebounceTimer = null;
    });
    return _loadSettings();
  }

  Map<String, TemperatureState> _loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    final Map<String, TemperatureState> map = {'all': TemperatureState()};
    if (prefs == null) return map;

    final jsonStr = prefs.getString(_prefsKey);
    // fallback check for old single state
    if (jsonStr == null) {
      final oldJsonStr = prefs.getString('temperature_settings');
      if (oldJsonStr != null) {
        try {
          final decoded = jsonDecode(oldJsonStr) as Map<String, dynamic>;
          map['all'] = TemperatureState.fromJson(decoded);
          unawaited(_saveSettingsMap(map));
        } catch (_) {}
      }
      return map;
    }

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        map[key] = TemperatureState.fromJson(value as Map<String, dynamic>);
      });
    } catch (e) {
      debugPrint('Error loading temperature settings: $e');
    }
    return map;
  }

  Timer? _saveDebounceTimer;

  Future<void> _saveSettingsMap(Map<String, TemperatureState> map) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      final encoded = map.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    }
  }

  void _debouncedSaveSettingsMap(Map<String, TemperatureState> map) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _saveDebounceTimer = null;
      _saveSettingsMap(map);
    });
  }

  TemperatureState currentSettings([String? monitorId]) {
    final id =
        monitorId ?? ref.read(selectedMonitorsProvider).firstOrNull ?? 'all';
    final currentMap = state.value ?? {'all': TemperatureState()};
    return currentMap[id] ?? currentMap['all'] ?? TemperatureState();
  }

  Future<void> _updateSettings(
    Set<String> monitorIds,
    TemperatureState newState, {
    bool debounceSave = false,
  }) async {
    final currentMap = state.value ?? {'all': TemperatureState()};
    final newStateMap = Map<String, TemperatureState>.from(currentMap);

    for (final id in monitorIds) {
      newStateMap[id] = newState;
      if (id == 'all') {
        for (final key in newStateMap.keys) {
          newStateMap[key] = newState;
        }
      }
    }

    state = AsyncData(newStateMap);
    if (debounceSave) {
      _debouncedSaveSettingsMap(newStateMap);
    } else {
      _saveDebounceTimer?.cancel();
      _saveDebounceTimer = null;
      await _saveSettingsMap(newStateMap);
    }
  }

  void syncAllMonitorsToGlobal() {
    final currentMap = state.value ?? {'all': TemperatureState()};
    final global = currentMap['all'] ?? TemperatureState();
    final newStateMap = Map<String, TemperatureState>.from(currentMap);

    for (final key in newStateMap.keys.toList()) {
      if (key != 'all') {
        newStateMap[key] = newStateMap[key]!.copyWith(
          activePreset: global.activePreset,
          activeUserPresetId: global.activeUserPresetId,
          clearActiveUserPresetId: global.activeUserPresetId == null,
          curvesMap: global.curvesMap,
          userPresets: global.userPresets,
          isSmartCircadianEnabled: global.isSmartCircadianEnabled,
          isSleepDebtEnabled: global.isSleepDebtEnabled,
          isSleepPressureEnabled: global.isSleepPressureEnabled,
          isTimeShiftEnabled: global.isTimeShiftEnabled,
          isWindDownEnabled: global.isWindDownEnabled,
        );
      }
    }

    debugPrint(
      '[TemperatureSettingsNotifier] Synchronized all monitor temperature presets with global preset (${global.activePreset.name})',
    );
    state = AsyncData(newStateMap);
    _saveSettingsMap(newStateMap);
  }

  void setEnabled(bool value, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    final firstId = ids.firstOrNull ?? 'all';
    if (state.value != null) {
      final currentMap = state.value!;
      final current = currentMap[firstId] ?? currentMap['all']!;
      if (current.isEnabled == value && ids.length == 1) return;
    }

    if (ids.contains('all')) {
      ref
          .read(sharedPreferencesProvider)
          ?.setBool('auto_temperature_enabled', value);
    }
    final current = currentSettings(firstId);
    _updateSettings(ids, current.copyWith(isEnabled: value));

    final monitors = ref.read(monitorListProvider).value ?? [];
    if (monitors.isEmpty) return;
    final tempService = ref.read(temperatureServiceProvider);
    final monitorService = ref.read(monitorServiceProvider);
    final monitorListNotifier = ref.read(monitorListProvider.notifier);
    final isGaming = ref.read(gamingModeProvider);
    final settingsMap = ref.read(settingsProvider).value ?? {};
    final globalSettings = settingsMap['all'] ?? SettingsState();

    final targetMonitors = ids.contains('all')
        ? monitors
        : monitors
              .where((m) => ids.contains(m.deviceName) || ids.contains(m.id))
              .toList();

    // When auto temperature is disabled, instantly restore manual temperature to hardware & state
    if (!value) {
      final currentMap = state.value ?? {'all': TemperatureState()};
      final fallbackManualTemp = ref.read(manualTemperatureProvider);

      for (final m in targetMonitors) {
        final mSettings = settingsMap[m.deviceName] ?? globalSettings;
        if (isGaming &&
            mSettings.isGameModeEnabled &&
            mSettings.isGameModeTemperatureEnabled) {
          continue;
        }

        final mState =
            currentMap[m.deviceName] ??
            currentMap[m.id] ??
            currentMap['all'] ??
            current;
        final targetTemp =
            mState.manualTemperature ??
            current.manualTemperature ??
            fallbackManualTemp;

        unawaited(
          tempService.setTemperatureInstant(
            selection: m.deviceName,
            targetValue: targetTemp.toDouble(),
            monitors: monitors,
            monitorService: monitorService,
            updateTemperatureCallback: (id, val) {
              monitorListNotifier.updateTemperature(id, val);
            },
          ),
        );
      }
    }
  }

  void setManualTemperature(
    int val, {
    String? monitorId,
    bool debounceSave = false,
  }) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    final firstId = ids.firstOrNull ?? 'all';
    final current = currentSettings(firstId);
    _updateSettings(
      ids,
      current.copyWith(isEnabled: false, manualTemperature: val),
      debounceSave: debounceSave,
    );
  }

  void toggleEnabled(bool isEnabled, {String? monitorId}) {
    setEnabled(isEnabled, monitorId: monitorId);
  }

  void _updateMonitorSettings(
    Set<String> monitorIds,
    TemperatureState Function(TemperatureState current) updater,
  ) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;

    final currentMap = state.value ?? {'all': TemperatureState()};
    final newStateMap = Map<String, TemperatureState>.from(currentMap);

    for (final id in monitorIds) {
      if (id == 'all') {
        newStateMap['all'] = updater(newStateMap['all'] ?? TemperatureState());
        for (final key in newStateMap.keys.toList()) {
          if (key != 'all') {
            newStateMap[key] = updater(newStateMap[key]!);
          }
        }
      } else {
        final cur = newStateMap[id] ?? newStateMap['all'] ?? TemperatureState();
        newStateMap[id] = updater(cur);
      }
    }

    state = AsyncData(newStateMap);
    _saveSettingsMap(newStateMap);
  }

  void updateSmartCircadian(bool enabled, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    _updateMonitorSettings(
      ids,
      (cur) => cur.copyWith(isSmartCircadianEnabled: enabled),
    );
  }

  void updateSleepDebt(bool enabled, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    _updateMonitorSettings(
      ids,
      (cur) => cur.copyWith(isSleepDebtEnabled: enabled),
    );
  }

  void updateSleepPressure(bool enabled, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    _updateMonitorSettings(
      ids,
      (cur) => cur.copyWith(isSleepPressureEnabled: enabled),
    );
  }

  void updateTimeShift(bool enabled, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    _updateMonitorSettings(
      ids,
      (cur) => cur.copyWith(isTimeShiftEnabled: enabled),
    );
  }

  void updateWindDown(bool enabled, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    _updateMonitorSettings(
      ids,
      (cur) => cur.copyWith(isWindDownEnabled: enabled),
    );
  }

  void setPreset(TemperaturePresetType type, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    final current = currentSettings(ids.firstOrNull);
    _updateSettings(
      ids,
      current.copyWith(activePreset: type, clearActiveUserPresetId: true),
    );
  }

  void setActiveUserPreset(String id, {String? monitorId}) {
    final ids = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);
    final current = currentSettings(ids.firstOrNull);
    _updateSettings(ids, current.copyWith(activeUserPresetId: id));
  }

  void saveAsNewPreset(String name) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    final newPreset = UserPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      points: List<FlSpot>.from(current.curvePoints),
      initialPoints: List<FlSpot>.from(current.curvePoints),
    );
    final newUserPresets = List<UserPreset>.from(current.userPresets)
      ..add(newPreset);
    final newPresetOrder = List<String>.from(current.presetOrder)
      ..add('user:${newPreset.id}');
    _updateSettings(
      ids,
      current.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newPreset.id,
        presetOrder: newPresetOrder,
      ),
    );
  }

  void deleteUserPreset(String id) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    final newUserPresets = current.userPresets
        .where((p) => p.id != id)
        .toList();
    final newPresetOrder = current.presetOrder
        .where((orderId) => orderId != 'user:$id')
        .toList();

    String? newActiveId = current.activeUserPresetId;
    if (newActiveId == id) {
      newActiveId = newUserPresets.isNotEmpty ? newUserPresets.first.id : null;
    }

    _updateSettings(
      ids,
      current.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newActiveId,
        presetOrder: newPresetOrder,
      ),
    );
  }

  void reorderAllPresets(int oldIndex, int newIndex) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    final newOrder = List<String>.from(current.presetOrder);

    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    _updateSettings(ids, current.copyWith(presetOrder: newOrder));
  }

  void renameUserPreset(String id, String newName) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    final newUserPresets = current.userPresets.map((p) {
      if (p.id == id) {
        return UserPreset(
          id: p.id,
          name: newName,
          points: p.points,
          initialPoints: p.initialPoints,
        );
      }
      return p;
    }).toList();

    _updateSettings(ids, current.copyWith(userPresets: newUserPresets));
  }

  void updateCurvePoints(List<FlSpot> newPoints) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();

    if (current.activeUserPresetId != null) {
      final newUserPresets = current.userPresets.map((p) {
        if (p.id == current.activeUserPresetId) {
          return UserPreset(
            id: p.id,
            name: p.name,
            points: newPoints,
            initialPoints: p.initialPoints,
          );
        }
        return p;
      }).toList();
      _updateSettings(ids, current.copyWith(userPresets: newUserPresets));
    } else {
      final newMap = Map<TemperaturePresetType, List<FlSpot>>.from(
        current.curvesMap,
      );
      newMap[current.activePreset] = newPoints;
      _updateSettings(ids, current.copyWith(curvesMap: newMap));
    }
  }

  void addCurvePoint(FlSpot point) {
    final current = currentSettings();
    final newPoints = List<FlSpot>.from(current.curvePoints)..add(point);
    newPoints.sort((a, b) => a.x.compareTo(b.x));
    updateCurvePoints(newPoints);
  }

  void removeCurvePoint(int index) {
    final current = currentSettings();
    final newPoints = List<FlSpot>.from(current.curvePoints);
    if (index > 0 && index < newPoints.length - 1) {
      newPoints.removeAt(index);
      updateCurvePoints(newPoints);
    }
  }

  void resetCurrentPreset() {
    final current = currentSettings();
    if (current.activeUserPresetId != null) {
      final newUserPresets = current.userPresets.map((p) {
        if (p.id == current.activeUserPresetId) {
          return UserPreset(
            id: p.id,
            name: p.name,
            points: List<FlSpot>.from(p.initialPoints),
            initialPoints: List<FlSpot>.from(p.initialPoints),
          );
        }
        return p;
      }).toList();
      _updateSettings(
        ref.read(selectedMonitorsProvider),
        current.copyWith(userPresets: newUserPresets),
      );
      return;
    }

    final defaultPoints = PresetConstants.getTemperatureDefaultPoints(
      current.activePreset,
    );
    updateCurvePoints(defaultPoints);
  }
}

final temperatureSettingsProvider =
    AsyncNotifierProvider<
      TemperatureSettingsNotifier,
      Map<String, TemperatureState>
    >(TemperatureSettingsNotifier.new);

class ManualTemperatureNotifier extends Notifier<int> {
  static const _manualTemperatureKey = 'manual_temperature';

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getInt(_manualTemperatureKey) ?? 6500;
  }

  void update(int val) {
    state = val;
    ref.read(sharedPreferencesProvider)?.setInt(_manualTemperatureKey, val);
  }

  void setTemperature(int val) {
    ref.read(temperatureSettingsProvider.notifier).setEnabled(false);
    state = val;
    ref.read(sharedPreferencesProvider)?.setInt(_manualTemperatureKey, val);
  }
}

final manualTemperatureProvider =
    NotifierProvider<ManualTemperatureNotifier, int>(
      ManualTemperatureNotifier.new,
    );

/// Resolves temperature per display so explanation and hardware share its source.
final temperatureTargetProvider = Provider.family<TemperatureTarget?, String>((
  ref,
  id,
) {
  TemperatureTarget fixed(
    TemperatureSource source,
    int value, {
    String? application,
  }) => TemperatureTarget(
    source: source,
    applicationName: application,
    data: const SmartCircadianData.neutral().copyWith(
      baseTemperature: value,
      finalTemperature: value,
    ),
  );
  if (!ref.watch(isColorTemperatureEnabledProvider)) {
    return fixed(TemperatureSource.disabled, 6500);
  }
  final map = ref.watch(settingsProvider).value;
  if (map == null) return null;
  final global = map['all'] ?? SettingsState();
  final settings = map[id] ?? global;
  final rule = resolveActiveAppRule(
    settings,
    global,
    ref.watch(activeProcessServiceProvider),
  );
  if (rule?.temperatureMode == AppOverrideMode.fixed &&
      (rule?.fixedTemperature?.isFinite ?? false)) {
    return fixed(
      TemperatureSource.appFixed,
      rule!.fixedTemperature!.round().clamp(
        TemperatureConstants.min,
        TemperatureConstants.max,
      ),
      application: rule.appDisplayName,
    );
  }
  final tempMap = ref.watch(temperatureSettingsProvider).value;
  final temp = tempMap?[id] ?? tempMap?['all'];
  if (rule?.temperatureMode == AppOverrideMode.curve && temp != null) {
    final presetId = rule!.temperatureCurvePresetId;
    final user = temp.userPresets.firstWhereOrNull((p) => p.id == presetId);
    final system = TemperaturePresetType.values.firstWhereOrNull(
      (p) => p.name == presetId,
    );
    final points = user?.points ?? temp.curvesMap[system];
    if (points != null && points.isNotEmpty) {
      final solar = ref.watch(debouncedSolarStateProvider).value;
      if (solar == null) return null;
      final timezone = ref.watch(effectiveTimezoneProvider);
      final now =
          ref.watch(minuteTimeProvider).value ?? tz.TZDateTime.now(timezone);
      final smart =
          settings.isSmartCircadianEnabled && temp.isSmartCircadianEnabled
          ? ref.watch(smartCircadianTemperatureDataProvider(id))
          : const SmartCircadianData.neutral();
      final weather = ref.watch(currentWeatherProvider).value;
      final result = ref
          .watch(circadianServiceProvider)
          .calculateTargetTemperature(
            solar.phases,
            solar.sunElevation,
            now,
            curvePoints: points,
            weather: settings.isWeatherTemperatureAdjustmentEnabled
                ? weather
                : null,
            weatherIntensity: settings.weatherAdjustmentIntensity,
            smartData: smart,
            circadianMode: CircadianMode.normalizedCurve,
            maxElevation: solar.maxElevation,
            minElevation: solar.minElevation,
          );
      return TemperatureTarget(
        source: TemperatureSource.appCurve,
        systemPreset: user == null ? system : null,
        userPresetName: user?.name,
        applicationName: rule.appDisplayName,
        data: smart.copyWith(
          baseTemperature: result.baseTemperature,
          finalTemperature: result.finalTemperature,
          weatherCode: weather?.weatherCode,
          weatherTemperatureImpact: result.weatherImpact,
          timeShiftTemperatureImpact: result.timeShiftImpact,
          windDownTemperatureImpact: result.windDownImpact,
          sleepPressureTemperatureImpact: result.sleepPressureImpact,
          sleepDebtTemperatureImpact: result.sleepDebtImpact,
          temperatureLimitImpact: result.limitImpact,
          temperatureRoundingImpact: result.roundingImpact,
        ),
      );
    }
  }
  if (ref.watch(gamingModeProvider) &&
      (settings.isGameModeEnabled || global.isGameModeEnabled) &&
      (settings.isGameModeTemperatureEnabled ||
          global.isGameModeTemperatureEnabled)) {
    return fixed(
      TemperatureSource.game,
      (settings.isGameModeTemperatureEnabled
              ? settings.gameModeTemperature
              : global.gameModeTemperature)
          .round()
          .clamp(TemperatureConstants.min, TemperatureConstants.max),
    );
  }
  if (temp == null) return null;
  if (!temp.isEnabled) {
    final int manual =
        temp.manualTemperature ??
        tempMap?['all']?.manualTemperature ??
        ref.watch(manualTemperatureProvider);
    return fixed(
      TemperatureSource.manual,
      manual.clamp(TemperatureConstants.min, TemperatureConstants.max),
    );
  }
  final data = ref.watch(smartCircadianTemperatureDataProvider(id));
  if (data.finalTemperature == 0) return null;
  return TemperatureTarget(
    source: settings.circadianMode == CircadianMode.solarPhases
        ? TemperatureSource.solarPhases
        : TemperatureSource.curve,
    data: data,
    systemPreset: data.activeSystemTemperaturePreset,
    userPresetName: data.activeUserTemperaturePresetName,
  );
});

class CurrentTemperatureNotifier extends Notifier<int> {
  static const _lastTempKey = 'last_known_temperature';

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final id = ref.watch(selectedMonitorsProvider).firstOrNull ?? 'all';
    final target = ref.watch(temperatureTargetProvider(id));
    if (target == null) return prefs?.getInt(_lastTempKey) ?? 6500;
    if (!target.isDisabled &&
        !target.isManual &&
        target.source != TemperatureSource.game) {
      _saveTemperature(target.value);
    }
    return target.value;
  }

  void setManualTemperature(
    int val, {
    String? monitorId,
    bool debounceSave = false,
  }) {
    ref.read(activeProcessServiceProvider.notifier).suppressActiveApp();
    if (!ref.read(isColorTemperatureEnabledProvider)) {
      ref.read(isColorTemperatureEnabledProvider.notifier).set(true);
    }
    ref
        .read(temperatureSettingsProvider.notifier)
        .setManualTemperature(
          val,
          monitorId: monitorId,
          debounceSave: debounceSave,
        );
    if (monitorId == null || monitorId == 'all') {
      ref.read(manualTemperatureProvider.notifier).update(val);
      _saveTemperature(val);
    }
    state = val;

    final monitors = ref.read(monitorListProvider).value ?? [];
    if (monitors.isNotEmpty) {
      final tempService = ref.read(temperatureServiceProvider);
      final monitorService = ref.read(monitorServiceProvider);
      final monitorListNotifier = ref.read(monitorListProvider.notifier);
      final isGaming = ref.read(gamingModeProvider);
      final settingsMap = ref.read(settingsProvider).value ?? {};
      final globalSettings = settingsMap['all'] ?? SettingsState();

      final selection = monitorId != null
          ? {monitorId}
          : ref.read(selectedMonitorsProvider);

      final targetMonitors = selection.contains('all')
          ? monitors
          : monitors
                .where(
                  (m) =>
                      selection.contains(m.deviceName) ||
                      selection.contains(m.id),
                )
                .toList();

      for (final m in targetMonitors) {
        final mSettings = settingsMap[m.deviceName] ?? globalSettings;
        if (isGaming &&
            mSettings.isGameModeEnabled &&
            mSettings.isGameModeTemperatureEnabled) {
          continue;
        }

        unawaited(
          tempService.setTemperatureInstant(
            selection: m.deviceName,
            targetValue: val.toDouble(),
            monitors: monitors,
            monitorService: monitorService,
            updateTemperatureCallback: (id, v) {
              monitorListNotifier.updateTemperature(id, v);
            },
          ),
        );
      }
    }
  }

  void _saveTemperature(int val) {
    ref.read(sharedPreferencesProvider)?.setInt(_lastTempKey, val);
  }
}

final currentTemperatureProvider =
    NotifierProvider<CurrentTemperatureNotifier, int>(
      CurrentTemperatureNotifier.new,
    );
