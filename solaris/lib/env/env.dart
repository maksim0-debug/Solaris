import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'GOOGLE_CLIENT_ID')
  static final String googleClientId = _Env.googleClientId;

  @EnviedField(varName: 'GOOGLE_CLIENT_SECRET')
  static final String googleClientSecret = _Env.googleClientSecret;

  @EnviedField(varName: 'MAPBOX_TOKEN')
  static final String mapboxToken = _Env.mapboxToken;
}
