import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/services/geocoding_service.dart';

void main() {
  group('GeocodingService Tests', () {
    test('Successful online geocoding from Mapbox API', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.mapbox.com');
        expect(request.url.path, contains('/geocoding/v5/mapbox.places/30.5238,50.4547.json'));
        
        final mockResponse = {
          'features': [
            {
              'text': 'Kyiv',
              'place_name': 'Kyiv, Ukraine',
            }
          ]
        };
        return http.Response(json.encode(mockResponse), 200);
      });

      final service = GeocodingService(client: mockClient);
      final result = await service.getCityName(50.4547, 30.5238, customToken: 'pk.mock_token');
      expect(result.name, 'Kyiv');
      expect(result.isOffline, false);
    });

    test('Successful online geocoding with custom language', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.mapbox.com');
        expect(request.url.queryParameters['language'], 'en');
        
        final mockResponse = {
          'features': [
            {
              'text': 'Kyiv',
              'place_name': 'Kyiv, Ukraine',
            }
          ]
        };
        return http.Response(json.encode(mockResponse), 200);
      });

      final service = GeocodingService(client: mockClient);
      final result = await service.getCityName(50.4547, 30.5238, language: 'en', customToken: 'pk.mock_token');
      expect(result.name, 'Kyiv');
      expect(result.isOffline, false);
    });

    test('HTTP error falls back to offline timezone-based city', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final service = GeocodingService(client: mockClient);
      // Coordinates of New York: 40.7128, -74.0060
      final result = await service.getCityName(40.7128, -74.0060, customToken: 'pk.mock_token');
      
      // Timezone identifier for NY is America/New_York
      expect(result.name, 'America/New_York');
      expect(result.isOffline, true);
      expect(result.offlineReason, OfflineReason.apiError);
    });

    test('Offline timezone-based city for default Kyiv coordinates', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final service = GeocodingService(client: mockClient);
      // Coordinates of Kyiv: 50.4547, 30.5238
      final result = await service.getCityName(50.4547, 30.5238);
      
      // Timezone is Europe/Kyiv
      expect(result.name, 'Europe/Kyiv');
      expect(result.isOffline, true);
      expect(result.offlineReason, OfflineReason.missingToken);
    });
  });
}
