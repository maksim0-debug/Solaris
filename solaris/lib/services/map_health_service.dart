import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:solaris/env/env.dart';
import 'package:solaris/models/map_health_report.dart';

class MapHealthService {
  static const String mapboxApiUrl = 'https://api.mapbox.com';

  Future<MapHealthReport> getHealthReport() async {
    final results = await Future.wait([
      _checkToken(),
      _checkInternet(),
      _checkVCRedistInstalled(),
      _checkMapboxReachable(),
    ]);

    return MapHealthReport(
      isTokenValid: results[0],
      isInternetAvailable: results[1],
      isVCRedistInstalled: results[2],
      isMapboxReachable: results[3],
    );
  }

  Future<bool> _checkToken() async {
    final token = Env.mapboxToken;
    // Mapbox tokens always start with pk. or sk.
    return token.isNotEmpty &&
        (token.startsWith('pk.') || token.startsWith('sk.')) &&
        !token.contains('your_mapbox_token_here');
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkMapboxReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$mapboxApiUrl/tokens/v2?access_token=${Env.mapboxToken}'))
          .timeout(const Duration(seconds: 3));
      // Even a 401/403 means the server is reachable
      return response.statusCode != 404 && response.statusCode != 500;
    } catch (_) {
      return false;
    }
  }

  /// Checks for Visual C++ 2015-2022 Redistributable (msvcp140.dll).
  /// This is required for most Flutter apps on Windows to function correctly.
  Future<bool> _checkVCRedistInstalled() async {
    if (!Platform.isWindows) return true;

    try {
      // Check for the presence of the DLL in System32
      final systemPath = '${Platform.environment['SystemRoot']}\\System32\\msvcp140.dll';
      return await File(systemPath).exists();
    } catch (_) {
      // If we can't check, assume true to avoid false positives in restrictive environments
      return true;
    }
  }
}
