import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/services/temperature_service.dart';
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
    return currentMap[ids.first] ?? currentMap['all']!;
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

  void toggleEnabled(bool isEnabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(isEnabled: isEnabled));
  }

  void setPreset(TemperaturePresetType type) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    _updateSettings(ids, current.copyWith(activePreset: type));
  }

  void updateCurvePoints(List<FlSpot> newPoints) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = currentSettings();
    final newMap = Map<TemperaturePresetType, List<FlSpot>>.from(
      current.curvesMap,
    );
    newMap[current.activePreset] = newPoints;
    _updateSettings(ids, current.copyWith(curvesMap: newMap));
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
  @override
  int build() => 6500;

  void setTemperature(int val) {
    state = val;
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

    final isAuto = ref.watch(autoAdjustmentProvider);
    final isTempEnabled = ref.watch(isColorTemperatureEnabledProvider);

    if (isAuto && isTempEnabled) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
      final weatherAsync = ref.watch(currentWeatherProvider);
      final monitorIds = ref.watch(selectedMonitorsProvider);

      final id = monitorIds.isNotEmpty ? monitorIds.first : 'all';

      return solarStateAsync.maybeWhen(
        data: (state) {
          return tempSettingsAsync.maybeWhen(
            data: (tempSettingsMap) {
              final tempSettings =
                  tempSettingsMap[id] ?? tempSettingsMap['all']!;
              final target = circadianService.calculateTargetTemperature(
                state.phases,
                state.sunElevation,
                DateTime.now(),
                curvePoints: tempSettings.curvePoints,
                weather: weatherAsync.value,
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

  void _saveTemperature(int val) {
    ref.read(sharedPreferencesProvider)?.setInt(_lastTempKey, val);
  }
}

final currentTemperatureProvider =
    NotifierProvider<CurrentTemperatureNotifier, int>(
      CurrentTemperatureNotifier.new,
    );
