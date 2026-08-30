import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/active_process_service.dart';
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
  final Map<WebSocket, ApiPermissionsConfig> _clientPermissions = {};
  final Map<WebSocket, ApiKeyEntry?> _clientKeyEntries = {};
  Timer? _heartbeatTimer;
  Timer? _moduleDebounceTimer;
  bool _isListenersInitialized = false;

  WebSocketService(this.ref);

  int get connectedClientsCount => _clients.length;

  /// Lazily initialize heartbeat and provider listeners on first client connection.
  /// Saves ~3-5 MB when no WebSocket clients are connected.
  void _ensureInitialized() {
    if (_isListenersInitialized) return;
    _isListenersInitialized = true;
    _startHeartbeat();
    _setupProviderListeners();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final pingPayload = jsonEncode({'type': 'ping', 'timestamp': nowIso});

      for (final client in _clients.toList()) {
        try {
          final pending = _pendingBytesPerClient[client] ?? 0;
          if (pending > maxPendingBytes) {
            debugPrint(
              'WS Slow Consumer Detected. Disconnecting client (> 512 KB pending).',
            );
            _removeClient(
              client,
              code: 1008,
              reason: 'Slow Consumer: Pending buffer limit exceeded 512 KB',
            );
            continue;
          }
          // Reset byte tracking on heartbeat tick and send ping frame
          _pendingBytesPerClient[client] = 0;
          client.add(pingPayload);
        } catch (_) {
          _removeClient(
            client,
            code: WebSocketStatus.goingAway,
            reason: 'Heartbeat failed',
          );
        }
      }
    });
  }

  void _setupProviderListeners() {
    // Listen to Settings changes for instant reactive revocation and subscription audits
    ref.listen(settingsProvider, (prev, next) {
      final prevSettings = prev?.value?['all'];
      final nextSettings = next.value?['all'];
      if (nextSettings == null) return;

      final prevRequireLocal = prevSettings?.requireLocalToken ?? false;
      final nextRequireLocal = nextSettings.requireLocalToken;

      // 1. Reactive audit for requireLocalToken toggle
      if (nextRequireLocal && !prevRequireLocal) {
        for (final ws in _clients.toList()) {
          if (_clientKeyEntries[ws] == null) {
            _removeClient(ws, code: 4001, reason: 'Local Auth Required');
          }
        }
      }

      // 2. Reactive audit for client keys
      final nextKeys = nextSettings.apiKeys;
      for (final ws in _clients.toList()) {
        final currentKey = _clientKeyEntries[ws];
        if (currentKey == null) continue;

        final updatedKey = nextKeys
            .where((k) => k.id == currentKey.id)
            .firstOrNull;
        if (updatedKey == null) {
          _removeClient(ws, code: 4001, reason: 'Key Revoked');
        } else if (updatedKey.token != currentKey.token) {
          _removeClient(ws, code: 4001, reason: 'Token Regenerated');
        } else if (updatedKey.permissions != _clientPermissions[ws]) {
          final oldPerms = _clientPermissions[ws];
          _clientPermissions[ws] = updatedKey.permissions;
          _clientKeyEntries[ws] = updatedKey;
          _auditSubscriptionsForClient(ws, oldPerms, updatedKey.permissions);
        }
      }

      // 3. Broadcast app_override_changed event when appOverrides rules change
      if (!listEquals(prevSettings?.appOverrides, nextSettings.appOverrides) ||
          prevSettings?.appOverrideExitDelaySeconds !=
              nextSettings.appOverrideExitDelaySeconds) {
        broadcastEvent('app_override_changed', {
          'app_overrides': nextSettings.appOverrides
              .map((e) => e.toJson())
              .toList(),
          'exit_delay_seconds': nextSettings.appOverrideExitDelaySeconds,
        });
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
        final isGaming = ref.read(gamingModeProvider);
        final settingsMap = ref.read(settingsProvider).value ?? {};

        final list = monitors.map((mon) {
          final monSettings =
              settingsMap[mon.deviceName] ??
              settingsMap[mon.id] ??
              settingsMap['all'] ??
              SettingsState();
          return {
            'id': mon.id,
            'name': mon.name,
            'friendly_name': mon.friendlyName,
            'slug': MonitorSlugResolver.getSlugForSystemId(mon.id),
            'device_id_hash': mon.deviceIdHash,
            'is_primary': mon.isPrimary,
            'brightness': mon.realBrightness ?? currentBrightness.round(),
            'temperature': mon.realTemperature ?? currentTemp,
            'game_mode': {
              'enabled': monSettings.isGameModeEnabled,
              'active': isGaming && monSettings.isGameModeEnabled,
            },
          };
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

    // Listen to Active Process changes for active_process_changed event
    ref.listen<ActiveProcessState>(activeProcessServiceProvider, (prev, next) {
      if (prev != next) {
        _broadcastActiveProcessChanged(next);
      }
    });
  }

  void _broadcastActiveProcessChanged(ActiveProcessState activeState) {
    final settingsMap = ref.read(settingsProvider).value;
    final settings = settingsMap?['all'] ?? SettingsState();

    AppOverrideRule? appliedRule;
    if (activeState.activeProcess.isNotEmpty &&
        activeState.suppressedPids.isEmpty) {
      appliedRule = settings.appOverrides.firstWhereOrNull(
        (r) => r.exeName == activeState.activeProcess && r.isEnabled,
      );
    }

    final evalBrightness = ref.read(currentBrightnessProvider);
    final evalTemp = ref.read(currentTemperatureProvider);

    broadcastEvent('active_process_changed', {
      'active_process': activeState.activeProcess,
      'window_title': activeState.windowTitle,
      'is_gaming': activeState.isGaming,
      'applied_override': appliedRule?.toJson(),
      'evaluated_brightness': evalBrightness,
      'evaluated_temperature': evalTemp,
    });
  }

  void _auditSubscriptionsForClient(
    WebSocket ws,
    ApiPermissionsConfig? prevPerms,
    ApiPermissionsConfig nextPerms,
  ) {
    final subs = _subscriptionsPerClient[ws];
    if (subs == null) return;

    void checkRevoked(String moduleName, bool wasAllowed, bool isAllowed) {
      if (wasAllowed && !isAllowed) {
        final isExplicitlySubscribed = subs.contains(moduleName);
        final isImplicitlySubscribed = subs.isEmpty;

        if (isExplicitlySubscribed || isImplicitlySubscribed) {
          if (isExplicitlySubscribed) {
            subs.remove(moduleName);
          }
          try {
            ws.add(
              jsonEncode({
                'type': 'subscription_revoked',
                'module': moduleName,
              }),
            );
          } catch (_) {}
        }
      }
    }

    final prev = prevPerms ?? const ApiPermissionsConfig();
    checkRevoked(
      'monitors',
      prev.allowReadMonitors,
      nextPerms.allowReadMonitors,
    );
    checkRevoked('solar', prev.allowReadSolar, nextPerms.allowReadSolar);
    checkRevoked('weather', prev.allowReadWeather, nextPerms.allowReadWeather);
    checkRevoked('sleep', prev.allowReadSleep, nextPerms.allowReadSleep);
    checkRevoked(
      'circadian',
      prev.allowReadCircadian,
      nextPerms.allowReadCircadian,
    );
    checkRevoked(
      'smart_circadian',
      prev.allowReadCircadian,
      nextPerms.allowReadCircadian,
    );
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
      'weather_brightness_adjustment':
          globalSettings?.isWeatherAdjustmentEnabled ?? true,
      'weather_temperature_adjustment':
          globalSettings?.isWeatherTemperatureAdjustmentEnabled ?? true,
      'weather_adjustment_intensity':
          globalSettings?.weatherAdjustmentIntensity ?? 0.45,
      'smart_circadian': globalSettings?.isSmartCircadianEnabled ?? false,
      'game_mode': {
        'enabled': globalSettings?.isGameModeEnabled ?? true,
        'active': gamingModeActive,
        'brightness_override': globalSettings?.gameModeBrightness ?? 80.0,
        'temperature_enabled':
            globalSettings?.isGameModeTemperatureEnabled ?? true,
        'temperature_override': globalSettings?.gameModeTemperature ?? 6500.0,
      },
    };
  }

  /// Upgrade HTTP connection to WebSocket after authenticating and validating CSWSH Guard.
  Future<void> handleUpgrade(
    HttpRequest request, {
    required ApiRouter router,
    required bool isLanEnabled,
  }) async {
    final origin = request.headers.value('origin');
    final referer = request.headers.value('referer');
    final remoteIp = request.connectionInfo?.remoteAddress.address ?? '';

    // 1. CSWSH Guard & Drive-by Origin Check
    bool isLocalHostUri(String? uriStr) {
      if (uriStr == null) return false;
      final uri = Uri.tryParse(uriStr);
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1' || host == '::1';
    }

    final hasBrowserOrigin =
        (origin != null && !isLocalHostUri(origin)) ||
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
    token ??=
        request.headers.value('x-api-key') ??
        request.headers
            .value('authorization')
            ?.replaceAll('Bearer ', '')
            .trim();

    final isLoopback = remoteIp == '127.0.0.1' || remoteIp == '::1';
    final isAnonymousLocalAllowed =
        isLoopback && !router.requireLocalToken && !hasBrowserOrigin;

    final matchedKey = (token != null && token.isNotEmpty)
        ? router.findMatchingKey(token)
        : null;

    // 1. If token was provided but is invalid -> reject immediately with 401 Unauthorized (even on loopback)
    if (token != null && token.isNotEmpty && matchedKey == null) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({'error': 'Unauthorized: Invalid API key provided'}),
        );
      await request.response.close();
      return;
    }

    // 2. If no token was provided, check if anonymous local connection is allowed
    if (matchedKey == null && !isAnonymousLocalAllowed) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Unauthorized: Missing API key'}));
      await request.response.close();
      return;
    }

    if (_clients.length >= maxClients) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'error':
                'Service Unavailable: Max WebSocket connections ($maxClients) reached',
          }),
        );
      await request.response.close();
      return;
    }

    // Lazy initialization: start heartbeat and provider listeners only
    // when the first client connects (~3-5 MB saved when WS is unused)
    _ensureInitialized();

    final ws = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: matchedSubprotocol != null
          ? (_) => matchedSubprotocol!
          : null,
    );
    ws.pingInterval = const Duration(seconds: 25);

    _clients.add(ws);
    _pendingBytesPerClient[ws] = 0;
    _subscriptionsPerClient[ws] = <String>{};

    if (matchedKey != null) {
      _clientPermissions[ws] = matchedKey.permissions;
      _clientKeyEntries[ws] = matchedKey;
      router.onKeyUsed?.call(matchedKey.id);
    } else {
      _clientPermissions[ws] = const ApiPermissionsConfig();
      _clientKeyEntries[ws] = null;
    }

    try {
      final perms = _clientPermissions[ws] ?? const ApiPermissionsConfig();
      final snapshotMap = await _buildSnapshotMap(perms);
      ws.add(jsonEncode({'type': 'snapshot', 'data': snapshotMap}));
    } catch (e) {
      debugPrint('WebSocketService: Snapshot generation error: $e');
      ws.add(
        jsonEncode({
          'type': 'snapshot',
          'data': {'version': '1.1.0', 'monitors': <dynamic>[]},
        }),
      );
    }

    ws.listen(
      (data) {
        _pendingBytesPerClient[ws] = 0;
        if (data is String) _handleClientMessage(ws, data);
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
      final monitors = await ref
          .read(monitorServiceProvider)
          .getConnectedMonitors();
      MonitorSlugResolver.updateMonitors(monitors);
      final currentBrightness = ref.read(currentBrightnessProvider);
      final currentTemp = ref.read(currentTemperatureProvider);
      final isGaming = ref.read(gamingModeProvider);
      final settingsMap = ref.read(settingsProvider).value ?? {};

      map['monitors'] = monitors.map((mon) {
        final monSettings =
            settingsMap[mon.deviceName] ??
            settingsMap[mon.id] ??
            settingsMap['all'] ??
            SettingsState();
        return {
          'id': mon.id,
          'name': mon.name,
          'friendly_name': mon.friendlyName,
          'slug': MonitorSlugResolver.getSlugForSystemId(mon.id),
          'is_primary': mon.isPrimary,
          'brightness': mon.realBrightness ?? currentBrightness.round(),
          'temperature': mon.realTemperature ?? currentTemp,
          'game_mode': {
            'enabled': monSettings.isGameModeEnabled,
            'active': isGaming && monSettings.isGameModeEnabled,
          },
        };
      }).toList();
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
    map['automation'] = ApiPermissionsFilter.filterAutomation(
      rawAutomation,
      permissions,
    );

    return map;
  }

  void _handleClientMessage(WebSocket ws, String messageText) async {
    try {
      final jsonMap = jsonDecode(messageText) as Map<String, dynamic>;
      final type = jsonMap['type'] as String?;

      if (type == 'ping') {
        ws.add(
          jsonEncode({
            'type': 'pong',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        return;
      }

      final permissions =
          _clientPermissions[ws] ?? const ApiPermissionsConfig();

      if (type == 'subscribe') {
        final requestedModules =
            (jsonMap['modules'] as List<dynamic>?)
                ?.map((e) => e.toString().toLowerCase())
                .toSet() ??
            <String>{};

        final allowedModules = <String>{};

        for (final mod in requestedModules) {
          bool isAllowed = true;
          if (mod == 'solar' && !permissions.allowReadSolar) isAllowed = false;
          if (mod == 'weather' && !permissions.allowReadWeather)
            isAllowed = false;
          if (mod == 'monitors' && !permissions.allowReadMonitors)
            isAllowed = false;
          if (mod == 'sleep' && !permissions.allowReadSleep) isAllowed = false;
          if ((mod == 'circadian' || mod == 'smart_circadian') &&
              !permissions.allowReadCircadian)
            isAllowed = false;

          if (isAllowed) {
            allowedModules.add(mod);
          } else {
            ws.add(
              jsonEncode({
                'type': 'subscription_denied',
                'module': mod,
                'reason': 'Read access disabled in API permissions',
              }),
            );
          }
        }

        final currentSubs = _subscriptionsPerClient[ws] ?? <String>{};
        currentSubs.addAll(allowedModules);
        _subscriptionsPerClient[ws] = currentSubs;

        ws.add(
          jsonEncode({
            'type': 'subscribed',
            'active_modules': currentSubs.toList(),
          }),
        );
        return;
      }

      if (type == 'unsubscribe') {
        final removeModules =
            (jsonMap['modules'] as List<dynamic>?)
                ?.map((e) => e.toString().toLowerCase())
                .toSet() ??
            <String>{};

        final currentSubs = _subscriptionsPerClient[ws] ?? <String>{};
        currentSubs.removeAll(removeModules);
        _subscriptionsPerClient[ws] = currentSubs;

        ws.add(
          jsonEncode({
            'type': 'unsubscribed',
            'active_modules': currentSubs.toList(),
          }),
        );
        return;
      }

      if (type == 'command') {
        final cmdId = jsonMap['cmd_id'] as String?;
        final action = jsonMap['action'] as String?;

        if (action == null) {
          ws.add(
            jsonEncode({
              'type': 'response',
              'cmd_id': cmdId,
              'status': 'error',
              'message': 'Missing "action" field',
            }),
          );
          return;
        }

        // Privilege Escalation Guard
        if (jsonMap.containsKey('apiKeys') ||
            jsonMap.containsKey('apiKey') ||
            jsonMap.containsKey('apiPermissions') ||
            jsonMap.containsKey('permissions')) {
          ws.add(
            jsonEncode({
              'type': 'response',
              'cmd_id': cmdId,
              'status': 'error',
              'action': action,
              'error': 'Forbidden',
              'message':
                  'Modifying API permissions or keys via WebSocket commands is strictly prohibited.',
            }),
          );
          return;
        }

        // ACL Evaluation
        final checkResult = ApiPermissionsChecker.checkAction(
          permissions,
          action,
        );

        if (!checkResult.isAllowed) {
          ws.add(
            jsonEncode({
              'type': 'response',
              'cmd_id': cmdId,
              'status': 'error',
              'action': action,
              'error': 'Forbidden',
              'message': checkResult.detail,
            }),
          );
          return;
        }

        final controlHandler = ApiControlHandler(ref.container);
        final result = await controlHandler.executeAction(
          jsonMap,
          permissions: permissions,
        );

        ws.add(
          jsonEncode({
            'type': 'response',
            'cmd_id': cmdId,
            'status': result['status'] ?? 'ok',
            'action': action,
            'applied': result['applied'],
            'error': result['error'],
            'message': result['message'],
          }),
        );
        return;
      }
    } catch (e) {
      debugPrint('WebSocket message handling error: $e');
    }
  }

  /// Broadcast module update to subscribers with granular per-client permissions filtering
  void broadcastModule(String moduleName, dynamic data) {
    if (_clients.isEmpty) return;
    final moduleLower = moduleName.toLowerCase();

    for (final client in _clients.toList()) {
      try {
        final clientPermissions =
            _clientPermissions[client] ?? const ApiPermissionsConfig();

        // Check read permissions for module for this specific client
        if (moduleLower == 'solar' && !clientPermissions.allowReadSolar)
          continue;
        if (moduleLower == 'weather' && !clientPermissions.allowReadWeather)
          continue;
        if (moduleLower == 'monitors' && !clientPermissions.allowReadMonitors)
          continue;
        if (moduleLower == 'sleep' && !clientPermissions.allowReadSleep)
          continue;
        if ((moduleLower == 'circadian' || moduleLower == 'smart_circadian') &&
            !clientPermissions.allowReadCircadian)
          continue;

        dynamic filteredData = data;
        if (moduleLower == 'automation' && data is Map<String, dynamic>) {
          filteredData = ApiPermissionsFilter.filterAutomation(
            data,
            clientPermissions,
          );
        } else if ((moduleLower == 'circadian' ||
                moduleLower == 'smart_circadian') &&
            data is Map<String, dynamic>) {
          filteredData = ApiPermissionsFilter.filterSmartCircadian(
            data,
            clientPermissions,
          );
          if (filteredData == null) continue;
        }

        final subs = _subscriptionsPerClient[client];
        // If client specified explicit subscriptions and this module isn't included, skip
        if (subs != null && subs.isNotEmpty && !subs.contains(moduleLower)) {
          continue;
        }

        final payloadStr = jsonEncode({
          'type': 'update',
          'module': moduleName,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'data': filteredData,
        });

        final payloadBytesLen = utf8.encode(payloadStr).length;

        final pending = _pendingBytesPerClient[client] ?? 0;
        if (pending > maxPendingBytes) {
          _removeClient(
            client,
            code: 1008,
            reason: 'Slow Consumer: Pending buffer limit exceeded 512 KB',
          );
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

    final category =
        ApiPermissionsConfig.getCategoryForAction(eventName) ??
        ApiActionCategory.system;

    for (final client in _clients.toList()) {
      try {
        final clientPermissions =
            _clientPermissions[client] ?? const ApiPermissionsConfig();
        if (!clientPermissions.allowedCategories.contains(category)) {
          continue;
        }
        if (!clientPermissions.isActionAllowed(eventName)) {
          continue;
        }

        final payloadStr = jsonEncode({
          'type': 'event',
          'event': eventName,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        });

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
    _clientPermissions.remove(ws);
    _clientKeyEntries.remove(ws);
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
    _clientPermissions.clear();
    _clientKeyEntries.clear();
    debugPrint('WebSocketService: Closed all connected clients.');
  }

  void dispose() {
    closeAll();
  }
}
