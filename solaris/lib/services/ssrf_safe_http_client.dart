import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/services/ssrf_validator.dart';

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}

class SsrfHttpResponse {
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> headers;
  final String body;

  SsrfHttpResponse({
    required this.statusCode,
    required this.reasonPhrase,
    required this.headers,
    required this.body,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// HttpClient with True IP-Pinning Socket connection against DNS Rebinding and TOCTOU attacks.
class SsrfSafeHttpClient {
  static const int maxRedirects = 3;

  /// Executes an SSRF-safe HTTP POST JSON request.
  static Future<SsrfHttpResponse> postJson(
    Uri targetUri,
    String body, {
    Map<String, String>? customHeaders,
    WebhookConfig? webhookConfig,
    String? deliveryId,
    String? eventName,
    bool allowLanWebhooks = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Uri currentUri = targetUri;
    int redirectCount = 0;

    final String finalDeliveryId = deliveryId ?? _generateUuid();
    final String timestamp = DateTime.now().toUtc().toIso8601String();

    while (redirectCount <= maxRedirects) {
      // 1. DNS Lookup and validation of ALL returned IP addresses
      List<InternetAddress> addresses;
      try {
        addresses = await InternetAddress.lookup(
          currentUri.host,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        throw SocketException(
          'DNS Lookup Failed for host ${currentUri.host}: $e',
        );
      }

      if (addresses.isEmpty) {
        throw SocketException(
          'DNS Lookup Failed: No IP addresses resolved for ${currentUri.host}',
        );
      }

      // Check ALL resolved IPs against SSRF Guard
      for (final ip in addresses) {
        if (SsrfValidator.isBlockedIp(
          ip,
          targetType: SsrfValidationTarget.webhook,
          allowLanWebhooks: allowLanWebhooks,
        )) {
          throw SecurityException(
            'SSRF Guard: Resolved IP (${ip.address}) for ${currentUri.host} is blocked.',
          );
        }
      }

      final validatedIp = addresses.first;

      // 2. HttpClient with custom connectionFactory (True IP-Pinning & TLS SNI for HTTPS)
      final client = HttpClient()
        ..autoUncompress = true
        ..connectionTimeout = const Duration(seconds: 5)
        ..connectionFactory = (uri, proxyHost, proxyPort) async {
          final task = await Socket.startConnect(validatedIp, uri.port);
          final socketFuture = task.socket.then((rawSocket) async {
            if (uri.scheme == 'https') {
              return await SecureSocket.secure(rawSocket, host: uri.host);
            }
            return rawSocket;
          });
          return ConnectionTask.fromSocket(socketFuture, () {
            task.cancel();
          });
        };

      try {
        final request = await client.postUrl(currentUri).timeout(timeout);
        request.followRedirects =
            false; // Disable automatic redirects (Strict Anti-TOCTOU)
        request.headers.contentType = ContentType.json;
        request.headers.set('User-Agent', 'Solaris/1.1.0');
        request.headers.set('X-Solaris-Timestamp', timestamp);
        request.headers.set('X-Solaris-Delivery-Id', finalDeliveryId);
        if (eventName != null) {
          request.headers.set('X-Solaris-Event', eventName);
        }

        // Sign payload if HMAC secret is configured
        if (webhookConfig != null) {
          final signature = webhookConfig.calculateSignature(
            finalDeliveryId,
            timestamp,
            body,
          );
          if (signature != null) {
            request.headers.set('X-Solaris-Signature', signature);
          }
        }

        // Apply custom headers (e.g., Authorization tokens)
        if (customHeaders != null) {
          customHeaders.forEach((k, v) {
            if (v.isNotEmpty) request.headers.set(k, v);
          });
        }
        if (webhookConfig?.customHeaders != null) {
          webhookConfig!.customHeaders!.forEach((k, v) {
            if (v.isNotEmpty) request.headers.set(k, v);
          });
        }

        request.write(body);
        final response = await request.close().timeout(timeout);

        // 3. Handle redirects manually with full re-validation of Location header
        if (response.isRedirect ||
            response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.movedTemporarily ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect ||
            response.statusCode == HttpStatus.permanentRedirect) {
          final location = response.headers.value('location');
          if (location != null) {
            currentUri = currentUri.resolve(location);
            redirectCount++;
            client.close();
            continue;
          }
        }

        // Read response body
        final responseBody = await response.transform(utf8.decoder).join();
        final responseHeaders = <String, String>{};
        response.headers.forEach((name, values) {
          responseHeaders[name] = values.join(', ');
        });

        client.close();

        return SsrfHttpResponse(
          statusCode: response.statusCode,
          reasonPhrase: response.reasonPhrase,
          headers: responseHeaders,
          body: responseBody,
        );
      } catch (e) {
        client.close();
        rethrow;
      }
    }

    throw SocketException(
      'Too many redirects (exceeded maximum of $maxRedirects)',
    );
  }

  static String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode('deliv_$now');
    final hash = base64Url.encode(bytes).replaceAll('=', '');
    return 'deliv-${hash.substring(0, hash.length > 24 ? 24 : hash.length)}';
  }
}
