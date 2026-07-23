import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default fallback app version used when PackageInfo is unavailable.
const String fallbackAppVersion = '1.0.0';

/// Riverpod FutureProvider for retrieving the application version.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  } catch (_) {
    return fallbackAppVersion;
  }
});

