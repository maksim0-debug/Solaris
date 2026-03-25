import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature; // Температура воздуха (°C)
  final double humidity; // Влажность (%)
  final double uvIndex; // УФ-индекс
  final double directRadiation; // Прямая радиация (W/m²)
  final double diffuseRadiation; // Диффузная радиация (W/m²)

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.uvIndex,
    required this.directRadiation,
    required this.diffuseRadiation,
  });
}

class WeatherService {
  Future<WeatherData?> fetchCurrentWeather(double lat, double lon) async {
    try {
      // Формируем URL. Запрашиваем текущую температуру, влажность, УФ-индекс и радиацию.
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,uv_index,direct_radiation,diffuse_radiation',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];

        return WeatherData(
          temperature: (current['temperature_2m'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toDouble(),
          uvIndex: (current['uv_index'] as num).toDouble(),
          directRadiation: (current['direct_radiation'] as num).toDouble(),
          diffuseRadiation: (current['diffuse_radiation'] as num).toDouble(),
        );
      }
      return null;
    } catch (e) {
      print('Ошибка загрузки погоды: $e');
      return null;
    }
  }
}

