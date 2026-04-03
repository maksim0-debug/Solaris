import 'package:equatable/equatable.dart';

class MapHealthReport extends Equatable {
  final bool isTokenValid;
  final bool isInternetAvailable;
  final bool isVCRedistInstalled;
  final bool isMapboxReachable;

  const MapHealthReport({
    required this.isTokenValid,
    required this.isInternetAvailable,
    required this.isVCRedistInstalled,
    required this.isMapboxReachable,
  });

  bool get hasIssues =>
      !isTokenValid || !isInternetAvailable || !isVCRedistInstalled || !isMapboxReachable;

  @override
  List<Object?> get props => [
    isTokenValid,
    isInternetAvailable,
    isVCRedistInstalled,
    isMapboxReachable,
  ];

  MapHealthReport copyWith({
    bool? isTokenValid,
    bool? isInternetAvailable,
    bool? isVCRedistInstalled,
    bool? isMapboxReachable,
  }) {
    return MapHealthReport(
      isTokenValid: isTokenValid ?? this.isTokenValid,
      isInternetAvailable: isInternetAvailable ?? this.isInternetAvailable,
      isVCRedistInstalled: isVCRedistInstalled ?? this.isVCRedistInstalled,
      isMapboxReachable: isMapboxReachable ?? this.isMapboxReachable,
    );
  }
}
