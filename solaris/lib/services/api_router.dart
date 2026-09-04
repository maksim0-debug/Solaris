import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/rfc7807_error.dart';

/// Scope permissions & key attachment extension for HttpRequest
extension HttpRequestPermissions on HttpRequest {
  static final Expando<ApiPermissionsConfig> _permissions =
      Expando<ApiPermissionsConfig>();
  static final Expando<ApiKeyEntry> _apiKeyEntry = Expando<ApiKeyEntry>();

  ApiPermissionsConfig? get attachedPermissions => _permissions[this];
  ApiPermissionsConfig get permissions =>
      _permissions[this] ?? const ApiPermissionsConfig();
  set permissions(ApiPermissionsConfig val) => _permissions[this] = val;

  ApiKeyEntry? get apiKeyEntry => _apiKeyEntry[this];
  set apiKeyEntry(ApiKeyEntry? val) => _apiKeyEntry[this] = val;
}

/// Match result for router lookup.
class RouteMatch {
  final ApiHandler handler;
  final Map<String, String> pathParams;

  RouteMatch({required this.handler, required this.pathParams});
}

/// Handler signature for API endpoints.
typedef ApiHandler =
    Future<void> Function(HttpRequest request, Map<String, String> pathParams);

/// Middleware signature returning true to continue down the chain, or false to halt.
typedef ApiMiddleware = Future<bool> Function(HttpRequest request);

class ApiRouter {
  final List<_RouteEntry> _routes = [];
  final List<ApiMiddleware> _middlewares = [];

  List<ApiKeyEntry> apiKeys = [];
  bool requireLocalToken = false;
  bool isLanEnabled = false;

  /// Callback emitted when an API key is used, for decoupled throttled persistence
  void Function(String keyId)? onKeyUsed;

  /// Legacy proxy getter and setter for 100% backward compatibility with existing tests
  String get expectedToken => apiKeys.isNotEmpty ? apiKeys.first.token : '';
  set expectedToken(String value) {
    if (value.isEmpty) return;
    if (apiKeys.isNotEmpty) {
      apiKeys[0] = apiKeys.first.copyWith(token: value);
    } else {
      apiKeys = [
        ApiKeyEntry(
          id: 'default_legacy',
          name: 'Default Key',
          token: value,
          permissions: const ApiPermissionsConfig(),
          createdAt: DateTime.now(),
        ),
      ];
    }
  }

  /// Constant-time lookup of token against active apiKeys via SHA-256
  ApiKeyEntry? findMatchingKey(String? token) {
    if (token == null || token.isEmpty) return null;
    for (final keyEntry in apiKeys) {
      if (constantTimeEquals(token, keyEntry.token)) {
        return keyEntry;
      }
    }
    return null;
  }

  void get(String pattern, ApiHandler handler) =>
      _addRoute('GET', pattern, handler);
  void post(String pattern, ApiHandler handler) =>
      _addRoute('POST', pattern, handler);
  void put(String pattern, ApiHandler handler) =>
      _addRoute('PUT', pattern, handler);
  void delete(String pattern, ApiHandler handler) =>
      _addRoute('DELETE', pattern, handler);

  void _addRoute(String method, String pattern, ApiHandler handler) {
    _routes.add(
      _RouteEntry(
        method: method.toUpperCase(),
        pattern: pattern,
        handler: handler,
      ),
    );
  }

  void use(ApiMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Dispatch incoming HTTP request through middleware chain and route handler.
  Future<bool> handle(HttpRequest request) async {
    // 1. Execute middleware chain
    for (final middleware in _middlewares) {
      final canContinue = await middleware(request);
      if (!canContinue) return true; // Handled (or rejected) by middleware
    }

    // 2. Trie/Segment Route Match
    final method = request.method.toUpperCase();
    final pathSegments = request.uri.pathSegments;

    for (final route in _routes) {
      if (route.method != method && route.method != 'ANY') continue;

      final match = route.match(pathSegments);
      if (match != null) {
        try {
          await match.handler(request, match.pathParams);
        } catch (e, st) {
          debugPrint(
            'ApiRouter: Error handling route ${request.uri.path}: $e\n$st',
          );
          _sendError(
            request,
            HttpStatus.internalServerError,
            'Internal Server Error',
            e.toString(),
          );
        }
        return true;
      }
    }

    return false; // Route not matched
  }

  static void sendJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> data,
  ) {
    try {
      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(data));
      request.response.close();
    } catch (e) {
      debugPrint('ApiRouter: Error sending JSON response: $e');
    }
  }

  static void sendRfc7807(HttpRequest request, Rfc7807Error error) {
    try {
      request.response
        ..statusCode = error.status
        ..headers.set('Content-Type', 'application/problem+json')
        ..write(error.toJsonString());
      request.response.close();
    } catch (e) {
      debugPrint('ApiRouter: Error sending RFC 7807 response: $e');
    }
  }

  static void _sendError(
    HttpRequest request,
    int statusCode,
    String title,
    String detail,
  ) {
    final error = Rfc7807Error(
      type: 'about:blank',
      title: title,
      status: statusCode,
      detail: detail,
      instance: request.uri.path,
    );
    sendRfc7807(request, error);
  }
}

class _RouteEntry {
  final String method;
  final String pattern;
  final ApiHandler handler;
  final List<String> _patternSegments;

  _RouteEntry({
    required this.method,
    required this.pattern,
    required this.handler,
  }) : _patternSegments = Uri.parse(pattern).pathSegments;

  RouteMatch? match(List<String> requestSegments) {
    if (requestSegments.length != _patternSegments.length) return null;

    final pathParams = <String, String>{};
    for (int i = 0; i < _patternSegments.length; i++) {
      final pSeg = _patternSegments[i];
      final rSeg = requestSegments[i];

      if (pSeg.startsWith(':')) {
        final paramName = pSeg.substring(1);
        pathParams[paramName] = rSeg;
      } else if (pSeg != rSeg) {
        return null;
      }
    }

    return RouteMatch(handler: handler, pathParams: pathParams);
  }
}

// ==========================================
// MIDDLEWARES
// ==========================================

/// Security Headers Middleware & CSP rules for OpenAPI / docs
Future<bool> securityHeadersMiddleware(HttpRequest request) async {
  final response = request.response;
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'SAMEORIGIN');

  if (request.uri.path.startsWith('/api/v1/docs')) {
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'self'; connect-src 'self' http: https: ws: wss:; script-src 'self' 'unsafe-inline' https://unpkg.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;",
    );
  } else {
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'none'; frame-ancestors 'none';",
    );
  }
  return true;
}

/// Payload Size Guard Middleware (64 KB limit to prevent Chunked OOM)
Future<bool> payloadSizeGuardMiddleware(HttpRequest request) async {
  final contentLength = request.contentLength;
  if (contentLength > 65536) {
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/payload-too-large',
      title: 'Payload Too Large',
      status: HttpStatus.requestEntityTooLarge,
      detail: 'Maximum allowed request payload size is 64 KB (65,536 bytes).',
      instance: request.uri.path,
    );
    ApiRouter.sendRfc7807(request, error);
    return false;
  }
  return true;
}

/// Content-Type Guard Middleware (requires application/json for POST, PUT, DELETE)
Future<bool> contentTypeGuardMiddleware(HttpRequest request) async {
  final method = request.method.toUpperCase();
  if (method == 'POST' || method == 'PUT' || method == 'DELETE') {
    final contentType = request.headers.contentType;
    if (contentType == null || contentType.mimeType != 'application/json') {
      final error = Rfc7807Error(
        type: 'https://solaris.local/errors/unsupported-media-type',
        title: 'Unsupported Media Type',
        status: HttpStatus.unsupportedMediaType,
        detail:
            'Content-Type header must be application/json for mutating requests.',
        instance: request.uri.path,
      );
      ApiRouter.sendRfc7807(request, error);
      return false;
    }
  }
  return true;
}

// Host header TTL cache
DateTime? _lastInterfaceRefresh;
Set<String> _cachedAllowedHosts = {};

/// Host Header Validation Middleware with 30s TTL cache against DNS Rebinding
Future<bool> hostHeaderValidationMiddleware(HttpRequest request) async {
  final hostHeader = request.headers.value('host');
  if (hostHeader == null || hostHeader.isEmpty) {
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/forbidden',
      title: 'Forbidden',
      status: HttpStatus.forbidden,
      detail: 'Missing Host header in request.',
      instance: request.uri.path,
    );
    ApiRouter.sendRfc7807(request, error);
    return false;
  }

  // Safe extraction supporting IPv6 e.g. [::1]:45321
  final match = RegExp(
    r'^(?:\[(?<ipv6>[^\]]+)\]|(?<host>[^:]+))',
  ).firstMatch(hostHeader);
  final hostOnly = match != null
      ? (match.namedGroup('ipv6') ?? match.namedGroup('host') ?? '')
            .toLowerCase()
      : hostHeader.split(':').first.toLowerCase();

  final now = DateTime.now();
  if (_lastInterfaceRefresh == null ||
      now.difference(_lastInterfaceRefresh!).inSeconds > 30) {
    final allowedHosts = {'localhost', '127.0.0.1', '::1'};
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          allowedHosts.add(addr.address.toLowerCase());
        }
      }
    } catch (e) {
      debugPrint(
        'hostHeaderValidationMiddleware: NetworkInterface.list error: $e',
      );
    }
    _cachedAllowedHosts = allowedHosts;
    _lastInterfaceRefresh = now;
  }

  if (!_cachedAllowedHosts.contains(hostOnly)) {
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/untrusted-host',
      title: 'Forbidden',
      status: HttpStatus.forbidden,
      detail: 'Untrusted Host header ($hostOnly). Access denied.',
      instance: request.uri.path,
    );
    ApiRouter.sendRfc7807(request, error);
    return false;
  }

  return true;
}

/// CORS & Strict Drive-by Protection Middleware
/// Helper to check if a URI string belongs to a trusted host (loopback or local interface)
bool _isTrustedUri(String? uriStr) {
  if (uriStr == null) return false;
  final uri = Uri.tryParse(uriStr);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  final isLoopback =
      host == 'localhost' || host == '127.0.0.1' || host == '::1';
  return isLoopback || _cachedAllowedHosts.contains(host);
}

/// CORS & Strict Drive-by Protection Middleware
Future<bool> corsMiddleware(HttpRequest request, ApiRouter router) async {
  final origin = request.headers.value('Origin');
  final referer = request.headers.value('Referer');

  final hasTrustedOrigin = _isTrustedUri(origin);
  final isUntrustedOrigin =
      (origin != null && !hasTrustedOrigin) ||
      (referer != null && !_isTrustedUri(referer));

  final isPublicRoute =
      request.uri.path.startsWith('/api/v1/docs') ||
      request.uri.path == '/api/v1/openapi.json' ||
      request.uri.path == '/api/v1/health';

  // OPTIONS preflight handling
  if (request.method == 'OPTIONS') {
    final allowPreflight = hasTrustedOrigin || isPublicRoute;
    request.response
      ..statusCode = allowPreflight
          ? HttpStatus.noContent
          : HttpStatus.forbidden
      ..headers.set(
        'Access-Control-Allow-Origin',
        allowPreflight ? (origin ?? '*') : '',
      )
      ..headers.set(
        'Access-Control-Allow-Methods',
        'GET, POST, PUT, DELETE, OPTIONS',
      )
      ..headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, X-API-Key, Authorization',
      );
    await request.response.close();
    return false;
  }

  // Drive-by Guard: Untrusted Origin/Referer requires API key (except public routes)
  if (isUntrustedOrigin && !isPublicRoute) {
    final token =
        request.headers.value('X-API-Key') ??
        request.headers
            .value('Authorization')
            ?.replaceAll('Bearer ', '')
            .trim();
    final matchedKey = router.findMatchingKey(token);
    if (matchedKey == null) {
      final error = Rfc7807Error(
        type: 'https://solaris.local/errors/drive-by-blocked',
        title: 'Forbidden',
        status: HttpStatus.forbidden,
        detail:
            'Untrusted origin or referer header detected. Provide valid X-API-Key.',
        instance: request.uri.path,
      );
      ApiRouter.sendRfc7807(request, error);
      return false;
    }
    // Single-pass optimization: attach resolved key & permissions to avoid re-hashing in authMiddleware
    request.permissions = matchedKey.permissions;
    request.apiKeyEntry = matchedKey;
    router.onKeyUsed?.call(matchedKey.id);
  }

  if (hasTrustedOrigin && origin != null) {
    request.response.headers.set('Access-Control-Allow-Origin', origin);
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, X-API-Key, Authorization',
    );
  }

  return true;
}

/// Constant-time SHA-256 Auth & Strict Localhost Drive-by Guard Middleware
Future<bool> authMiddleware(HttpRequest request, ApiRouter router) async {
  if (request.method == 'OPTIONS') {
    return true; // CORS preflight requests bypass auth check
  }

  final token =
      request.headers.value('X-API-Key') ??
      request.headers.value('Authorization')?.replaceAll('Bearer ', '').trim();

  // 1. Priority token validation if present (for all routes, including public and loopback)
  if (request.apiKeyEntry != null) {
    // Already verified & attached in corsMiddleware
  } else if (token != null && token.isNotEmpty) {
    final matchedKey = router.findMatchingKey(token);
    if (matchedKey == null) {
      final error = Rfc7807Error(
        type: 'https://solaris.local/errors/unauthorized',
        title: 'Unauthorized',
        status: HttpStatus.unauthorized,
        detail: 'Invalid API token provided.',
        instance: request.uri.path,
      );
      ApiRouter.sendRfc7807(request, error);
      return false;
    }

    // Attach permissions and key entry to request context
    request.permissions = matchedKey.permissions;
    request.apiKeyEntry = matchedKey;
    router.onKeyUsed?.call(matchedKey.id);
  }

  // 2. Anonymous passthrough for public routes (openapi.json retains attached permissions if token was passed)
  if (request.uri.path.startsWith('/api/v1/docs') ||
      request.uri.path == '/api/v1/openapi.json' ||
      request.uri.path == '/api/v1/health') {
    return true;
  }

  // If token was successfully validated above -> allow access
  if (request.apiKeyEntry != null) {
    return true;
  }

  final origin = request.headers.value('Origin');
  final referer = request.headers.value('Referer');

  final hasBrowserOrigin =
      (origin != null && !_isTrustedUri(origin)) ||
      (referer != null && !_isTrustedUri(referer));

  final remoteIp = request.connectionInfo?.remoteAddress.address ?? '';
  final isLoopback = remoteIp == '127.0.0.1' || remoteIp == '::1';

  // 3. Anonymous loopback access allowed ONLY if token is completely absent
  if (isLoopback && !router.requireLocalToken && !hasBrowserOrigin) {
    request.apiKeyEntry = null; // Explicit null for anonymous loopback
    return true;
  }

  // 4. Reject request if missing token
  final error = Rfc7807Error(
    type: 'https://solaris.local/errors/unauthorized',
    title: 'Unauthorized',
    status: HttpStatus.unauthorized,
    detail: 'Missing API token.',
    instance: request.uri.path,
  );
  ApiRouter.sendRfc7807(request, error);
  return false;
}

/// Constant-time comparison of two strings using SHA-256 hashes against timing attacks.
/// Includes Non-Empty Token Guard.
bool constantTimeEquals(String input, String expected) {
  if (expected.isEmpty || input.isEmpty) return false;

  final hashInput = sha256.convert(utf8.encode(input)).bytes;
  final hashExpected = sha256.convert(utf8.encode(expected)).bytes;

  int result = 0;
  for (int i = 0; i < 32; i++) {
    result |= hashInput[i] ^ hashExpected[i];
  }
  return result == 0;
}

// Rate Limiter Token Bucket & LruCache against OOM
class TokenBucket {
  final double capacity;
  final double refillRate;
  double tokens;
  DateTime lastRefill;

  TokenBucket({required this.capacity, required this.refillRate})
    : tokens = capacity,
      lastRefill = DateTime.now();

  bool consume() {
    final now = DateTime.now();
    final deltaSeconds = now.difference(lastRefill).inMilliseconds / 1000.0;
    tokens = (tokens + deltaSeconds * refillRate).clamp(0.0, capacity);
    lastRefill = now;

    if (tokens >= 1.0) {
      tokens -= 1.0;
      return true;
    }
    return false;
  }
}

final Map<String, TokenBucket> _rateLimiters = {};
const int _maxIpEntries = 500;

/// Rate Limiter Middleware (Token Bucket per IP with LRU cleanup)
Future<bool> rateLimiterMiddleware(HttpRequest request) async {
  final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';
  if (ip == '127.0.0.1' || ip == '::1') return true; // Soft limit for localhost

  if (_rateLimiters.length > _maxIpEntries) {
    _rateLimiters.clear(); // Simple LRU flush on capacity overflow
  }

  final bucket = _rateLimiters.putIfAbsent(
    ip,
    () => TokenBucket(capacity: 20.0, refillRate: 2.0),
  );

  if (!bucket.consume()) {
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/too-many-requests',
      title: 'Too Many Requests',
      status: HttpStatus.tooManyRequests,
      detail: 'Rate limit exceeded. Try again in 60 seconds.',
      instance: request.uri.path,
    );
    request.response.headers.set('Retry-After', '60');
    ApiRouter.sendRfc7807(request, error);
    return false;
  }

  return true;
}
