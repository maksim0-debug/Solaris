enum AppOverrideMode {
  global,
  fixed,
  curve;

  String toJson() => name;

  factory AppOverrideMode.fromJson(String json) {
    final cleaned = json.trim().toLowerCase();
    return AppOverrideMode.values.firstWhere(
      (e) => e.name.toLowerCase() == cleaned,
      orElse: () => AppOverrideMode.global,
    );
  }
}

class AppOverrideRule {
  final String exeName;
  final String appDisplayName;
  final bool isEnabled;
  final bool isBuiltIn;

  final AppOverrideMode brightnessMode;
  final double? fixedBrightness;
  final String? brightnessCurvePresetId;

  final AppOverrideMode temperatureMode;
  final double? fixedTemperature;
  final String? temperatureCurvePresetId;

  const AppOverrideRule({
    required this.exeName,
    required this.appDisplayName,
    this.isEnabled = true,
    this.isBuiltIn = false,
    this.brightnessMode = AppOverrideMode.global,
    this.fixedBrightness,
    this.brightnessCurvePresetId,
    this.temperatureMode = AppOverrideMode.global,
    this.fixedTemperature,
    this.temperatureCurvePresetId,
  });

  static List<AppOverrideRule> get defaultBuiltInRules => const [
        AppOverrideRule(
          exeName: 'photoshop.exe',
          appDisplayName: 'Adobe Photoshop',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
        AppOverrideRule(
          exeName: 'premiere.exe',
          appDisplayName: 'Adobe Premiere Pro',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
        AppOverrideRule(
          exeName: 'resolve.exe',
          appDisplayName: 'DaVinci Resolve',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
        AppOverrideRule(
          exeName: 'lightroom.exe',
          appDisplayName: 'Adobe Lightroom',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
        AppOverrideRule(
          exeName: 'blender.exe',
          appDisplayName: 'Blender 3D',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
        AppOverrideRule(
          exeName: 'figma.exe',
          appDisplayName: 'Figma Desktop',
          isBuiltIn: true,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: 6500.0,
        ),
      ];

  static String _sanitizeExeName(String raw) {
    var cleaned = raw.trim().toLowerCase();
    if (cleaned.contains('/') || cleaned.contains('\\')) {
      cleaned = cleaned.split(RegExp(r'[/\\]')).last;
    }
    return cleaned;
  }

  static double? _parseBoundedDouble(dynamic value, double min, double max) {
    if (value == null) return null;
    double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value);
    }
    if (parsed == null || !parsed.isFinite) return null;
    return parsed.clamp(min, max);
  }

  Map<String, dynamic> toJson() => {
        'exeName': _sanitizeExeName(exeName),
        'appDisplayName': appDisplayName,
        'isEnabled': isEnabled,
        'isBuiltIn': isBuiltIn,
        'brightnessMode': brightnessMode.toJson(),
        'fixedBrightness': fixedBrightness,
        'brightnessCurvePresetId': brightnessCurvePresetId,
        'temperatureMode': temperatureMode.toJson(),
        'fixedTemperature': fixedTemperature,
        'temperatureCurvePresetId': temperatureCurvePresetId,
      };

  factory AppOverrideRule.fromJson(Map<String, dynamic> json) {
    return AppOverrideRule(
      exeName: _sanitizeExeName(json['exeName']?.toString() ?? ''),
      appDisplayName: json['appDisplayName']?.toString() ?? '',
      isEnabled: json['isEnabled'] is bool ? json['isEnabled'] as bool : true,
      isBuiltIn: json['isBuiltIn'] is bool ? json['isBuiltIn'] as bool : false,
      brightnessMode: json.containsKey('brightnessMode') && json['brightnessMode'] is String
          ? AppOverrideMode.fromJson(json['brightnessMode'] as String)
          : AppOverrideMode.global,
      fixedBrightness: _parseBoundedDouble(json['fixedBrightness'], 0.0, 100.0),
      brightnessCurvePresetId: json['brightnessCurvePresetId']?.toString(),
      temperatureMode: json.containsKey('temperatureMode') && json['temperatureMode'] is String
          ? AppOverrideMode.fromJson(json['temperatureMode'] as String)
          : AppOverrideMode.global,
      fixedTemperature: _parseBoundedDouble(json['fixedTemperature'], 3300.0, 6500.0),
      temperatureCurvePresetId: json['temperatureCurvePresetId']?.toString(),
    );
  }

  AppOverrideRule copyWith({
    String? exeName,
    String? appDisplayName,
    bool? isEnabled,
    bool? isBuiltIn,
    AppOverrideMode? brightnessMode,
    double? fixedBrightness,
    String? brightnessCurvePresetId,
    AppOverrideMode? temperatureMode,
    double? fixedTemperature,
    String? temperatureCurvePresetId,
    bool clearFixedBrightness = false,
    bool clearBrightnessCurvePresetId = false,
    bool clearFixedTemperature = false,
    bool clearTemperatureCurvePresetId = false,
  }) {
    return AppOverrideRule(
      exeName: exeName != null ? _sanitizeExeName(exeName) : this.exeName,
      appDisplayName: appDisplayName ?? this.appDisplayName,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      brightnessMode: brightnessMode ?? this.brightnessMode,
      fixedBrightness: clearFixedBrightness
          ? null
          : (fixedBrightness != null && fixedBrightness.isFinite
              ? fixedBrightness.clamp(0.0, 100.0)
              : this.fixedBrightness),
      brightnessCurvePresetId: clearBrightnessCurvePresetId ? null : (brightnessCurvePresetId ?? this.brightnessCurvePresetId),
      temperatureMode: temperatureMode ?? this.temperatureMode,
      fixedTemperature: clearFixedTemperature
          ? null
          : (fixedTemperature != null && fixedTemperature.isFinite
              ? fixedTemperature.clamp(3300.0, 6500.0)
              : this.fixedTemperature),
      temperatureCurvePresetId: clearTemperatureCurvePresetId ? null : (temperatureCurvePresetId ?? this.temperatureCurvePresetId),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppOverrideRule &&
        other.exeName == exeName &&
        other.appDisplayName == appDisplayName &&
        other.isEnabled == isEnabled &&
        other.isBuiltIn == isBuiltIn &&
        other.brightnessMode == brightnessMode &&
        other.fixedBrightness == fixedBrightness &&
        other.brightnessCurvePresetId == brightnessCurvePresetId &&
        other.temperatureMode == temperatureMode &&
        other.fixedTemperature == fixedTemperature &&
        other.temperatureCurvePresetId == temperatureCurvePresetId;
  }

  @override
  int get hashCode {
    return Object.hash(
      exeName,
      appDisplayName,
      isEnabled,
      isBuiltIn,
      brightnessMode,
      fixedBrightness,
      brightnessCurvePresetId,
      temperatureMode,
      fixedTemperature,
      temperatureCurvePresetId,
    );
  }
}
