import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:solaris/env/env.dart';

class GeocodingService {
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Resolves the city name for the given coordinates.
  /// 
  /// First, it attempts to fetch the city using Mapbox Geocoding API.
  /// If it fails (offline, bad token, error), it falls back to extracting
  /// the city from the timezone identifier using the offline `lat_lng_to_timezone` library.
  Future<String> getCityName(double latitude, double longitude, {String? language}) async {
    // 1. Try Mapbox Geocoding API if token is valid
    final token = Env.mapboxToken;
    if (token.isNotEmpty && !token.contains('your_mapbox_token_here')) {
      try {
        final lang = language ?? Platform.localeName.split('_').first;
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json'
          '?access_token=$token'
          '&types=place'
          '&limit=1'
          '&language=$lang',
        );

        final response = await _client.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final place = features.first;
            final text = place['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
      } catch (e) {
        // Fallback to offline timezone-based extraction
        print('GeocodingService: Mapbox Geocoding failed: $e');
      }
    }

    // 2. Offline Fallback: Extract from Timezone name
    try {
      final tzName = tzmap.latLngToTimezoneString(latitude, longitude);
      final parts = tzName.split('/');
      if (parts.isNotEmpty) {
        final city = parts.last.replaceAll('_', ' ');
        if (city.isNotEmpty) {
          return city;
        }
      }
    } catch (e) {
      print('GeocodingService: Timezone-based extraction failed: $e');
    }

    return "Global Coordinates";
  }
}
