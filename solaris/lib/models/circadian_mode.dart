enum CircadianMode {
  solarPhases,
  normalizedCurve;

  String toJson() => name;

  factory CircadianMode.fromJson(String? json) {
    if (json == 'legacyDegrees') {
      return CircadianMode.normalizedCurve;
    }
    return CircadianMode.values.firstWhere(
      (e) => e.name == json,
      orElse: () => CircadianMode.solarPhases,
    );
  }
}
