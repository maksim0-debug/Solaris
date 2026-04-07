import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solaris/env/env.dart';
import 'package:solaris/models/settings_state.dart';

class WeatherData {
  final double temperature;
  final double humidity;
  final double uvIndex;
  final double directRadiation;
  final double diffuseRadiation;
  final double cloudCover;
  final double windSpeed;
  final int weatherCode; // WMO weather code
  final DateTime lastUpdated;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.uvIndex,
    required this.directRadiation,
    required this.diffuseRadiation,
    required this.cloudCover,
    required this.windSpeed,
    required this.weatherCode,
    required this.lastUpdated,
  });
}

class WeatherService {
  Future<WeatherData?> fetchCurrentWeather(
    double lat,
    double lon, {
    WeatherProvider provider = WeatherProvider.auto,
  }) async {
    final apiKey = Env.weatherApiKey;

    // --- FORCED PROVIDER LOGIC ---
    if (provider == WeatherProvider.weatherApi) {
      if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY') {
        print('WeatherService: WeatherAPI requested but key is missing.');
        return null;
      }
      try {
        return await _fetchWeatherApi(lat, lon);
      } catch (e) {
        print('WeatherService: Forced WeatherAPI failed: $e');
        return null;
      }
    }

    if (provider == WeatherProvider.openMeteo) {
      try {
        return await _fetchOpenMeteo(lat, lon);
      } catch (e) {
        print('WeatherService: Forced Open-Meteo failed: $e');
        return null;
      }
    }

    // --- AUTO / FALLBACK LOGIC ---
    // PLAN A: Try WeatherAPI if key is available
    if (apiKey.isNotEmpty && apiKey != 'YOUR_API_KEY') {
      try {
        print('WeatherService: Attempting WeatherAPI (Primary)...');
        final data = await _fetchWeatherApi(lat, lon);
        print('WeatherService: WeatherAPI success.');
        return data;
      } catch (e) {
        print('WeatherService: WeatherAPI failed: $e');
      }
    } else {
      print(
        'WeatherService: WeatherAPI key is missing or invalid. Skipping Plan A...',
      );
    }

    // PLAN B: Fallback to Open-Meteo
    try {
      print('WeatherService: Attempting Open-Meteo (Fallback)...');
      final data = await _fetchOpenMeteo(lat, lon);
      print('WeatherService: Open-Meteo success.');
      return data;
    } catch (e) {
      print(
        'WeatherService: Open-Meteo failed: $e. Both services unavailable.',
      );
      return null;
    }
  }

  // --- OPEN-METEO ---
  Future<WeatherData> _fetchOpenMeteo(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,uv_index,direct_radiation,diffuse_radiation,cloud_cover,wind_speed_10m,weather_code',
    );

    final response = await http
        .get(url)
        .timeout(const Duration(seconds: 5)); // 5 sec timeout to switch quickly

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final current = data['current'];

      return WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toDouble(),
        uvIndex: (current['uv_index'] as num).toDouble(),
        directRadiation: (current['direct_radiation'] as num).toDouble(),
        diffuseRadiation: (current['diffuse_radiation'] as num).toDouble(),
        cloudCover: (current['cloud_cover'] as num).toDouble(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        lastUpdated: DateTime.parse(current['time'] as String),
      );
    } else {
      throw Exception('Open-Meteo returned code ${response.statusCode}');
    }
  }

  // --- WEATHER API ---
  Future<WeatherData> _fetchWeatherApi(double lat, double lon) async {
    final apiKey = Env.weatherApiKey;
    final url = Uri.parse(
      'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$lat,$lon&aqi=no',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final current = data['current'];

      final double uv = (current['uv'] as num).toDouble();
      final double cloud = (current['cloud'] as num).toDouble();
      final int weatherApiCode = (current['condition']['code'] as num).toInt();

      // Extract radiation data if available
      // short_rad is Global Horizontal Irradiance (GHI) - ground level total
      // diff_rad is Diffuse Horizontal Irradiance (DHI)
      // dni is Direct Normal Irradiance (Beam perpendicular to sun)
      final double? shortRad =
          current['short_rad'] != null
              ? (current['short_rad'] as num).toDouble()
              : null;
      final double? diffRad =
          current['diff_rad'] != null
              ? (current['diff_rad'] as num).toDouble()
              : null;
      final double? dni =
          current['dni'] != null ? (current['dni'] as num).toDouble() : null;

      double directRad;
      double diffuseRad;

      if (shortRad != null && diffRad != null) {
        print(
          'WeatherService: Using real radiation from WeatherAPI (ShortRad/DiffRad).',
        );
        diffuseRad = diffRad;
        // Direct Horizontal = Global Horizontal - Diffuse Horizontal
        directRad = (shortRad - diffRad).clamp(0.0, double.infinity);
      } else if (dni != null && diffRad != null) {
        print(
          'WeatherService: Using DNI/DiffRad from WeatherAPI (Caution: may overstate ground intensity).',
        );
        directRad = dni;
        diffuseRad = diffRad;
      } else {
        print(
          'WeatherService: Radiation fields missing in WeatherAPI response. Falling back to heuristics.',
        );
        // Heuristic radiation calculation
        // Approx: UV index * 80 gives peak radiation, reduced by cloud cover
        final double estimatedTotalRadiation =
            (uv * 80.0) * (1.0 - (cloud / 100.0) * 0.5);
        directRad = estimatedTotalRadiation * 0.8;
        diffuseRad = estimatedTotalRadiation * 0.2;
      }

      final int lastUpdatedEpoch =
          (current['last_updated_epoch'] as num).toInt();

      return WeatherData(
        temperature: (current['temp_c'] as num).toDouble(),
        humidity: (current['humidity'] as num).toDouble(),
        uvIndex: uv,
        directRadiation: directRad,
        diffuseRadiation: diffuseRad,
        cloudCover: cloud,
        windSpeed: (current['wind_kph'] as num).toDouble(),
        weatherCode: _mapWeatherApiToWMO(weatherApiCode), // Convert code
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(lastUpdatedEpoch * 1000),
      );
    } else {
      throw Exception('WeatherAPI returned code ${response.statusCode}');
    }
  }

  // WeatherAPI to WMO (Open-Meteo) code converter
  int _mapWeatherApiToWMO(int weatherApiCode) {
    switch (weatherApiCode) {
      case 1000:
        return 0; // Clear
      case 1003:
        return 2; // Partly cloudy
      case 1006:
        return 3; // Cloudy
      case 1009:
        return 3; // Overcast
      case 1030:
        return 45; // Mist
      case 1063:
        return 3; // Patchy rain possible (mapped to Overcast to avoid false rain)
      case 1066:
        return 3; // Patchy snow possible (mapped to Overcast)
      case 1069:
        return 3; // Patchy sleet possible (mapped to Overcast)
      case 1072:
        return 3; // Patchy freezing drizzle possible (mapped to Overcast)
      case 1087:
        return 3; // Thundery outbreaks possible (mapped to Overcast)
      case 1114:
        return 71; // Blowing snow
      case 1117:
        return 73; // Blizzard
      case 1135:
        return 48; // Fog
      case 1148:
        return 48; // Freezing fog
      case 1150:
        return 51; // Patchy light drizzle
      case 1153:
        return 53; // Light drizzle
      case 1168:
        return 56; // Freezing drizzle
      case 1171:
        return 57; // Heavy freezing drizzle
      case 1180:
        return 61; // Patchy light rain
      case 1183:
        return 61; // Light rain
      case 1186:
        return 63; // Moderate rain at times
      case 1189:
        return 63; // Moderate rain
      case 1192:
        return 65; // Heavy rain at times
      case 1195:
        return 65; // Heavy rain
      case 1198:
        return 66; // Light freezing rain
      case 1201:
        return 67; // Moderate or heavy freezing rain
      case 1204:
        return 71; // Light sleet
      case 1207:
        return 73; // Moderate or heavy sleet
      case 1210:
        return 71; // Patchy light snow
      case 1213:
        return 71; // Light snow
      case 1216:
        return 73; // Patchy moderate snow
      case 1219:
        return 73; // Moderate snow
      case 1222:
        return 75; // Patchy heavy snow
      case 1225:
        return 75; // Heavy snow
      case 1237:
        return 77; // Ice pellets
      case 1240:
        return 80; // Light rain shower
      case 1243:
        return 81; // Moderate or heavy rain shower
      case 1246:
        return 82; // Torrential rain shower
      case 1249:
        return 85; // Light sleet showers
      case 1252:
        return 86; // Moderate or heavy sleet showers
      case 1255:
        return 85; // Light snow showers
      case 1258:
        return 86; // Moderate or heavy snow showers
      case 1261:
        return 87; // Light showers of ice pellets
      case 1264:
        return 88; // Moderate or heavy showers of ice pellets
      case 1273:
        return 95; // Patchy light rain with thunder
      case 1276:
        return 97; // Moderate or heavy rain with thunder
      case 1279:
        return 95; // Patchy light snow with thunder
      case 1282:
        return 99; // Moderate or heavy snow with thunder
      default:
        return 0; // Default: clear
    }
  }
}
