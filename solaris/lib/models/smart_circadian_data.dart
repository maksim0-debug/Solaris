import 'package:equatable/equatable.dart';
import 'package:solaris/models/preset_type.dart';

class SmartCircadianData extends Equatable {
  final double brightnessMultiplier;
  final int temperatureOffset;
  final Duration timeOffset;
  final bool isWindDownActive;
  final bool isSleepPressureActive;
  final bool isSleepDebtActive;
  final bool isTimeShiftActive;
  final double sleepDebtFactor;
  final double sleepPressureFactor;
  final double windDownFactor;
  final double timeShiftFactor;
  final double timeShiftBrightnessImpact;
  final int? timeShiftMinutesRemaining;
  final int? windDownMinutesRemaining;
  final int? minutesUntilSleep;
  final int? minutesUntilWakeUp;
  final int? weatherCode;

  // Absolute Impacts (as percentage points)
  final double baseBrightness;
  final double windDownAbsoluteImpact;
  final double sleepPressureAbsoluteImpact;
  final double sleepDebtAbsoluteImpact;
  final double weatherAbsoluteImpact;

  // Active Preset Information
  final PresetType? activeSystemPreset;
  final String? activeUserPresetName;

  const SmartCircadianData({
    this.brightnessMultiplier = 1.0,
    this.temperatureOffset = 0,
    this.timeOffset = Duration.zero,
    this.isWindDownActive = false,
    this.isSleepPressureActive = false,
    this.isSleepDebtActive = false,
    this.isTimeShiftActive = false,
    this.sleepDebtFactor = 1.0,
    this.sleepPressureFactor = 1.0,
    this.windDownFactor = 1.0,
    this.timeShiftFactor = 0.0,
    this.timeShiftBrightnessImpact = 0.0,
    this.timeShiftMinutesRemaining,
    this.windDownMinutesRemaining,
    this.minutesUntilSleep,
    this.minutesUntilWakeUp,
    this.weatherCode,
    this.baseBrightness = 100.0,
    this.windDownAbsoluteImpact = 0.0,
    this.sleepPressureAbsoluteImpact = 0.0,
    this.sleepDebtAbsoluteImpact = 0.0,
    this.weatherAbsoluteImpact = 0.0,
    this.activeSystemPreset,
    this.activeUserPresetName,
  });

  const SmartCircadianData.neutral()
    : brightnessMultiplier = 1.0,
      temperatureOffset = 0,
      timeOffset = Duration.zero,
      isWindDownActive = false,
      isSleepPressureActive = false,
      isSleepDebtActive = false,
      isTimeShiftActive = false,
      sleepDebtFactor = 1.0,
      sleepPressureFactor = 1.0,
      windDownFactor = 1.0,
      timeShiftFactor = 0.0,
      timeShiftBrightnessImpact = 0.0,
      timeShiftMinutesRemaining = null,
      windDownMinutesRemaining = null,
      minutesUntilSleep = null,
      minutesUntilWakeUp = null,
      weatherCode = null,
      baseBrightness = 100.0,
      windDownAbsoluteImpact = 0.0,
      sleepPressureAbsoluteImpact = 0.0,
      sleepDebtAbsoluteImpact = 0.0,
      weatherAbsoluteImpact = 0.0,
      activeSystemPreset = null,
      activeUserPresetName = null;

  @override
  List<Object?> get props => [
    brightnessMultiplier,
    temperatureOffset,
    timeOffset,
    isWindDownActive,
    isSleepPressureActive,
    isSleepDebtActive,
    isTimeShiftActive,
    sleepDebtFactor,
    sleepPressureFactor,
    windDownFactor,
    timeShiftFactor,
    timeShiftBrightnessImpact,
    timeShiftMinutesRemaining,
    windDownMinutesRemaining,
    minutesUntilSleep,
    minutesUntilWakeUp,
    baseBrightness,
    windDownAbsoluteImpact,
    sleepPressureAbsoluteImpact,
    sleepDebtAbsoluteImpact,
    weatherAbsoluteImpact,
    weatherCode,
    activeSystemPreset,
    activeUserPresetName,
  ];

  SmartCircadianData copyWith({
    double? brightnessMultiplier,
    int? temperatureOffset,
    Duration? timeOffset,
    bool? isWindDownActive,
    bool? isSleepPressureActive,
    bool? isSleepDebtActive,
    bool? isTimeShiftActive,
    double? sleepDebtFactor,
    double? sleepPressureFactor,
    double? windDownFactor,
    double? timeShiftFactor,
    double? timeShiftBrightnessImpact,
    int? timeShiftMinutesRemaining,
    int? windDownMinutesRemaining,
    int? minutesUntilSleep,
    int? minutesUntilWakeUp,
    double? baseBrightness,
    double? windDownAbsoluteImpact,
    double? sleepPressureAbsoluteImpact,
    double? sleepDebtAbsoluteImpact,
    double? weatherAbsoluteImpact,
    int? weatherCode,
    PresetType? activeSystemPreset,
    String? activeUserPresetName,
  }) {
    return SmartCircadianData(
      brightnessMultiplier: brightnessMultiplier ?? this.brightnessMultiplier,
      temperatureOffset: temperatureOffset ?? this.temperatureOffset,
      timeOffset: timeOffset ?? this.timeOffset,
      isWindDownActive: isWindDownActive ?? this.isWindDownActive,
      isSleepPressureActive:
          isSleepPressureActive ?? this.isSleepPressureActive,
      isSleepDebtActive: isSleepDebtActive ?? this.isSleepDebtActive,
      isTimeShiftActive: isTimeShiftActive ?? this.isTimeShiftActive,
      sleepDebtFactor: sleepDebtFactor ?? this.sleepDebtFactor,
      sleepPressureFactor: sleepPressureFactor ?? this.sleepPressureFactor,
      windDownFactor: windDownFactor ?? this.windDownFactor,
      timeShiftFactor: timeShiftFactor ?? this.timeShiftFactor,
      timeShiftBrightnessImpact:
          timeShiftBrightnessImpact ?? this.timeShiftBrightnessImpact,
      timeShiftMinutesRemaining:
          timeShiftMinutesRemaining ?? this.timeShiftMinutesRemaining,
      windDownMinutesRemaining:
          windDownMinutesRemaining ?? this.windDownMinutesRemaining,
      minutesUntilSleep: minutesUntilSleep ?? this.minutesUntilSleep,
      minutesUntilWakeUp: minutesUntilWakeUp ?? this.minutesUntilWakeUp,
      baseBrightness: baseBrightness ?? this.baseBrightness,
      windDownAbsoluteImpact:
          windDownAbsoluteImpact ?? this.windDownAbsoluteImpact,
      sleepPressureAbsoluteImpact:
          sleepPressureAbsoluteImpact ?? this.sleepPressureAbsoluteImpact,
      sleepDebtAbsoluteImpact:
          sleepDebtAbsoluteImpact ?? this.sleepDebtAbsoluteImpact,
      weatherAbsoluteImpact: weatherAbsoluteImpact ?? this.weatherAbsoluteImpact,
      weatherCode: weatherCode ?? this.weatherCode,
      activeSystemPreset: activeSystemPreset ?? this.activeSystemPreset,
      activeUserPresetName: activeUserPresetName ?? this.activeUserPresetName,
    );
  }
}
