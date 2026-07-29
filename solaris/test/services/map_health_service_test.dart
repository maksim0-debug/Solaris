import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/services/map_health_service.dart';

void main() {
  group('MapHealthService Tests', () {
    test('Invalid custom token format returns isTokenValid false', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = MapHealthService(client: mockClient);
      final report = await service.getHealthReport(
        customToken: 'invalid_token',
      );

      expect(report.isTokenValid, isFalse);
    });

    test(
      'Valid custom token format and reachable Mapbox returns true for token and reachability',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.queryParameters['access_token'],
            equals('pk.valid_mock_token'),
          );
          return http.Response(json.encode({'status': 'ok'}), 200);
        });

        final service = MapHealthService(client: mockClient);
        final report = await service.getHealthReport(
          customToken: 'pk.valid_mock_token',
        );

        expect(report.isTokenValid, isTrue);
        expect(report.isMapboxReachable, isTrue);
        expect(report.errorDetails, null);
      },
    );

    test(
      'Valid custom token format but unreachable Mapbox due to server error returns reachable false',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.queryParameters['access_token'],
            equals('sk.valid_mock_token'),
          );
          return http.Response('Internal Server Error', 500);
        });

        final service = MapHealthService(client: mockClient);
        final report = await service.getHealthReport(
          customToken: 'sk.valid_mock_token',
        );

        expect(report.isTokenValid, isTrue);
        expect(report.isMapboxReachable, isFalse);
        expect(report.errorDetails, equals('HTTP 500'));
      },
    );
  });
}
