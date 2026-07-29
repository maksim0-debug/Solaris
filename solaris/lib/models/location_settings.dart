import 'package:equatable/equatable.dart';

class LocationSettings extends Equatable {
  final bool useManual;
  final double? manualLatitude;
  final double? manualLongitude;
  final String? lastCityName;
  final double? lastResolvedLatitude;
  final double? lastResolvedLongitude;

  const LocationSettings({
    this.useManual = false,
    this.manualLatitude,
    this.manualLongitude,
    this.lastCityName,
    this.lastResolvedLatitude,
    this.lastResolvedLongitude,
  });

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    final lat = (json['manualLatitude'] as num?)?.toDouble();
    final lon = (json['manualLongitude'] as num?)?.toDouble();
    final resolvedLat = (json['lastResolvedLatitude'] as num?)?.toDouble();
    final resolvedLon = (json['lastResolvedLongitude'] as num?)?.toDouble();

    return LocationSettings(
      useManual: json['useManual'] as bool? ?? false,
      manualLatitude: lat != null ? lat.clamp(-90.0, 90.0) : null,
      manualLongitude: lon != null ? lon.clamp(-180.0, 180.0) : null,
      lastCityName: json['lastCityName'] as String?,
      lastResolvedLatitude: resolvedLat != null
          ? resolvedLat.clamp(-90.0, 90.0)
          : null,
      lastResolvedLongitude: resolvedLon != null
          ? resolvedLon.clamp(-180.0, 180.0)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'useManual': useManual,
      'manualLatitude': manualLatitude,
      'manualLongitude': manualLongitude,
      'lastCityName': lastCityName,
      'lastResolvedLatitude': lastResolvedLatitude,
      'lastResolvedLongitude': lastResolvedLongitude,
    };
  }

  LocationSettings copyWith({
    bool? useManual,
    double? manualLatitude,
    double? manualLongitude,
    String? lastCityName,
    double? lastResolvedLatitude,
    double? lastResolvedLongitude,
  }) {
    return LocationSettings(
      useManual: useManual ?? this.useManual,
      manualLatitude: manualLatitude != null
          ? manualLatitude.clamp(-90.0, 90.0)
          : this.manualLatitude,
      manualLongitude: manualLongitude != null
          ? manualLongitude.clamp(-180.0, 180.0)
          : this.manualLongitude,
      lastCityName: lastCityName ?? this.lastCityName,
      lastResolvedLatitude: lastResolvedLatitude != null
          ? lastResolvedLatitude.clamp(-90.0, 90.0)
          : this.lastResolvedLatitude,
      lastResolvedLongitude: lastResolvedLongitude != null
          ? lastResolvedLongitude.clamp(-180.0, 180.0)
          : this.lastResolvedLongitude,
    );
  }

  @override
  List<Object?> get props => [
    useManual,
    manualLatitude,
    manualLongitude,
    lastCityName,
    lastResolvedLatitude,
    lastResolvedLongitude,
  ];
}
