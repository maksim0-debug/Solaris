import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:fl_chart/fl_chart.dart';

final temperatureServiceProvider = Provider((ref) => TemperatureService());

class ColorTemperatureEnabledNotifier extends Notifier<bool> {
  static const _filename = 'color_temp_enabled.json';

  @override
  bool build() {
    _loadInit();
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getBool('color_temperature_enabled') ?? false;
  }

  Future<void> _loadInit() async {
    final storage = ref.read(storageServiceProvider);
    final data = await storage.load(_filename);
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
      print('Error loading temperature settings: $e');
    }
    return map;
  }

  Future<void> _saveSettingsMap(Map<String, TemperatureState> map) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      final encoded = map.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    }
  }

  TemperatureState currentSettings() {
    final ids = ref.read(selectedMonitorsProvider);
    final currentMap = state.value ?? {'all': TemperatureState()};
    return currentMap[ids.firstOrNull ?? 'all'] ?? currentMap['all']!;
  }

  Future<void> _updateSettings(
    Set<String> monitorIds,
    TemperatureState newState,
  ) async {
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
    await _saveSettingsMap(newStateMap);
  }

  void setEnabled(bool value) {
    if (state.value != null) {
      final ids = ref.read(selectedMonitorsProvider);
      final firstId = ids.firstOrNull ?? 'all';
      final currentMap = state.value!;
      final current = currentMap[firstId] ?? currentMap['all']!;
      if (current.isEnabled == value) return;
    }

    ref
        .read(sharedPreferencesProvider)
        ?.setBool('auto_temperature_enabled', value);
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isEnabled: value));
  }

  void toggleEnabled(bool isEnabled) {
    setEnabled(isEnabled);
  }

  void updateSmartCircadian(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isSmartCircadianEnabled: enabled));
  }

  void updateSleepDebt(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isSleepDebtEnabled: enabled));
  }

  void updateSleepPressure(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isSleepPressureEnabled: enabled));
  }

  void updateTimeShift(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isTimeShiftEnabled: enabled));
  }

  void updateWindDown(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isWindDownEnabled: enabled));
  }

  void setPreset(TemperaturePresetType type) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(
      ids,
      current.copyWith(activePreset: type, clearActiveUserPresetId: true),
    );
  }

  void setActiveUserPreset(String id) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
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
    final newUserPresets = current.userPresets.where((p) => p.id != id).toList();
    final newPresetOrder =
        current.presetOrder.where((orderId) => orderId != 'user:$id').toList();
 
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
 
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
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
      _updateSettings(ref.read(selectedMonitorsProvider), current.copyWith(userPresets: newUserPresets));
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

  void setTemperature(int val) {
    ref.read(temperatureSettingsProvider.notifier).toggleEnabled(false);
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

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastTemp = prefs?.getInt(_lastTempKey) ?? 6500;

    final isAuto = ref.watch(autoTemperatureAdjustmentProvider);
    final isTempEnabled = ref.watch(isColorTemperatureEnabledProvider);

    if (isAuto && isTempEnabled) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
      final weatherAsync = ref.watch(currentWeatherProvider);
      final monitorIds = ref.watch(selectedMonitorsProvider);

      final id = monitorIds.firstOrNull ?? 'all';

      return solarStateAsync.maybeWhen(
        data: (state) {
          return tempSettingsAsync.maybeWhen(
            data: (tempSettingsMap) {
              final tempSettings =
                  tempSettingsMap[id] ?? tempSettingsMap['all']!;

              if (!tempSettings.isEnabled) {
                return ref.watch(manualTemperatureProvider);
              }

              final smartData = tempSettings.isSmartCircadianEnabled
                  ? ref.watch(smartCircadianTemperatureDataProvider(id))
                  : const SmartCircadianData.neutral();

              double effectiveElevation = state.sunElevation;
              if (tempSettings.isSmartCircadianEnabled &&
                  smartData.timeOffset != Duration.zero) {
                final locationAsync = ref.read(effectiveLocationProvider);
                final pos = locationAsync.value;
                if (pos != null) {
                  final sunService = ref.read(sunCalculatorServiceProvider);
                  final shiftedTime = DateTime.now().subtract(
                    smartData.timeOffset,
                  );
                  effectiveElevation = sunService.getSunElevation(
                    pos.latitude,
                    pos.longitude,
                    shiftedTime,
                  );

                  if (state.sunElevation < 0 && effectiveElevation > 10) {
                    effectiveElevation = effectiveElevation.clamp(-20.0, 10.0);
                  }
                }
              }

              final target = circadianService.calculateTargetTemperature(
                state.phases,
                effectiveElevation,
                DateTime.now(),
                curvePoints: tempSettings.curvePoints,
                weather: weatherAsync.value,
                smartData: smartData,
              );
              _saveTemperature(target);
              return target;
            },
            orElse: () => lastTemp,
          );
        },
        orElse: () => lastTemp,
      );
    }
    return ref.watch(manualTemperatureProvider);
  }

  void setManualTemperature(int val) {
    ref.read(temperatureSettingsProvider.notifier).setEnabled(false);
    ref.read(manualTemperatureProvider.notifier).setTemperature(val);
    _saveTemperature(val);
  }

  void _saveTemperature(int val) {
    ref.read(sharedPreferencesProvider)?.setInt(_lastTempKey, val);
  }
}

final currentTemperatureProvider =
    NotifierProvider<CurrentTemperatureNotifier, int>(
      CurrentTemperatureNotifier.new,
    );
