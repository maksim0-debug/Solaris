import 'package:equatable/equatable.dart';

class MapHealthReport extends Equatable {
  final bool isTokenValid;
  final bool isInternetAvailable;
  final bool isVCRedistInstalled;
  final bool isMapboxReachable;

  final String? errorDetails;

  const MapHealthReport({
    required this.isTokenValid,
    required this.isInternetAvailable,
    required this.isVCRedistInstalled,
    required this.isMapboxReachable,
    this.errorDetails,
  });

  bool get hasIssues =>
      !isTokenValid || !isInternetAvailable || !isVCRedistInstalled || !isMapboxReachable;

  @override
  List<Object?> get props => [
    isTokenValid,
    isInternetAvailable,
    isVCRedistInstalled,
    isMapboxReachable,
    errorDetails,
  ];

  MapHealthReport copyWith({
    bool? isTokenValid,
    bool? isInternetAvailable,
    bool? isVCRedistInstalled,
    bool? isMapboxReachable,
    String? errorDetails,
  }) {
    return MapHealthReport(
      isTokenValid: isTokenValid ?? this.isTokenValid,
      isInternetAvailable: isInternetAvailable ?? this.isInternetAvailable,
      isVCRedistInstalled: isVCRedistInstalled ?? this.isVCRedistInstalled,
      isMapboxReachable: isMapboxReachable ?? this.isMapboxReachable,
      errorDetails: errorDetails ?? this.errorDetails,
    );
  }
}
