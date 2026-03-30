import 'package:equatable/equatable.dart';

class LocationSettings extends Equatable {
  final bool useManual;
  final double? manualLatitude;
  final double? manualLongitude;
  final String? lastCityName;

  const LocationSettings({
    this.useManual = false,
    this.manualLatitude,
    this.manualLongitude,
    this.lastCityName,
  });

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    return LocationSettings(
      useManual: json['useManual'] as bool? ?? false,
      manualLatitude: (json['manualLatitude'] as num?)?.toDouble(),
      manualLongitude: (json['manualLongitude'] as num?)?.toDouble(),
      lastCityName: json['lastCityName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'useManual': useManual,
      'manualLatitude': manualLatitude,
      'manualLongitude': manualLongitude,
      'lastCityName': lastCityName,
    };
  }

  LocationSettings copyWith({
    bool? useManual,
    double? manualLatitude,
    double? manualLongitude,
    String? lastCityName,
  }) {
    return LocationSettings(
      useManual: useManual ?? this.useManual,
      manualLatitude: manualLatitude ?? this.manualLatitude,
      manualLongitude: manualLongitude ?? this.manualLongitude,
      lastCityName: lastCityName ?? this.lastCityName,
    );
  }

  @override
  List<Object?> get props => [
    useManual,
    manualLatitude,
    manualLongitude,
    lastCityName,
  ];
}
