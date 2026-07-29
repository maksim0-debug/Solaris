import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:solaris/env/env.dart';

enum OfflineReason { missingToken, apiError }

class GeocodingResult {
  final String name;
  final bool isOffline;
  final OfflineReason? offlineReason;
  final bool isCachedCity;

  const GeocodingResult({
    required this.name,
    required this.isOffline,
    this.offlineReason,
    this.isCachedCity = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeocodingResult &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          isOffline == other.isOffline &&
          offlineReason == other.offlineReason &&
          isCachedCity == other.isCachedCity;

  @override
  int get hashCode =>
      name.hashCode ^
      isOffline.hashCode ^
      offlineReason.hashCode ^
      isCachedCity.hashCode;

  @override
  String toString() =>
      'GeocodingResult(name: $name, isOffline: $isOffline, offlineReason: $offlineReason, isCachedCity: $isCachedCity)';
}

class GeocodingService {
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Resolves the city name for the given coordinates.
  ///
  /// First, it attempts to fetch the city using Mapbox Geocoding API.
  /// If it fails (offline, bad token, error), it falls back to extracting
  /// the city from the timezone identifier using the offline `lat_lng_to_timezone` library.
  Future<GeocodingResult> getCityName(
    double latitude,
    double longitude, {
    String? language,
    String? customToken,
  }) async {
    // 1. Try Mapbox Geocoding API if token is valid
    final token = (customToken != null && customToken.isNotEmpty)
        ? customToken
        : Env.mapboxToken;
    final bool hasToken =
        token.isNotEmpty && !token.contains('your_mapbox_token_here');

    if (hasToken) {
      try {
        final lang = language ?? Platform.localeName.split('_').first;
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json'
          '?access_token=$token'
          '&types=place'
          '&limit=1'
          '&language=$lang',
        );

        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final place = features.first;
            final text = place['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return GeocodingResult(name: text, isOffline: false);
            }
          }
        }
        return _getOfflineFallback(latitude, longitude, OfflineReason.apiError);
      } catch (e) {
        // Fallback to offline timezone-based extraction
        print('GeocodingService: Mapbox Geocoding failed: $e');
        return _getOfflineFallback(latitude, longitude, OfflineReason.apiError);
      }
    }

    return _getOfflineFallback(latitude, longitude, OfflineReason.missingToken);
  }

  GeocodingResult _getOfflineFallback(
    double latitude,
    double longitude,
    OfflineReason reason,
  ) {
    try {
      var tzName = tzmap.latLngToTimezoneString(latitude, longitude);
      if (tzName == 'Europe/Kiev') {
        tzName = 'Europe/Kyiv';
      }
      return GeocodingResult(
        name: tzName,
        isOffline: true,
        offlineReason: reason,
      );
    } catch (e) {
      print('GeocodingService: Timezone-based extraction failed: $e');
    }

    return GeocodingResult(
      name: "Global Coordinates",
      isOffline: true,
      offlineReason: reason,
    );
  }
}
