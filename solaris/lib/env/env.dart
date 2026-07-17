import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'GOOGLE_CLIENT_ID', optional: true, defaultValue: '')
  static final String googleClientId = _Env.googleClientId;

  @EnviedField(varName: 'MAPBOX_TOKEN', optional: true, defaultValue: '')
  static final String mapboxToken = _Env.mapboxToken;

  @EnviedField(varName: 'WEATHER_API_KEY', optional: true, defaultValue: '')
  static final String weatherApiKey = _Env.weatherApiKey;

  static bool get isWeatherApiKeyValid {
    return weatherApiKey.isNotEmpty &&
        weatherApiKey != 'your_weather_api_key_here' &&
        weatherApiKey != 'YOUR_API_KEY';
  }

  static bool get isMapboxTokenValid {
    return mapboxToken.isNotEmpty &&
        (mapboxToken.startsWith('pk.') || mapboxToken.startsWith('sk.')) &&
        !mapboxToken.contains('your_mapbox_token_here');
  }

  static bool get isGoogleFitKeysValid {
    return googleClientId.isNotEmpty &&
        googleClientId != 'your_client_id_here';
  }
}

