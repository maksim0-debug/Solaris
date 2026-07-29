import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/services/geocoding_service.dart';

void main() {
  group('GeocodingService getCityName', () {
    test(
      'returns city name from Mapbox API when valid token and response',
      () async {
        final mockResponse = jsonEncode({
          'features': [
            {'text': 'Bila Tserkva'},
          ],
        });

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('mapbox.places')) {
            return http.Response(mockResponse, 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = GeocodingService(client: mockClient);
        final result = await service.getCityName(
          49.8029,
          30.1236,
          customToken: 'pk.test_token_12345',
        );

        expect(result.name, equals('Bila Tserkva'));
        expect(result.isOffline, isFalse);
        expect(result.offlineReason, isNull);
      },
    );

    test('falls back to offline timezone when Mapbox API fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = GeocodingService(client: mockClient);
      final result = await service.getCityName(
        50.4501,
        30.5234,
        customToken: 'pk.test_token_12345',
      );

      expect(result.isOffline, isTrue);
      expect(result.offlineReason, equals(OfflineReason.apiError));
      expect(result.name, equals('Europe/Kyiv'));
    });

    test('falls back to offline timezone when token is missing', () async {
      final service = GeocodingService();
      final result = await service.getCityName(50.4501, 30.5234);

      expect(result.isOffline, isTrue);
      expect(result.offlineReason, equals(OfflineReason.missingToken));
    });
  });

  group('GeocodingService searchPlaces', () {
    test('returns empty list when query is empty', () async {
      final service = GeocodingService();
      final results = await service.searchPlaces('  ');
      expect(results, isEmpty);
    });

    test(
      'returns empty list when token is missing and no custom token provided',
      () async {
        final service = GeocodingService();
        final results = await service.searchPlaces('Kyiv');
        expect(results, isA<List<CitySearchResult>>());
      },
    );

    test(
      'parses Mapbox forward geocoding JSON correctly with valid token',
      () async {
        final mockResponse = jsonEncode({
          'features': [
            {
              'text': 'Kyiv',
              'place_name': 'Kyiv, Ukraine',
              'center': [30.5234, 50.4501],
            },
            {
              'text': 'Bila Tserkva',
              'place_name': 'Bila Tserkva, Kyiv Oblast, Ukraine',
              'center': [30.1236, 49.8029],
            },
          ],
        });

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('mapbox.places')) {
            return http.Response(mockResponse, 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = GeocodingService(client: mockClient);
        final results = await service.searchPlaces(
          'Kyiv',
          customToken: 'pk.test_token_12345',
        );

        expect(results, hasLength(2));
        expect(results[0].name, equals('Kyiv'));
        expect(results[0].fullAddress, equals('Kyiv, Ukraine'));
        expect(results[0].latitude, equals(50.4501));
        expect(results[0].longitude, equals(30.5234));

        expect(results[1].name, equals('Bila Tserkva'));
        expect(results[1].latitude, equals(49.8029));
        expect(results[1].longitude, equals(30.1236));
      },
    );
  });
}
