import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';

enum TemperatureSource {
  solarPhases,
  curve,
  appFixed,
  appCurve,
  game,
  manual,
  disabled,
}

class TemperatureTarget {
  const TemperatureTarget({
    required this.source,
    required this.data,
    this.systemPreset,
    this.userPresetName,
    this.applicationName,
  });

  final TemperatureSource source;
  final SmartCircadianData data;
  final TemperaturePresetType? systemPreset;
  final String? userPresetName;
  final String? applicationName;

  int get value => data.finalTemperature;
  bool get isManual => source == TemperatureSource.manual;
  bool get isDisabled => source == TemperatureSource.disabled;
}
