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

class CitySearchResult {
  final String name;
  final String fullAddress;
  final double latitude;
  final double longitude;

  const CitySearchResult({
    required this.name,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CitySearchResult &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fullAddress == other.fullAddress &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode =>
      name.hashCode ^
      fullAddress.hashCode ^
      latitude.hashCode ^
      longitude.hashCode;

  @override
  String toString() =>
      'CitySearchResult(name: $name, fullAddress: $fullAddress, latitude: $latitude, longitude: $longitude)';
}

class GeocodingService {
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Searches for cities/places matching [query] using Mapbox Forward Geocoding API.
  Future<List<CitySearchResult>> searchPlaces(
    String query, {
    String? language,
    String? customToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final token = (customToken != null && customToken.isNotEmpty)
        ? customToken
        : Env.mapboxToken;
    final bool hasToken =
        token.isNotEmpty && !token.contains('your_mapbox_token_here');

    if (!hasToken) return [];

    try {
      final lang = language ?? Platform.localeName.split('_').first;
      final encodedQuery = Uri.encodeComponent(trimmed);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=$token'
        '&types=place,locality'
        '&limit=5'
        '&language=$lang',
      );

      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null) {
          final results = <CitySearchResult>[];
          for (final feature in features) {
            final text = feature['text'] as String?;
            final placeName = feature['place_name'] as String?;
            final center = feature['center'] as List?;
            if (text != null &&
                center != null &&
                center.length >= 2 &&
                center[0] is num &&
                center[1] is num) {
              final lon = (center[0] as num).toDouble();
              final lat = (center[1] as num).toDouble();
              results.add(
                CitySearchResult(
                  name: text,
                  fullAddress: placeName ?? text,
                  latitude: lat,
                  longitude: lon,
                ),
              );
            }
          }
          return results;
        }
      }
    } catch (e) {
      print('GeocodingService: Mapbox Forward Geocoding search failed: $e');
    }

    return [];
  }

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
