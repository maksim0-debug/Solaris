import 'package:equatable/equatable.dart';

class RegimeSettings extends Equatable {
  final int toleranceWindow; // min from anchor
  final int maxSpread; // min between min and max within regime
  final int maxAnomalies; // consecutive anomalies before break
  final int minRegimeLength; // min days to be a regime
  final int anchorSize; // num days to form anchor
  final int floatingThreshold; // avg daily delta to be "floating"
  final int mergeThresholdMinutes; // min gap between sessions to merge
  final int recencyTolerance; // minutes difference from latest to be "outdated"

  const RegimeSettings({
    this.toleranceWindow = 75,
    this.maxSpread = 105,
    this.maxAnomalies = 2,
    this.minRegimeLength = 2,
    this.anchorSize = 2,
    this.floatingThreshold = 45,
    this.mergeThresholdMinutes = 210, // 3.5 hours
    int? recencyTolerance,
  }) : recencyTolerance = recencyTolerance ?? toleranceWindow;

  @override
  List<Object?> get props => [
    toleranceWindow,
    maxSpread,
    maxAnomalies,
    minRegimeLength,
    anchorSize,
    floatingThreshold,
    mergeThresholdMinutes,
    recencyTolerance,
  ];
}
