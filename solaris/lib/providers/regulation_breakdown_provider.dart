import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/models/regulation_group.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/monitor_service.dart';

class RegulationBreakdownSelection {
  const RegulationBreakdownSelection({
    required this.brightness,
    required this.temperature,
    required this.allSelected,
    required this.selectedCount,
  });

  final List<RegulationGroup<BrightnessTarget>> brightness;
  final List<RegulationGroup<TemperatureTarget>> temperature;
  final bool allSelected;
  final int selectedCount;
}

List<Object?> _sleepControls(
  SettingsState settings, {
  required bool temperature,
  TemperatureState? temp,
}) {
  if (!settings.isSmartCircadianEnabled ||
      (temperature && !temp!.isSmartCircadianEnabled)) {
    return [false];
  }
  final wind =
      settings.isWindDownMasterEnabled &&
      (temperature ? temp!.isWindDownEnabled : settings.isWindDownEnabled);
  final shift =
      settings.isTimeShiftMasterEnabled &&
      (temperature ? temp!.isTimeShiftEnabled : settings.isTimeShiftEnabled);
  final pressure =
      settings.isSleepPressureMasterEnabled &&
      (temperature
          ? temp!.isSleepPressureEnabled
          : settings.isSleepPressureEnabled);
  final debt =
      settings.isSleepDebtMasterEnabled &&
      (temperature ? temp!.isSleepDebtEnabled : settings.isSleepDebtEnabled);
  return [
    true,
    wind,
    shift,
    pressure,
    debt,
    if (wind) ...[
      settings.windDownDurationMinutes,
      temperature
          ? settings.windDownTemperatureIntensity
          : settings.windDownBrightnessIntensity,
    ],
    if (shift) ...[
      settings.timeShiftDurationMinutes,
      temperature
          ? settings.timeShiftTemperatureIntensity
          : settings.timeShiftBrightnessIntensity,
    ],
    if (pressure) ...[
      settings.sleepPressureWakeLimitHours,
      temperature
          ? settings.sleepPressureTemperatureIntensity
          : settings.sleepPressureBrightnessIntensity,
    ],
    if (debt) ...[
      settings.sleepDebtThresholdMinutes,
      temperature
          ? settings.sleepDebtTemperatureIntensity
          : settings.sleepDebtBrightnessIntensity,
    ],
  ];
}

final regulationBreakdownProvider = Provider<RegulationBreakdownSelection>((
  ref,
) {
  final monitors = ref.watch(monitorListProvider).value ?? [];
  final selection = ref.watch(selectedMonitorsProvider);
  final selected = monitors
      .where(
        (m) =>
            selection.contains('all') ||
            selection.contains(m.deviceName) ||
            selection.contains(m.id),
      )
      .toList();
  String baseName(MonitorInfo monitor) => monitor.friendlyName.trim().isNotEmpty
      ? monitor.friendlyName
      : monitor.name.trim().isNotEmpty
      ? monitor.name
      : monitor.deviceName;
  final nameCounts = <String, int>{};
  for (final monitor in selected) {
    nameCounts.update(
      baseName(monitor),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  final settings = ref.watch(settingsProvider).value ?? {};
  final temperatures = ref.watch(temperatureSettingsProvider).value ?? {};
  final offsets = ref.watch(brightnessOffsetsProvider);
  final global = settings['all'] ?? SettingsState();
  final brightness = <MonitorRegulationEntry<BrightnessTarget>>[];
  final temperature = <MonitorRegulationEntry<TemperatureTarget>>[];
  for (final monitor in selected) {
    final id = monitor.deviceName;
    final config = settings[id] ?? global;
    final name = nameCounts[baseName(monitor)]! > 1
        ? '${baseName(monitor)} ($id)'
        : baseName(monitor);
    final temp = temperatures[id] ?? temperatures['all'] ?? TemperatureState();
    final brightTarget = ref.watch(brightnessTargetProvider(id));
    final tempTarget = ref.watch(temperatureTargetProvider(id));
    final offset = offsets[id] ?? 0;
    final minimum = brightTarget?.isManual == true
        ? MonitorInfo.effectiveMinBrightness(
            isOverlayOnly: !monitor.isDdcSupported,
            isSoftwareDimmingEnabled: global.isSoftwareDimmingEnabled,
          )
        : 0.0;
    final b = brightTarget?.data;
    final t = tempTarget?.data;
    final automaticBright =
        brightTarget != null &&
        [
          BrightnessSource.solarPhases,
          BrightnessSource.curve,
          BrightnessSource.appCurve,
        ].contains(brightTarget.source);
    final automaticTemp =
        tempTarget != null &&
        [
          TemperatureSource.solarPhases,
          TemperatureSource.curve,
          TemperatureSource.appCurve,
        ].contains(tempTarget.source);
    final brightnessCurve =
        brightTarget?.source == BrightnessSource.curve ||
        brightTarget?.source == BrightnessSource.appCurve;
    final temperatureCurve =
        tempTarget?.source == TemperatureSource.curve ||
        tempTarget?.source == TemperatureSource.appCurve;
    brightness.add(
      MonitorRegulationEntry(
        id: id,
        name: name,
        target: brightTarget,
        appliedValue: monitor.realBrightness?.toDouble(),
        offset: offset,
        minimum: minimum,
        signature: [
          brightTarget?.source,
          if (brightnessCurve) ...[
            brightTarget?.systemPreset,
            brightTarget?.userPresetName,
          ],
          brightTarget?.applicationName,
          if (brightTarget?.source == BrightnessSource.solarPhases)
            b?.basePhase,
          b?.baseBrightness,
          b?.finalBrightness,
          b?.elevationShiftBrightnessImpact,
          b?.weatherAbsoluteImpact,
          b?.windDownAbsoluteImpact,
          b?.sleepPressureAbsoluteImpact,
          b?.sleepDebtAbsoluteImpact,
          b?.timeShiftBrightnessImpact,
          b?.brightnessLimitImpact,
          b?.brightnessMultiplier,
          b?.windDownFactor,
          b?.sleepPressureFactor,
          b?.sleepDebtFactor,
          b?.timeShiftFactor,
          b?.isWindDownActive,
          b?.isTimeShiftActive,
          b?.isSleepPressureActive,
          b?.isSleepDebtActive,
          b?.timeShiftMinutesRemaining,
          b?.windDownMinutesRemaining,
          b?.minutesUntilWakeUp,
          b?.weatherCode,
          offset,
          minimum,
          if (automaticBright) ...[
            config.isWeatherAdjustmentEnabled,
            if (config.isWeatherAdjustmentEnabled) ...[
              config.weatherAdjustmentIntensity,
              brightTarget.source == BrightnessSource.appCurve &&
                      brightTarget.systemPreset != null
                  ? brightTarget.systemPreset!.weatherSensitivity
                  : config.activePreset.weatherSensitivity,
            ],
            _sleepControls(config, temperature: false),
          ],
        ],
      ),
    );
    temperature.add(
      MonitorRegulationEntry(
        id: id,
        name: name,
        target: tempTarget,
        appliedValue: monitor.realTemperature?.toDouble(),
        signature: [
          tempTarget?.source,
          if (temperatureCurve) ...[
            tempTarget?.systemPreset,
            tempTarget?.userPresetName,
          ],
          tempTarget?.applicationName,
          if (tempTarget?.source == TemperatureSource.solarPhases) t?.basePhase,
          t?.baseTemperature,
          t?.finalTemperature,
          t?.weatherTemperatureImpact,
          t?.windDownTemperatureImpact,
          t?.sleepPressureTemperatureImpact,
          t?.sleepDebtTemperatureImpact,
          t?.timeShiftTemperatureImpact,
          t?.temperatureLimitImpact,
          t?.temperatureRoundingImpact,
          t?.isWindDownActive,
          t?.isTimeShiftActive,
          t?.isSleepPressureActive,
          t?.isSleepDebtActive,
          t?.timeShiftFactor,
          t?.timeShiftTemperatureIntensity,
          t?.timeShiftMinutesRemaining,
          t?.weatherCode,
          if (automaticTemp) ...[
            config.isWeatherTemperatureAdjustmentEnabled,
            if (config.isWeatherTemperatureAdjustmentEnabled)
              config.weatherAdjustmentIntensity,
            _sleepControls(config, temperature: true, temp: temp),
          ],
        ],
      ),
    );
  }
  return RegulationBreakdownSelection(
    brightness: groupRegulations(brightness),
    temperature: groupRegulations(temperature),
    selectedCount: selected.length,
    allSelected: selected.isNotEmpty && selected.length == monitors.length,
  );
});
