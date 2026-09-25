import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:solaris/models/temperature_state.dart';
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
    // When auto temperature is enabled (value == true), circadianAdjustmentProvider
    // reactively detects temperatureSettingsProvider change and smoothly applies
    // the circadian temperature without creating a circular dependency.
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

class CurrentTemperatureNotifier extends Notifier<int> {
  static const _lastTempKey = 'last_known_temperature';

  List<FlSpot>? _resolveTemperatureCurvePoints(
    String? presetId,
    TemperatureState tempSettings,
  ) {
    if (presetId == null) return null;
    final userPreset = tempSettings.userPresets.firstWhereOrNull(
      (p) => p.id == presetId,
    );
    if (userPreset != null) return userPreset.points;
    final systemType = TemperaturePresetType.values.firstWhereOrNull(
      (e) => e.name == presetId,
    );
    if (systemType != null) {
      return tempSettings.curvesMap[systemType];
    }
    return null; // Safe Fallback to global circadian temperature
  }

  @override
  int build() {
    final isTempEnabled = ref.watch(isColorTemperatureEnabledProvider);
    if (!isTempEnabled) {
      return 6500;
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    final lastTemp = prefs?.getInt(_lastTempKey) ?? 6500;

    final activeProcessState = ref.watch(activeProcessServiceProvider);
    final isGamingMode = ref.watch(gamingModeProvider);
    final monitorIds = ref.watch(selectedMonitorsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
    final id = monitorIds.firstOrNull ?? 'all';

    final allSettings = settingsAsync.maybeWhen(
      data: (map) => map['all'] ?? SettingsState(),
      orElse: () => SettingsState(),
    );
    final monitorSettings = settingsAsync.maybeWhen(
      data: (map) => map[id] ?? map['all'] ?? SettingsState(),
      orElse: () => SettingsState(),
    );

    // 1 & 2: Active App Rule Cascade for Temperature
    final activeAppExe = activeProcessState.activeProcess;
    final isAppSuppressed = activeProcessState.suppressedPids.isNotEmpty;
    final appRule = (!isAppSuppressed && activeAppExe.isNotEmpty)
        ? (monitorSettings.appOverrides.firstWhereOrNull(
                (r) => r.isEnabled && r.exeName == activeAppExe,
              ) ??
              allSettings.appOverrides.firstWhereOrNull(
                (r) => r.isEnabled && r.exeName == activeAppExe,
              ))
        : null;

    const minTemp = TemperatureConstants.min;
    const maxTemp = TemperatureConstants.max;

    if (appRule != null && appRule.temperatureMode != AppOverrideMode.global) {
      if (appRule.temperatureMode == AppOverrideMode.fixed &&
          appRule.fixedTemperature != null) {
        final val = appRule.fixedTemperature!
            .clamp(minTemp.toDouble(), maxTemp.toDouble())
            .round();
        _saveTemperature(val);
        return val;
      } else if (appRule.temperatureMode == AppOverrideMode.curve) {
        final tempSettings = tempSettingsAsync.maybeWhen(
          data: (map) => map[id] ?? map['all'] ?? TemperatureState(),
          orElse: () => TemperatureState(),
        );
        final curvePoints = _resolveTemperatureCurvePoints(
          appRule.temperatureCurvePresetId,
          tempSettings,
        );
        if (curvePoints != null) {
          final solarStateAsync = ref.watch(solarStateStreamProvider);
          final circadianService = ref.watch(circadianServiceProvider);
          final weatherAsync = ref.watch(currentWeatherProvider);
          final now = ref.watch(minuteTimeProvider).value ?? DateTime.now();

          return solarStateAsync.maybeWhen(
            data: (state) {
              final isSmart = monitorSettings.isSmartCircadianEnabled;
              final smartData = isSmart
                  ? ref.watch(smartCircadianTemperatureDataProvider(id))
                  : const SmartCircadianData.neutral();

              final result = circadianService.calculateTargetTemperature(
                state.phases,
                state.sunElevation,
                now,
                curvePoints: curvePoints,
                weather: allSettings.isWeatherTemperatureAdjustmentEnabled
                    ? weatherAsync.value
                    : null,
                weatherIntensity: allSettings.weatherAdjustmentIntensity,
                smartData: smartData,
              );
              final val = result.finalTemperature
                  .clamp(minTemp, maxTemp)
                  .round();
              _saveTemperature(val);
              return val;
            },
            orElse: () => lastTemp,
          );
        }
        // Safe Fallback to global circadian temperature if preset was deleted
      }
    }

    // 3. Game Mode Cascade for Temperature
    final isMonitorGaming =
        isGamingMode &&
        (monitorSettings.isGameModeEnabled || allSettings.isGameModeEnabled);
    final isTempGaming =
        monitorSettings.isGameModeTemperatureEnabled ||
        allSettings.isGameModeTemperatureEnabled;

    if (isMonitorGaming && isTempGaming) {
      final gameTemp = monitorSettings.isGameModeTemperatureEnabled
          ? monitorSettings.gameModeTemperature
          : allSettings.gameModeTemperature;
      return gameTemp.round();
    }

    // 4. Global Auto / Circadian Cascade for Temperature
    final isAuto = ref.watch(autoTemperatureAdjustmentProvider);

    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
      final weatherAsync = ref.watch(currentWeatherProvider);

      final now = ref.watch(minuteTimeProvider).value ?? DateTime.now();

      return solarStateAsync.maybeWhen(
        data: (state) {
          return tempSettingsAsync.maybeWhen(
            data: (tempSettingsMap) {
              final tempSettings =
                  tempSettingsMap[id] ??
                  tempSettingsMap['all'] ??
                  TemperatureState();

              if (!tempSettings.isEnabled) {
                return tempSettings.manualTemperature ??
                    tempSettingsMap['all']?.manualTemperature ??
                    ref.watch(manualTemperatureProvider);
              }

              final isSmart = monitorSettings.isSmartCircadianEnabled;
              final smartData = isSmart
                  ? ref.watch(smartCircadianTemperatureDataProvider(id))
                  : const SmartCircadianData.neutral();

              final result = circadianService.calculateTargetTemperature(
                state.phases,
                state.sunElevation,
                now,
                curvePoints: tempSettings.curvePoints,
                weather: allSettings.isWeatherTemperatureAdjustmentEnabled
                    ? weatherAsync.value
                    : null,
                weatherIntensity: allSettings.weatherAdjustmentIntensity,
                smartData: smartData,
              );
              final val = result.finalTemperature.clamp(
                minTemp,
                TemperatureConstants.max,
              );
              _saveTemperature(val);
              return val;
            },
            orElse: () => lastTemp,
          );
        },
        orElse: () => lastTemp,
      );
    }
    final tempSettings = tempSettingsAsync.maybeWhen(
      data: (map) => map[id] ?? map['all'] ?? TemperatureState(),
      orElse: () => TemperatureState(),
    );
    final globalManual = tempSettingsAsync.value?['all']?.manualTemperature;
    return tempSettings.manualTemperature ??
        globalManual ??
        ref.watch(manualTemperatureProvider);
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
