import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/local_ipc_server_state.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers.dart';

class LocalIpcService extends Notifier<LocalIpcServerState> {
  HttpServer? _server;
  bool _isStarting = false;

  @override
  LocalIpcServerState build() {
    ref.listen<AsyncValue<Map<String, SettingsState>>>(
      settingsProvider,
      (previous, next) {
        next.whenData((settingsMap) async {
          final settings = settingsMap['all'];
          final prevSettings = previous?.value?['all'];
          if (settings != null) {
            final isEnabled = settings.isLocalIpcServerEnabled;
            final port = settings.localIpcServerPort;
            final prevPort = prevSettings?.localIpcServerPort;

            if (isEnabled) {
              if (!state.isRunning) {
                await start();
              } else if (port != prevPort) {
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
      },
      fireImmediately: true,
    );

    ref.onDispose(() {
      stop();
    });

    return const LocalIpcServerState(isRunning: false);
  }

  /// Starts the HTTP server on the configured port if enabled.
  Future<void> start() async {
    if (state.isRunning || _isStarting) return;
    _isStarting = true;
    state = state.copyWith(isRunning: false, error: null, failedPort: null);

    final settingsMap = ref.read(settingsProvider).value;
    final settings = settingsMap?['all'];
    if (settings == null) {
      debugPrint('LocalIpcService: Settings not loaded yet. Delaying startup.');
      _isStarting = false;
      return;
    }

    if (!settings.isLocalIpcServerEnabled) {
      debugPrint('LocalIpcService: Server is disabled in settings.');
      _isStarting = false;
      return;
    }

    final portToBind = settings.localIpcServerPort;

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4, // 127.0.0.1 for security
        portToBind,
        shared: true,
      );
      debugPrint('LocalIpcService: Server running on http://${_server!.address.address}:${_server!.port}');
      state = LocalIpcServerState(isRunning: true, port: _server!.port);
      _listen();
    } catch (e) {
      debugPrint('LocalIpcService: Failed to bind server to port $portToBind: $e');
      _server = null;
      state = LocalIpcServerState(
        isRunning: false,
        error: e.toString(),
        failedPort: portToBind,
      );
    } finally {
      _isStarting = false;
    }
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      debugPrint('LocalIpcService: Server stopped.');
      _server = null;
    }
    state = const LocalIpcServerState(isRunning: false);
  }

  /// REST Request Listener loop
  void _listen() {
    _server?.listen((HttpRequest request) async {
      try {
        final path = request.uri.path;
        final method = request.method;

        if (method == 'POST' && path == '/api/sleep/sessions') {
          await _handleSleepSessions(request);
        } else if (method == 'POST' && path == '/api/sleep/status') {
          await _handleSleepStatus(request);
        } else if (method == 'GET' && path == '/api/sleep/status') {
          await _handleGetStatus(request);
        } else {
          _sendResponse(request, HttpStatus.notFound, {'error': 'Not Found'});
        }
      } catch (e) {
        debugPrint('LocalIpcService: Exception handling request: $e');
        _sendResponse(
          request,
          HttpStatus.internalServerError,
          {'error': 'Internal Server Error', 'details': e.toString()},
        );
      }
    }, onError: (Object error) {
      debugPrint('LocalIpcService: Server error: $error');
    });
  }

  Future<void> _handleSleepSessions(HttpRequest request) async {
    final body = await _readRequestBody(request);
    if (body == null) {
      _sendResponse(request, HttpStatus.badRequest, {'error': 'Empty request body'});
      return;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        _sendResponse(request, HttpStatus.badRequest, {'error': 'Expected JSON array of sleep sessions'});
        return;
      }

      final sessions = decoded.map((item) {
        final map = item as Map<String, dynamic>;
        // Force source to local_api when received via local API endpoint
        return SleepSession.fromJson({
          ...map,
          'source': map['source'] ?? 'local_api',
        });
      }).toList();

      if (sessions.isEmpty) {
        _sendResponse(request, HttpStatus.badRequest, {'error': 'No valid sessions provided'});
        return;
      }

      // Update sessions in notifier
      await ref.read(sleepProvider.notifier).updateSessionsFromIpc(sessions);

      _sendResponse(request, HttpStatus.ok, {
        'status': 'success',
        'message': 'Successfully processed ${sessions.length} sleep sessions.',
      });
    } catch (e) {
      debugPrint('LocalIpcService: Failed to parse sleep sessions: $e');
      _sendResponse(request, HttpStatus.badRequest, {'error': 'Invalid JSON or session format', 'details': e.toString()});
    }
  }

  Future<void> _handleSleepStatus(HttpRequest request) async {
    final body = await _readRequestBody(request);
    if (body == null) {
      _sendResponse(request, HttpStatus.badRequest, {'error': 'Empty request body'});
      return;
    }

    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final isSleeping = decoded['is_sleeping'] as bool?;

      if (isSleeping == null) {
        _sendResponse(request, HttpStatus.badRequest, {'error': 'Missing required parameter "is_sleeping"'});
        return;
      }

      debugPrint('LocalIpcService: Received sleep status change: isSleeping = $isSleeping');

      // TODO: Реализовать реакцию на реальный статус сна (включение Wind-Down/Снижение яркости)

      _sendResponse(request, HttpStatus.ok, {
        'status': 'success',
        'is_sleeping': isSleeping,
        'message': 'Status received (processing logic pending implementation)',
      });
    } catch (e) {
      _sendResponse(request, HttpStatus.badRequest, {'error': 'Invalid JSON format', 'details': e.toString()});
    }
  }

  Future<void> _handleGetStatus(HttpRequest request) async {
    final sleepState = ref.read(sleepProvider);
    _sendResponse(request, HttpStatus.ok, {
      'service': 'Solaris Local API',
      'running': true,
      'port': _server?.port,
      'cached_sessions_count': sleepState.sessions.length,
      'last_fetch': sleepState.lastFetchTime?.toIso8601String(),
    });
  }

  Future<String?> _readRequestBody(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      return content.trim().isEmpty ? null : content;
    } catch (e) {
      debugPrint('LocalIpcService: Error reading request body: $e');
      return null;
    }
  }

  void _sendResponse(HttpRequest request, int statusCode, Map<String, dynamic> data) {
    try {
      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(data));
      request.response.close();
    } catch (e) {
      debugPrint('LocalIpcService: Error sending response: $e');
    }
  }
}
