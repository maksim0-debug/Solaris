import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_permissions_filter.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

/// High-performance WebSocket streaming service with CSWSH protection,
/// granular permissions filtering, selective subscriptions, runtime ACL auditing,
/// and Slow Consumer OOM protection.
class WebSocketService {
  static const int maxClients = 20;
  static const int maxPendingBytes = 512 * 1024; // 512 KB limit

  final Ref ref;
  final Set<WebSocket> _clients = {};
  final Map<WebSocket, int> _pendingBytesPerClient = {};
  final Map<WebSocket, Set<String>> _subscriptionsPerClient = {};
  Timer? _heartbeatTimer;
  Timer? _moduleDebounceTimer;

  WebSocketService(this.ref) {
    _startHeartbeat();
    _setupProviderListeners();
  }

  int get connectedClientsCount => _clients.length;

  ApiPermissionsConfig _getPermissions() {
    final settingsMap = ref.read(settingsProvider).value;
    return settingsMap?['all']?.apiPermissions ?? const ApiPermissionsConfig();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final pingPayload = jsonEncode({
        'type': 'ping',
        'timestamp': nowIso,
      });

      for (final client in _clients.toList()) {
        try {
          final pending = _pendingBytesPerClient[client] ?? 0;
          if (pending > maxPendingBytes) {
            debugPrint('WS Slow Consumer Detected. Disconnecting client (> 512 KB pending).');
            _removeClient(client, code: 1008, reason: 'Slow Consumer: Pending buffer limit exceeded 512 KB');
            continue;
          }
          // Reset byte tracking on heartbeat tick and send ping frame
          _pendingBytesPerClient[client] = 0;
          client.add(pingPayload);
        } catch (_) {
          _removeClient(client, code: WebSocketStatus.goingAway, reason: 'Heartbeat failed');
        }
      }
    });
  }

  void _setupProviderListeners() {
    // Listen to API Permissions toggles in runtime for instant synchronous subscription audit
    ref.listen(settingsProvider, (prev, next) {
      final prevPerms = prev?.value?['all']?.apiPermissions;
      final nextPerms = next.value?['all']?.apiPermissions;

      if (nextPerms != null && (prevPerms == null || prevPerms != nextPerms)) {
        _auditSubscriptions(prevPerms, nextPerms);
      }
    });

    // Listen to Solar State changes
    ref.listen(solarStateStreamProvider, (prev, next) {
      next.whenData((solar) {
        broadcastModule('solar', {
          'elevation': solar.sunElevation,
          'azimuth': solar.sunAzimuth,
          'zenith': solar.sunZenith,
          'progress': solar.sunProgress,
          'current_phase': solar.currentPhase.name,
          'next_event': {
            'type': solar.nextEventType.name,
            'in_seconds': solar.timeUntilNextEvent.inSeconds,
          },
          'uv_index': solar.uvIndex,
          'spectral_intensity': solar.spectralIntensity,
        });
      });
    });

    // Listen to Monitors list changes
    ref.listen(monitorListProvider, (prev, next) {
      next.whenData((monitors) {
        MonitorSlugResolver.updateMonitors(monitors);
        final currentBrightness = ref.read(currentBrightnessProvider);
        final currentTemp = ref.read(currentTemperatureProvider);

        final list = monitors.map((mon) => {
          'id': mon.id,
          'name': mon.name,
          'friendly_name': mon.friendlyName,
          'slug': MonitorSlugResolver.getSlugForSystemId(mon.id),
          'device_id_hash': mon.deviceIdHash,
          'is_primary': mon.isPrimary,
          'brightness': mon.realBrightness ?? currentBrightness.round(),
          'temperature': mon.realTemperature ?? currentTemp,
        }).toList();

        broadcastModule('monitors', list);
      });
    });

    // Listen to Gaming Mode changes
    ref.listen(gamingModeProvider, (prev, next) {
      if (prev != next) {
        broadcastModule('automation', _buildAutomationData());
      }
    });

    // Listen to Auto Brightness changes
    ref.listen(autoBrightnessAdjustmentProvider, (prev, next) {
      if (prev != next) {
        broadcastModule('automation', _buildAutomationData());
      }
    });

    // Listen to Sleep State changes
    ref.listen(sleepProvider, (prev, next) {
      broadcastModule('sleep', {
        'is_sleeping': next.isCurrentlySleeping,
        'sessions_count': next.sessions.length,
        'last_session_end': next.lastSessionEnd?.toIso8601String(),
      });
    });
  }

  void _auditSubscriptions(
    ApiPermissionsConfig? prevPerms,
    ApiPermissionsConfig nextPerms,
  ) {
    for (final ws in _clients.toList()) {
      final subs = _subscriptionsPerClient[ws];
      if (subs == null) continue;

      void checkRevoked(String moduleName, bool wasAllowed, bool isAllowed) {
        if (wasAllowed && !isAllowed) {
          final isExplicitlySubscribed = subs.contains(moduleName);
          final isImplicitlySubscribed = subs.isEmpty;

          if (isExplicitlySubscribed || isImplicitlySubscribed) {
            if (isExplicitlySubscribed) {
              subs.remove(moduleName);
            }
            try {
              ws.add(jsonEncode({
                'type': 'subscription_revoked',
                'module': moduleName,
              }));
            } catch (_) {}
          }
        }
      }

      final prev = prevPerms ?? const ApiPermissionsConfig();
      checkRevoked('monitors', prev.allowReadMonitors, nextPerms.allowReadMonitors);
      checkRevoked('solar', prev.allowReadSolar, nextPerms.allowReadSolar);
      checkRevoked('weather', prev.allowReadWeather, nextPerms.allowReadWeather);
      checkRevoked('sleep', prev.allowReadSleep, nextPerms.allowReadSleep);
      checkRevoked('circadian', prev.allowReadCircadian, nextPerms.allowReadCircadian);
      checkRevoked('smart_circadian', prev.allowReadCircadian, nextPerms.allowReadCircadian);
    }
  }

  Map<String, dynamic> _buildAutomationData() {
    final settingsMap = ref.read(settingsProvider).value;
    final globalSettings = settingsMap?['all'];
    final autoBrightnessEnabled = ref.read(autoBrightnessAdjustmentProvider);
    final autoTempEnabled = ref.read(autoTemperatureAdjustmentProvider);
    final isColorTempEnabled = ref.read(isColorTemperatureEnabledProvider);
    final gamingModeActive = ref.read(gamingModeProvider);

    return {
      'auto_brightness': autoBrightnessEnabled,
      'auto_temperature': autoTempEnabled,
      'color_temperature_hardware_enabled': isColorTempEnabled,
      'weather_brightness_adjustment': globalSettings?.isWeatherAdjustmentEnabled ?? true,
      'weather_temperature_adjustment': globalSettings?.isWeatherTemperatureAdjustmentEnabled ?? true,
      'weather_adjustment_intensity': globalSettings?.weatherAdjustmentIntensity ?? 0.45,
      'smart_circadian': globalSettings?.isSmartCircadianEnabled ?? false,
      'game_mode': {
        'enabled': globalSettings?.isGameModeEnabled ?? true,
        'active': gamingModeActive,
        'brightness_override': globalSettings?.gameModeBrightness ?? 80.0,
      },
    };
  }

  /// Upgrade HTTP connection to WebSocket after authenticating and validating CSWSH Guard.
  Future<void> handleUpgrade(
    HttpRequest request, {
    required String expectedToken,
    required bool isLanEnabled,
  }) async {
    final origin = request.headers.value('origin');
    final referer = request.headers.value('referer');

    // 1. CSWSH Guard & Drive-by Origin Check
    bool isLocalHostUri(String? uriStr) {
      if (uriStr == null) return false;
      final uri = Uri.tryParse(uriStr);
      if (uri == null) return false;
      return uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    }

    final hasBrowserOrigin = (origin != null && !isLocalHostUri(origin)) ||
                             (referer != null && !isLocalHostUri(referer));

    // 2. Extract Auth Token from Query, Subprotocol, or Headers
    String? token;

    // A. Query Parameter ?token=<KEY>
    token ??= request.uri.queryParameters['token'];

    // B. Subprotocol Header Sec-WebSocket-Protocol: bearer.<KEY> or bearer, <KEY>
    String? matchedSubprotocol;
    final subprotocolHeader = request.headers.value('sec-websocket-protocol');
    if (token == null && subprotocolHeader != null) {
      final parts = subprotocolHeader.split(',').map((s) => s.trim()).toList();
      for (final part in parts) {
        if (part.startsWith('bearer.')) {
          token = part.substring(7);
          matchedSubprotocol = part;
          break;
        } else if (part.toLowerCase() != 'bearer' && token == null) {
          token = part;
          matchedSubprotocol = part;
        }
      }
    }

    // C. X-API-Key or Authorization Header
    token ??= request.headers.value('x-api-key') ??
        request.headers.value('authorization')?.replaceAll('Bearer ', '').trim();

    // Verification check
    final requiresAuth = isLanEnabled || hasBrowserOrigin || expectedToken.isNotEmpty;

    if (requiresAuth) {
      if (token == null || !constantTimeEquals(token, expectedToken)) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'Unauthorized: Invalid or missing API key'}));
        await request.response.close();
        return;
      }
    }

    // 3. Client Limit Guard
    if (_clients.length >= maxClients) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Service Unavailable: Max WebSocket connections ($maxClients) reached'}));
      await request.response.close();
      return;
    }

    // 4. Upgrade Socket
    final ws = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: matchedSubprotocol != null ? (_) => matchedSubprotocol! : null,
    );
    ws.pingInterval = const Duration(seconds: 25);

    _clients.add(ws);
    _pendingBytesPerClient[ws] = 0;
    _subscriptionsPerClient[ws] = <String>{}; // Empty set = receive all allowed modules

    // 5. Send Initial Snapshot with Granular Permission Filtering
    try {
      final permissions = _getPermissions();
      final snapshotMap = await _buildSnapshotMap(permissions);
      final snapshotStr = jsonEncode({
        'type': 'snapshot',
        'data': snapshotMap,
      });
      ws.add(snapshotStr);
    } catch (e) {
      debugPrint('WebSocketService: Snapshot generation error: $e');
      ws.add(jsonEncode({
        'type': 'snapshot',
        'data': {'version': '1.1.0', 'monitors': <dynamic>[]},
      }));
    }

    // 6. Listen to incoming client messages
    ws.listen(
      (data) {
        _pendingBytesPerClient[ws] = 0; // Reset lag count on any client activity
        if (data is String) {
          _handleClientMessage(ws, data);
        }
      },
      onDone: () => _removeClient(ws),
      onError: (_) => _removeClient(ws),
    );
  }

  Future<Map<String, dynamic>> _buildSnapshotMap(
    ApiPermissionsConfig permissions,
  ) async {
    final appVersionAsync = ref.read(appVersionProvider);
    final version = appVersionAsync.value ?? '1.1.0';

    final map = <String, dynamic>{
      'version': version,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    if (permissions.allowReadSolar) {
      final solar = ref.read(solarStateStreamProvider).value;
      if (solar != null) {
        map['solar'] = {
          'elevation': solar.sunElevation,
          'azimuth': solar.sunAzimuth,
          'zenith': solar.sunZenith,
          'progress': solar.sunProgress,
          'current_phase': solar.currentPhase.name,
          'uv_index': solar.uvIndex,
          'spectral_intensity': solar.spectralIntensity,
        };
      } else {
        map['solar'] = null;
      }
    }

    if (permissions.allowReadWeather) {
      final weather = ref.read(currentWeatherProvider).value;
      map['weather'] = weather != null
          ? {
              'available': true,
              'temperature_celsius': weather.temperature,
              'weather_code': weather.weatherCode,
            }
          : {'available': false};
    }

    if (permissions.allowReadMonitors) {
      final monitors =
          await ref.read(monitorServiceProvider).getConnectedMonitors();
      MonitorSlugResolver.updateMonitors(monitors);
      final currentBrightness = ref.read(currentBrightnessProvider);
      final currentTemp = ref.read(currentTemperatureProvider);

      map['monitors'] = monitors
          .map((mon) => {
                'id': mon.id,
                'name': mon.name,
                'friendly_name': mon.friendlyName,
                'slug': MonitorSlugResolver.getSlugForSystemId(mon.id),
                'is_primary': mon.isPrimary,
                'brightness': mon.realBrightness ?? currentBrightness.round(),
                'temperature': mon.realTemperature ?? currentTemp,
              })
          .toList();
    }

    if (permissions.allowReadSleep) {
      final sleepState = ref.read(sleepProvider);
      map['sleep'] = {
        'is_sleeping': sleepState.isCurrentlySleeping,
        'sessions_count': sleepState.sessions.length,
        'last_session_end': sleepState.lastSessionEnd?.toIso8601String(),
      };
    }

    final rawAutomation = _buildAutomationData();
    map['automation'] =
        ApiPermissionsFilter.filterAutomation(rawAutomation, permissions);

    return map;
  }

  void _handleClientMessage(WebSocket ws, String messageText) async {
    try {
      final jsonMap = jsonDecode(messageText) as Map<String, dynamic>;
      final type = jsonMap['type'] as String?;

      if (type == 'ping') {
        ws.add(jsonEncode({
          'type': 'pong',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }));
        return;
      }

      if (type == 'subscribe') {
        final requestedModules = (jsonMap['modules'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toSet() ?? <String>{};

        final permissions = _getPermissions();
        final allowedModules = <String>{};

        for (final mod in requestedModules) {
          bool isAllowed = true;
          if (mod == 'solar' && !permissions.allowReadSolar) isAllowed = false;
          if (mod == 'weather' && !permissions.allowReadWeather) isAllowed = false;
          if (mod == 'monitors' && !permissions.allowReadMonitors) isAllowed = false;
          if (mod == 'sleep' && !permissions.allowReadSleep) isAllowed = false;
          if ((mod == 'circadian' || mod == 'smart_circadian') && !permissions.allowReadCircadian) isAllowed = false;

          if (isAllowed) {
            allowedModules.add(mod);
          } else {
            ws.add(jsonEncode({
              'type': 'subscription_denied',
              'module': mod,
              'reason': 'Read access disabled in API permissions',
            }));
          }
        }

        _subscriptionsPerClient[ws] = allowedModules;

        ws.add(jsonEncode({
          'type': 'subscribed',
          'active_modules': allowedModules.toList(),
        }));
        return;
      }

      if (type == 'command') {
        final cmdId = jsonMap['cmd_id'] as String?;
        final action = jsonMap['action'] as String?;

        if (action == null) {
          ws.add(jsonEncode({
            'type': 'response',
            'cmd_id': cmdId,
            'status': 'error',
            'message': 'Missing "action" field',
          }));
          return;
        }

        // Privilege Escalation Guard
        if (jsonMap.containsKey('apiPermissions') || jsonMap.containsKey('permissions')) {
          ws.add(jsonEncode({
            'type': 'response',
            'cmd_id': cmdId,
            'status': 'error',
            'action': action,
            'error': 'Forbidden',
            'message': 'Modifying API permissions via WebSocket commands is strictly prohibited.',
          }));
          return;
        }

        // ACL Evaluation
        final permissions = _getPermissions();
        final category = ApiPermissionsConfig.getCategoryForAction(action);
        final checkResult = ApiPermissionsChecker.checkCategory(permissions, category);

        if (!checkResult.isAllowed) {
          ws.add(jsonEncode({
            'type': 'response',
            'cmd_id': cmdId,
            'status': 'error',
            'action': action,
            'error': 'Forbidden',
            'message': checkResult.detail,
          }));
          return;
        }

        final controlHandler = ApiControlHandler(ref.container);
        final result = await controlHandler.executeAction(jsonMap);

        ws.add(jsonEncode({
          'type': 'response',
          'cmd_id': cmdId,
          'status': result['status'] ?? 'ok',
          'action': action,
          'applied': result['applied'],
          'error': result['error'],
          'message': result['message'],
        }));
        return;
      }
    } catch (e) {
      debugPrint('WebSocket message handling error: $e');
    }
  }

  /// Broadcast module update to subscribers with granular permissions filtering
  void broadcastModule(String moduleName, dynamic data) {
    if (_clients.isEmpty) return;

    final permissions = _getPermissions();
    final moduleLower = moduleName.toLowerCase();

    // Check read permissions for module
    if (moduleLower == 'solar' && !permissions.allowReadSolar) return;
    if (moduleLower == 'weather' && !permissions.allowReadWeather) return;
    if (moduleLower == 'monitors' && !permissions.allowReadMonitors) return;
    if (moduleLower == 'sleep' && !permissions.allowReadSleep) return;
    if ((moduleLower == 'circadian' || moduleLower == 'smart_circadian') && !permissions.allowReadCircadian) return;

    dynamic filteredData = data;
    if (moduleLower == 'automation' && data is Map<String, dynamic>) {
      filteredData = ApiPermissionsFilter.filterAutomation(data, permissions);
    } else if ((moduleLower == 'circadian' || moduleLower == 'smart_circadian') && data is Map<String, dynamic>) {
      filteredData = ApiPermissionsFilter.filterSmartCircadian(data, permissions);
      if (filteredData == null) return;
    }

    final payloadStr = jsonEncode({
      'type': 'update',
      'module': moduleName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': filteredData,
    });

    final payloadBytesLen = utf8.encode(payloadStr).length;

    for (final client in _clients.toList()) {
      try {
        final subs = _subscriptionsPerClient[client];
        // If client specified explicit subscriptions and this module isn't included, skip
        if (subs != null && subs.isNotEmpty && !subs.contains(moduleLower)) {
          continue;
        }

        final pending = _pendingBytesPerClient[client] ?? 0;
        if (pending > maxPendingBytes) {
          _removeClient(client, code: 1008, reason: 'Slow Consumer: Pending buffer limit exceeded 512 KB');
          continue;
        }

        _pendingBytesPerClient[client] = pending + payloadBytesLen;
        client.add(payloadStr);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  /// Broadcast event payload to allowed clients
  void broadcastEvent(String eventName, Map<String, dynamic> data) {
    if (_clients.isEmpty) return;

    final permissions = _getPermissions();
    final category = ApiPermissionsConfig.getCategoryForAction(eventName) ?? ApiActionCategory.system;
    if (!permissions.allowedCategories.contains(category)) {
      return;
    }

    final payloadStr = jsonEncode({
      'type': 'event',
      'event': eventName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });

    for (final client in _clients.toList()) {
      try {
        client.add(payloadStr);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  void _removeClient(WebSocket ws, {int? code, String? reason}) {
    _clients.remove(ws);
    _pendingBytesPerClient.remove(ws);
    _subscriptionsPerClient.remove(ws);
    try {
      if (code != null) {
        ws.close(code, reason);
      } else {
        ws.close();
      }
    } catch (_) {}
  }

  /// Close all client connections gracefully
  void closeAll({int code = 1001, String reason = 'Server shutting down'}) {
    _heartbeatTimer?.cancel();
    _moduleDebounceTimer?.cancel();
    for (final client in _clients.toList()) {
      try {
        client.close(code, reason);
      } catch (_) {}
    }
    _clients.clear();
    _pendingBytesPerClient.clear();
    _subscriptionsPerClient.clear();
    debugPrint('WebSocketService: Closed all connected clients.');
  }

  void dispose() {
    closeAll();
  }
}
