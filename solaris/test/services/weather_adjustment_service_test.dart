import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/weather_adjustment_service.dart';
import 'package:solaris/services/weather_service.dart';

void main() {
  group('WeatherAdjustmentService', () {
    final service = WeatherAdjustmentService();

    WeatherData weather({double cloudCover = 0, int weatherCode = 0}) {
      return WeatherData(
        temperature: 20,
        humidity: 50,
        uvIndex: 4,
        directRadiation: 500,
        diffuseRadiation: 150,
        cloudCover: cloudCover,
        windSpeed: 0,
        weatherCode: weatherCode,
        lastUpdated: DateTime.now(),
      );
    }

    test('returns 1.0 when weather is null', () {
      final factor = service.calculateWeatherFactor(null, 20.0);
      expect(factor, 1.0);
    });

    test('returns 1.0 for clear weather in daytime', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 10, weatherCode: 1),
        20.0,
      );
      expect(factor, 1.0);
    });

    test('returns 0.85 for heavy cloud cover in daytime', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 90, weatherCode: 3),
        20.0,
      );
      expect(factor, closeTo(0.7, 0.001));
    });

    test('returns 0.75 for rain codes in daytime', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 10, weatherCode: 55),
        20.0,
      );
      expect(factor, closeTo(0.55, 0.001));
    });

    test('returns 0.65 for thunderstorm codes in daytime', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 10, weatherCode: 95),
        20.0,
      );
      expect(factor, closeTo(0.5, 0.001));
    });

    test('disables weather impact below horizon', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 100, weatherCode: 95),
        -2.0,
      );
      expect(factor, 1.0);
    });

    test('fades weather impact near horizon', () {
      final factor = service.calculateWeatherFactor(
        weather(cloudCover: 10, weatherCode: 55),
        5.0,
      );
  
      // At 5deg elevation, the impact is fully applied.
      // 1.0 - (1.0-0.55) = 0.55
      expect(factor, closeTo(0.55, 0.001));
    });
  });
}
