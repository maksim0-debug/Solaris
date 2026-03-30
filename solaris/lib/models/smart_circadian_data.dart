import 'package:equatable/equatable.dart';

class SmartCircadianData extends Equatable {
  final double brightnessMultiplier;
  final int temperatureOffset;
  final Duration timeOffset;
  final bool isWindDownActive;
  final double sleepDebtFactor;
  final double sleepPressureFactor;

  const SmartCircadianData({
    this.brightnessMultiplier = 1.0,
    this.temperatureOffset = 0,
    this.timeOffset = Duration.zero,
    this.isWindDownActive = false,
    this.sleepDebtFactor = 1.0,
    this.sleepPressureFactor = 1.0,
  });

  const SmartCircadianData.neutral()
      : brightnessMultiplier = 1.0,
        temperatureOffset = 0,
        timeOffset = Duration.zero,
        isWindDownActive = false,
        sleepDebtFactor = 1.0,
        sleepPressureFactor = 1.0;

  @override
  List<Object?> get props => [
        brightnessMultiplier,
        temperatureOffset,
        timeOffset,
        isWindDownActive,
        sleepDebtFactor,
        sleepPressureFactor,
      ];
}
