import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature; // Температура воздуха (°C)
  final double humidity; // Влажность (%)

  WeatherData({required this.temperature, required this.humidity});
}

class WeatherService {
  Future<WeatherData?> fetchCurrentWeather(double lat, double lon) async {
    try {
      // Формируем URL. Запрашиваем текущую температуру и влажность.
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];

        return WeatherData(
          temperature: (current['temperature_2m'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toDouble(),
        );
      }
      return null;
    } catch (e) {
      print('Ошибка загрузки погоды: $e');
      return null;
    }
  }
}
