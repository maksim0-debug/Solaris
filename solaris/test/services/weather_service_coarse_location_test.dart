import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/weather_service.dart';

void main() {
  group('WeatherService Coarse Location Privacy Tests', () {
    test('roundCoordinateTo2Decimals correctly rounds latitude and longitude', () {
      expect(WeatherService.roundCoordinateTo2Decimals(50.45012345), equals(50.45));
      expect(WeatherService.roundCoordinateTo2Decimals(30.52345678), equals(30.52));
      expect(WeatherService.roundCoordinateTo2Decimals(50.456), equals(50.46));
      expect(WeatherService.roundCoordinateTo2Decimals(-25.1234), equals(-25.12));
      expect(WeatherService.roundCoordinateTo2Decimals(-25.1289), equals(-25.13));
      expect(WeatherService.roundCoordinateTo2Decimals(0.0), equals(0.0));
    });
  });
}
