import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:solaris/env/env.dart';
import 'package:solaris/models/map_health_report.dart';

class MapHealthService {
  static const String mapboxApiUrl = 'https://api.mapbox.com';

  Future<MapHealthReport> getHealthReport() async {
    final isTokenValid = await _checkToken();
    final isInternetAvailable = await _checkInternet();
    final isVCRedistInstalled = await _checkVCRedistInstalled();
    final (isMapboxReachable, errorDetails) = await _checkMapboxReachable();

    return MapHealthReport(
      isTokenValid: isTokenValid,
      isInternetAvailable: isInternetAvailable,
      isVCRedistInstalled: isVCRedistInstalled,
      isMapboxReachable: isMapboxReachable,
      errorDetails: errorDetails,
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

  Future<(bool, String?)> _checkMapboxReachable() async {
    try {
      // Use a standard style endpoint for reachability check
      final url = Uri.parse('$mapboxApiUrl/styles/v1/mapbox/streets-v11?access_token=${Env.mapboxToken}');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 || response.statusCode == 401) {
        return (true, null);
      }
      return (false, "HTTP ${response.statusCode}");
    } on SocketException catch (e) {
      return (false, "Network error: ${e.message}");
    } on http.ClientException catch (e) {
      return (false, "Client error: ${e.message}");
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('CERTIFICATE_VERIFY_FAILED')) {
        return (false, "SSL Certificate Error (Clean Windows 10?)");
      }
      return (false, errorStr);
    }
  }

  /// Checks for Visual C++ 2015-2022 Redistributable (msvcp140.dll).
  /// This is required for most Flutter apps on Windows to function correctly.
  Future<bool> _checkVCRedistInstalled() async {
    if (!Platform.isWindows) return true;

    try {
      final sysRoot = Platform.environment['SystemRoot'] ?? 'C:\\Windows';
      // msvcp140.dll is the core, vcruntime140_1.dll handles x64 specifics in newer redist versions
      final paths = [
        '$sysRoot\\System32\\msvcp140.dll',
        if (Platform.executableArguments.contains('--x64') || !Platform.executable.contains('32'))
          '$sysRoot\\System32\\vcruntime140_1.dll',
      ];
      
      for (final path in paths) {
        if (!(await File(path).exists())) return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
