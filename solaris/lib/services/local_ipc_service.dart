import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/local_ipc_server_state.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/api_status_handler.dart';

class LocalIpcService extends Notifier<LocalIpcServerState> {
  HttpServer? _server;
  bool _isStarting = false;
  late final ApiRouter _router;
  late final ApiStatusHandler _statusHandler;
  late final ApiControlHandler _controlHandler;
  late final ApiMonitorsHandler _monitorsHandler;

  @override
  LocalIpcServerState build() {
    _router = ApiRouter();
    _statusHandler = ApiStatusHandler(ref);
    _controlHandler = ApiControlHandler(ref.container);
    _monitorsHandler = ApiMonitorsHandler(ref.container);

    _setupRouter();

    ref.listen<AsyncValue<Map<String, SettingsState>>>(
      settingsProvider,
      (previous, next) {
        next.whenData((settingsMap) {
          Future.microtask(() async {
            final settings = settingsMap['all'];
            final prevSettings = previous?.value?['all'];
            if (settings != null) {
              final isEnabled = settings.isLocalIpcServerEnabled;
              final port = settings.apiServerPort;
              final prevPort = prevSettings?.apiServerPort ?? prevSettings?.localIpcServerPort;
              final lanEnabled = settings.isApiLanAccessEnabled;
              final prevLanEnabled = prevSettings?.isApiLanAccessEnabled;

              _router.expectedToken = settings.apiAccessToken;
              _router.isLanEnabled = lanEnabled;

              if (isEnabled) {
                if (!state.isRunning) {
                  await start();
                } else if (port != prevPort || lanEnabled != prevLanEnabled) {
                  await stop();
                  await start();
                }
              } else {
                if (state.isRunning) {
                  await stop();
                }
              }
            }
          });
        });
      },
      fireImmediately: true,
    );

    ref.onDispose(() {
      _server?.close(force: true);
      _server = null;
    });

    return const LocalIpcServerState(isRunning: false);
  }

  void _setupRouter() {
    // 1. Register Middlewares
    _router.use((HttpRequest req) => securityHeadersMiddleware(req));
    _router.use((HttpRequest req) => payloadSizeGuardMiddleware(req));
    _router.use((HttpRequest req) => contentTypeGuardMiddleware(req));
    _router.use((HttpRequest req) => hostHeaderValidationMiddleware(req));
    _router.use((HttpRequest req) => corsMiddleware(req, _router));
    _router.use((HttpRequest req) => authMiddleware(req, _router));
    _router.use((HttpRequest req) => rateLimiterMiddleware(req));

    // 2. Register Phase 1 Status & Read-Only Routes
    _router.get('/api/v1/health', (HttpRequest req, Map<String, String> params) => _statusHandler.handleHealth(req, params));
    _router.get('/api/v1/status', (HttpRequest req, Map<String, String> params) => _statusHandler.handleStatus(req, params));
    _router.get('/api/v1/solar', (HttpRequest req, Map<String, String> params) => _statusHandler.handleSolar(req, params));
    _router.get('/api/v1/presets', (HttpRequest req, Map<String, String> params) => _statusHandler.handlePresets(req, params));
    _router.get('/api/v1/monitors', (HttpRequest req, Map<String, String> params) => _monitorsHandler.handleGetMonitors(req, params));
    _router.get('/api/v1/monitors/:slug', (HttpRequest req, Map<String, String> params) => _monitorsHandler.handleGetMonitorBySlug(req, params));
    _router.get('/api/v1/sleep/sessions', (HttpRequest req, Map<String, String> params) => _statusHandler.handleSleepSessions(req, params));
    _router.get('/api/v1/docs', (HttpRequest req, Map<String, String> params) => _statusHandler.handleDocs(req, params));
    _router.get('/api/v1/openapi.json', (HttpRequest req, Map<String, String> params) => _statusHandler.handleOpenApiJson(req, params));

    // 3. Register Phase 2 Control & Per-Monitor Endpoints
    _router.post('/api/v1/control', (HttpRequest req, Map<String, String> params) => _controlHandler.handleControl(req, params));
    _router.post('/api/v1/monitors/:slug/brightness', (HttpRequest req, Map<String, String> params) => _monitorsHandler.handleSetMonitorBrightness(req, params));
    _router.post('/api/v1/monitors/:slug/temperature', (HttpRequest req, Map<String, String> params) => _monitorsHandler.handleSetMonitorTemperature(req, params));

    // 4. Register Legacy Endpoints Aliases (100% Backward Compatibility)
    _router.post('/api/sleep/sessions', (HttpRequest req, Map<String, String> params) => _handleSleepSessions(req));
    _router.post('/api/sleep/status', (HttpRequest req, Map<String, String> params) => _handleSleepStatus(req));
    _router.get('/api/sleep/status', (HttpRequest req, Map<String, String> params) => _handleGetStatus(req));
  }

  /// Starts the HTTP server on configured port with auto-fallback to ports 45322..45330
  Future<void> start() async {
    if (state.isRunning || _isStarting) return;
    _isStarting = true;
    state = state.copyWith(isRunning: false, error: null, failedPort: null);

    final settingsMap = ref.read(settingsProvider).value;
    final configuredPort = settingsMap?['all']?.apiServerPort ?? 45321;
    final isLanEnabled = settingsMap?['all']?.isApiLanAccessEnabled ?? false;

    final bindAddress = isLanEnabled ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;

    int targetPort = configuredPort;
    HttpServer? boundServer;

    for (int offset = 0; offset <= 9; offset++) {
      final currentPort = configuredPort + offset;
      try {
        boundServer = await HttpServer.bind(bindAddress, currentPort);
        targetPort = currentPort;
        break;
      } on SocketException catch (e) {
        if (offset == 9) {
          debugPrint('LocalIpcService: Failed to bind to any port in range $configuredPort..${configuredPort + 9}: $e');
          _isStarting = false;
          state = state.copyWith(
            isRunning: false,
            error: 'Failed to bind port: ${e.message}',
            failedPort: configuredPort,
          );
          return;
        }
      }
    }

    _server = boundServer;
    _server?.autoCompress = true;

    _listen();
    _isStarting = false;

    state = state.copyWith(
      isRunning: true,
      port: targetPort,
      error: null,
      failedPort: null,
    );
    debugPrint('LocalIpcService: Server bound and listening at http://${bindAddress.address}:$targetPort');
  }

  void _listen() {
    _server?.listen((HttpRequest request) async {
      try {
        final handled = await _router.handle(request);
        if (!handled) {
          _sendResponse(request, HttpStatus.notFound, {
            'error': 'Not Found',
            'available_endpoints': [
              'GET /api/v1/status',
              'GET /api/v1/health',
              'GET /api/v1/monitors',
              'GET /api/v1/presets',
              'GET /api/v1/solar',
              'POST /api/v1/control',
              'GET /api/v1/docs',
              'GET /api/v1/openapi.json',
            ],
          });
        }
      } catch (e, st) {
        debugPrint('Error handling IPC request: $e\n$st');
        _sendResponse(request, HttpStatus.internalServerError, {
          'error': 'Internal Server Error',
          'detail': e.toString(),
        });
      }
    });
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: false).timeout(
        const Duration(seconds: 2),
        onTimeout: () => _server!.close(force: true),
      );
      _server = null;
      debugPrint('LocalIpcService: Gracefully stopped API server.');
    }
    state = const LocalIpcServerState(isRunning: false);
  }

  Future<void> _handleSleepSessions(HttpRequest request) async {
    try {
      final String content = await utf8.decoder.bind(request).join();
      final dynamic body = jsonDecode(content);

      if (body is List) {
        final sessions = body
            .map((e) => SleepSession.fromJson(e as Map<String, dynamic>))
            .toList();
        await ref.read(sleepProvider.notifier).updateSessionsFromIpc(sessions);
        _sendResponse(request, HttpStatus.ok, {'status': 'success'});
      } else {
        _sendResponse(request, HttpStatus.badRequest, {
          'error': 'Invalid format. Expected array of sessions.',
        });
      }
    } catch (e) {
      _sendResponse(request, HttpStatus.badRequest, {
        'error': 'Failed to parse JSON: $e',
      });
    }
  }

  Future<void> _handleSleepStatus(HttpRequest request) async {
    try {
      final String content = await utf8.decoder.bind(request).join();
      final dynamic body = jsonDecode(content);

      if (body is Map<String, dynamic> && body.containsKey('is_sleeping')) {
        final bool isSleeping = body['is_sleeping'] as bool;
        final now = DateTime.now();
        final session = SleepSession(
          id: 'ipc_${now.millisecondsSinceEpoch}',
          startTime: isSleeping ? now : now.subtract(const Duration(hours: 8)),
          endTime: now,
          source: 'local_api',
        );

        await ref
            .read(sleepProvider.notifier)
            .updateSessionsFromIpc([session]);
        _sendResponse(request, HttpStatus.ok, {'status': 'success'});
      } else {
        _sendResponse(request, HttpStatus.badRequest, {
          'error': 'Invalid format. Expected object with is_sleeping.',
        });
      }
    } catch (e) {
      _sendResponse(request, HttpStatus.badRequest, {
        'error': 'Failed to parse JSON: $e',
      });
    }
  }

  Future<void> _handleGetStatus(HttpRequest request) async {
    final sleepState = ref.read(sleepProvider);
    final isSleeping = sleepState.sessions.isNotEmpty &&
        sleepState.sessions.first.endTime.isAfter(DateTime.now());

    _sendResponse(request, HttpStatus.ok, {
      'status': 'success',
      'is_sleeping': isSleeping,
      'sessions_count': sleepState.sessions.length,
      'last_fetch': sleepState.lastFetchTime?.toIso8601String(),
    });
  }

  void _sendResponse(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> data,
  ) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data));
    request.response.close();
  }
}
