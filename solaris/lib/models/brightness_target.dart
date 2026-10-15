import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';

enum BrightnessSource { solarPhases, curve, appFixed, appCurve, game, manual }

/// A resolved per-monitor target, before the monitor offset and hardware rounding.
/// The same snapshot supplies automatic control and its explanation.
class BrightnessTarget {
  const BrightnessTarget({
    required this.source,
    required this.data,
    this.systemPreset,
    this.userPresetName,
    this.applicationName,
  });

  final BrightnessSource source;
  final SmartCircadianData data;
  final PresetType? systemPreset;
  final String? userPresetName;
  final String? applicationName;

  double get value => data.finalBrightness!;
  bool get isManual => source == BrightnessSource.manual;
}
