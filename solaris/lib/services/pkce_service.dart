import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Service to handle PKCE (Proof Key for Code Exchange) generation.
class PkceService {
  /// Generates a high-entropy code verifier.
  /// 
  /// A cryptographically random string between 43 and 128 characters.
  static String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Generates a code challenge from a code verifier using S256.
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Helper to encode bytes to Base64-URL (no padding).
  static String base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
