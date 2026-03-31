import 'package:equatable/equatable.dart';

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
  final double timeShiftBrightnessImpact;
  final int? timeShiftMinutesRemaining;
  final int? windDownMinutesRemaining;
  final int? minutesUntilSleep;
  final int? minutesUntilWakeUp;

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
    this.timeShiftBrightnessImpact = 0.0,
    this.timeShiftMinutesRemaining,
    this.windDownMinutesRemaining,
    this.minutesUntilSleep,
    this.minutesUntilWakeUp,
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
        timeShiftBrightnessImpact = 0.0,
        timeShiftMinutesRemaining = null,
        windDownMinutesRemaining = null,
        minutesUntilSleep = null,
        minutesUntilWakeUp = null;

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
        timeShiftBrightnessImpact,
        timeShiftMinutesRemaining,
        windDownMinutesRemaining,
        minutesUntilSleep,
        minutesUntilWakeUp,
      ];
}

