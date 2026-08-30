import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';
import 'package:collection/collection.dart';

/// Safe Riverpod state mutation outside Flutter frame rendering phase.
Future<void> safeStateMutator(VoidCallback mutation) async {
  final completer = Completer<void>();
  Future.microtask(() {
    try {
      mutation();
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    }
  });
  return completer.future;
}

/// Helper to detect privilege escalation reserved fields in payloads
bool containsPrivilegeEscalationKeys(Map<String, dynamic> map) {
  return map.containsKey('apiKeys') ||
      map.containsKey('apiKey') ||
      map.containsKey('apiPermissions') ||
      map.containsKey('permissions');
}

/// Handler for POST /api/v1/control
class ApiControlHandler {
  final ProviderContainer _container;

  ApiControlHandler(this._container);

  ApiPermissionsConfig _getPermissions([HttpRequest? request]) {
    if (request != null && request.attachedPermissions != null) {
      return request.attachedPermissions!;
    }
    final settingsMap =
        _container.read(settingsProvider).value ??
        _container.read(settingsProvider).asData?.value;
    final globalSettings = settingsMap?['all'];
    return globalSettings?.apiPermissions ?? const ApiPermissionsConfig();
  }

  Future<void> handleControl(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    try {
      final String content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) {
        await _sendError(
          request,
          HttpStatus.badRequest,
          'Bad Request',
          'Request body cannot be empty.',
        );
        return;
      }

      final dynamic jsonPayload = jsonDecode(content);
      if (jsonPayload is! Map<String, dynamic>) {
        await _sendError(
          request,
          HttpStatus.badRequest,
          'Invalid JSON',
          'JSON body must be an object.',
        );
        return;
      }

      if (jsonPayload.containsKey('actions') &&
          jsonPayload['actions'] is List) {
        await _handleBatchControl(request, jsonPayload, permissions);
        return;
      }

      final actionResult = await _executeSingleAction(jsonPayload, permissions);
      if (actionResult.isError) {
        await _sendError(
          request,
          actionResult.statusCode,
          actionResult.errorTitle,
          actionResult.errorMessage,
        );
        return;
      }

      final statusCode = actionResult.isDebounced
          ? HttpStatus.accepted
          : HttpStatus.ok;
      final responseBody = actionResult.toResponseBody();

      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseBody));
      await request.response.close();
    } catch (e) {
      debugPrint('[ApiControlHandler] Error handling control request: $e');
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Malformed Request',
        'Failed to parse control payload: ${e.toString()}',
      );
    }
  }

  Future<void> _handleBatchControl(
    HttpRequest request,
    Map<String, dynamic> jsonPayload,
    ApiPermissionsConfig permissions,
  ) async {
    if (containsPrivilegeEscalationKeys(jsonPayload)) {
      await _sendError(
        request,
        HttpStatus.forbidden,
        'Privilege Escalation Prohibited',
        'Modifying API permissions or keys via mutation endpoints is strictly prohibited.',
      );
      return;
    }

    final rawActions = jsonPayload['actions'] as List;
    final mode = (jsonPayload['mode'] as String?)?.toLowerCase() ?? 'fail_fast';

    // Pre-flight ACL check for fail_fast mode: validate all actions BEFORE executing any mutations
    if (mode == 'fail_fast') {
      for (int i = 0; i < rawActions.length; i++) {
        final actionItem = rawActions[i];
        if (actionItem is Map<String, dynamic>) {
          if (containsPrivilegeEscalationKeys(actionItem)) {
            await _sendError(
              request,
              HttpStatus.forbidden,
              'Privilege Escalation Prohibited',
              'Modifying API permissions or keys via mutation endpoints is strictly prohibited.',
            );
            return;
          }
          final actionStr = actionItem['action'] as String?;
          if (actionStr != null) {
            final checkResult = ApiPermissionsChecker.checkAction(
              permissions,
              actionStr,
            );
            if (!checkResult.isAllowed) {
              await _sendError(
                request,
                HttpStatus.forbidden,
                checkResult.title,
                checkResult.detail,
              );
              return;
            }
          }
        }
      }
    }

    final List<Map<String, dynamic>> results = [];
    int successfulActions = 0;

    for (int i = 0; i < rawActions.length; i++) {
      final actionItem = rawActions[i];
      if (actionItem is! Map<String, dynamic>) {
        final errResult = _ActionResult.error(
          HttpStatus.badRequest,
          'Invalid Action Format',
          'Action at index $i is not a JSON object.',
        );
        results.add({'index': i, ...errResult.toResponseBody()});
        if (mode == 'fail_fast') break;
        continue;
      }

      final res = await _executeSingleAction(actionItem, permissions);
      results.add({'index': i, ...res.toResponseBody()});

      if (!res.isError) {
        successfulActions++;
      } else if (mode == 'fail_fast') {
        break;
      }
    }

    final responseBody = {
      'status': successfulActions == rawActions.length
          ? 'completed'
          : 'partial',
      'mode': mode,
      'total_actions': rawActions.length,
      'successful_actions': successfulActions,
      'results': results,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    await request.response.close();
  }

  /// Public wrapper for executing a control action (used by WebSocket, etc.)
  Future<Map<String, dynamic>> executeAction(
    Map<String, dynamic> payload, {
    required ApiPermissionsConfig permissions,
  }) async {
    final result = await _executeSingleAction(payload, permissions);
    return result.toResponseBody();
  }

  Future<_ActionResult> _executeSingleAction(
    Map<String, dynamic> payload,
    ApiPermissionsConfig permissions,
  ) async {
    final mutablePayload = Map<String, dynamic>.from(payload);

    if (containsPrivilegeEscalationKeys(mutablePayload)) {
      return _ActionResult.error(
        HttpStatus.forbidden,
        'Privilege Escalation Prohibited',
        'Modifying API permissions or keys via mutation endpoints is strictly prohibited.',
      );
    }

    var action = mutablePayload['action'] as String?;
    if (action == null || action.isEmpty) {
      return _ActionResult.error(
        HttpStatus.unprocessableEntity,
        'Missing Action',
        "Field 'action' is required.",
      );
    }

    // Per-Action ACL check with canonical key
    final canonicalAction = ApiPermissionsConfig.getCanonicalAction(action);
    final checkResult = ApiPermissionsChecker.checkAction(
      permissions,
      canonicalAction,
    );
    if (!checkResult.isAllowed) {
      final statusCode = checkResult.title == 'Unknown Action'
          ? HttpStatus.unprocessableEntity
          : HttpStatus.forbidden;
      return _ActionResult.error(
        statusCode,
        checkResult.title,
        checkResult.detail,
      );
    }

    // Parameter injection for preset & weather provider aliases before switch
    final lowerAction = action.toLowerCase();
    if (const ['brightest', 'bright', 'dim', 'dimmest'].contains(lowerAction)) {
      mutablePayload['preset'] = action;
      action = 'set_brightness_preset';
    } else if (const [
      'coolest',
      'cool',
      'warm',
      'warmest',
    ].contains(lowerAction)) {
      mutablePayload['preset'] = action;
      action = 'set_temperature_preset';
    } else if (const [
      'openmeteo',
      'weatherapi',
      'auto',
    ].contains(lowerAction)) {
      mutablePayload['provider'] = action;
      action = 'set_weather_provider';
    }

    final monitorIdInput =
        mutablePayload['monitor_id'] as String? ??
        mutablePayload['monitor'] as String? ??
        'all';
    final monitors =
        _container.read(monitorListProvider).value ??
        await _container.read(monitorServiceProvider).getConnectedMonitors();
    MonitorSlugResolver.updateMonitors(monitors);
    final resolvedMonitorId = MonitorSlugResolver.resolveToSystemId(
      monitorIdInput,
    );

    if (resolvedMonitorId != 'all' && resolvedMonitorId != 'primary') {
      final exists = monitors.any(
        (m) => m.id == resolvedMonitorId || m.deviceName == resolvedMonitorId,
      );
      if (!exists && resolvedMonitorId == null) {
        return _ActionResult.error(
          HttpStatus.notFound,
          'Unknown Monitor ID',
          "Monitor with id '$monitorIdInput' was not found.",
        );
      }
    }

    switch (action) {
      case 'set_brightness':
        final val = _toDouble(mutablePayload['value']);
        if (val == null || val < 0.0 || val > 100.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a number between 0.0 and 100.0.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(autoBrightnessAdjustmentProvider.notifier)
              .setEnabled(false);
          _container.read(manualBrightnessProvider.notifier).update(val);
        });
        return _ActionResult.accepted('set_brightness', {
          'value': val,
          'monitor_id': monitorIdInput,
        });

      case 'set_auto_brightness':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(autoBrightnessAdjustmentProvider.notifier)
              .setEnabled(enabled);
        });
        return _ActionResult.ok('set_auto_brightness', {'enabled': enabled});

      case 'toggle_auto_brightness':
        await safeStateMutator(() {
          _container.read(autoBrightnessAdjustmentProvider.notifier).toggle();
        });
        final current = _container.read(autoBrightnessAdjustmentProvider);
        return _ActionResult.ok('toggle_auto_brightness', {'enabled': current});

      case 'set_temperature':
        final val = _toInt(mutablePayload['value']);
        if (val == null || val < 3300 || val > 6500) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be an integer Kelvin between 3300 and 6500.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(temperatureSettingsProvider.notifier)
              .toggleEnabled(false);
          _container
              .read(manualTemperatureProvider.notifier)
              .setTemperature(val);
        });
        return _ActionResult.accepted('set_temperature', {
          'value': val,
          'monitor_id': monitorIdInput,
        });

      case 'set_color_temperature_enabled':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(isColorTemperatureEnabledProvider.notifier)
              .set(enabled);
        });
        return _ActionResult.ok('set_color_temperature_enabled', {
          'enabled': enabled,
        });

      case 'set_auto_temperature':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(temperatureSettingsProvider.notifier)
              .toggleEnabled(enabled);
        });
        return _ActionResult.ok('set_auto_temperature', {'enabled': enabled});

      case 'toggle_auto_temperature':
        await safeStateMutator(() {
          _container.read(autoTemperatureAdjustmentProvider.notifier).toggle();
        });
        final current = _container.read(autoTemperatureAdjustmentProvider);
        return _ActionResult.ok('toggle_auto_temperature', {
          'enabled': current,
        });

      case 'set_brightness_preset':
        final presetStr = mutablePayload['preset'] as String?;
        final type = _parsePresetType(presetStr);
        if (type == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'preset' must be one of: brightest, bright, dim, dimmest.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).setActivePreset(type);
        });
        return _ActionResult.ok('set_brightness_preset', {'preset': presetStr});

      case 'set_temperature_preset':
        final presetStr = mutablePayload['preset'] as String?;
        final type = _parseTemperaturePresetType(presetStr);
        if (type == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'preset' must be one of: coolest, cool, warm, warmest.",
          );
        }
        await safeStateMutator(() {
          _container.read(temperatureSettingsProvider.notifier).setPreset(type);
        });
        return _ActionResult.ok('set_temperature_preset', {
          'preset': presetStr,
        });

      case 'set_user_preset':
        final id = mutablePayload['id'] as String?;
        if (id == null || id.isEmpty) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'id' (string) is required for user preset.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).setActiveUserPreset(id);
        });
        return _ActionResult.ok('set_user_preset', {'id': id});

      case 'cycle_preset':
        final dir = mutablePayload['direction'] as String? ?? 'next';
        final isBrighter = dir == 'next';
        await safeStateMutator(() {
          final selection = _container.read(selectedMonitorsProvider);
          final firstId = selection.firstOrNull ?? 'all';
          final settingsMap = _container.read(settingsProvider).value;
          final settings =
              settingsMap?[firstId] ?? settingsMap?['all'] ?? SettingsState();
          final currentType = settings.activePreset;
          final nextIndex = isBrighter
              ? (currentType.index + 1) % PresetType.values.length
              : (currentType.index - 1 + PresetType.values.length) %
                    PresetType.values.length;
          final nextPreset = PresetType.values[nextIndex];
          _container
              .read(settingsProvider.notifier)
              .setActivePreset(nextPreset);
          debugPrint(
            '[ApiControl] Action: cycle_preset | Selection: $selection | Old: ${currentType.name} -> New: ${nextPreset.name}',
          );
        });
        return _ActionResult.ok('cycle_preset', {'direction': dir});

      case 'set_game_mode':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          if (resolvedMonitorId == 'all') {
            _container
                .read(settingsProvider.notifier)
                .updateGameModeEnabled(enabled);
          } else {
            String targetDeviceName = resolvedMonitorId ?? 'all';
            if (resolvedMonitorId == 'primary') {
              final primary =
                  monitors.firstWhereOrNull((m) => m.isPrimary) ??
                  monitors.firstOrNull;
              if (primary != null) {
                targetDeviceName = primary.deviceName;
              }
            } else {
              final matched = monitors.firstWhereOrNull(
                (m) =>
                    m.id == resolvedMonitorId ||
                    m.deviceName == resolvedMonitorId,
              );
              if (matched != null) {
                targetDeviceName = matched.deviceName;
              }
            }
            _container
                .read(settingsProvider.notifier)
                .updateMonitorGameModeEnabled(targetDeviceName, enabled);
          }
        });
        return _ActionResult.ok('set_game_mode', {
          'enabled': enabled,
          'monitor': monitorIdInput,
        });

      case 'set_game_mode_brightness':
        final val = _toDouble(mutablePayload['value']);
        if (val == null || val < 0.0 || val > 100.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a number between 0.0 and 100.0.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateGameModeBrightness(val);
        });
        return _ActionResult.accepted('set_game_mode_brightness', {
          'value': val,
        });

      case 'manage_game_mode_whitelist':
        final op = mutablePayload['op'] as String?;
        final app = mutablePayload['app'] as String?;
        if (op == null ||
            app == null ||
            app.isEmpty ||
            (op != 'add' && op != 'remove')) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Fields 'op' ('add'/'remove') and 'app' (string) are required.",
          );
        }
        await safeStateMutator(() {
          if (op == 'add') {
            _container.read(settingsProvider.notifier).addWhitelistItem(app);
          } else {
            _container.read(settingsProvider.notifier).removeWhitelistItem(app);
          }
        });
        return _ActionResult.ok('manage_game_mode_whitelist', {
          'op': op,
          'app': app,
        });

      case 'set_monitor_offset':
        final offset = _toDouble(mutablePayload['offset']);
        if (offset == null || offset < -50.0 || offset > 50.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'offset' must be a double between -50.0 and +50.0.",
          );
        }
        final targetId = resolvedMonitorId ?? 'all';
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateMonitorOffset(targetId, offset);
        });
        return _ActionResult.accepted('set_monitor_offset', {
          'monitor_id': targetId,
          'offset': offset,
        });

      case 'set_weather_adjustment':
        final br = mutablePayload['brightness'] as bool?;
        final temp = mutablePayload['temperature'] as bool?;
        await safeStateMutator(() {
          if (br != null) {
            _container
                .read(settingsProvider.notifier)
                .updateWeatherAdjustment(br);
          }
          if (temp != null) {
            _container
                .read(settingsProvider.notifier)
                .updateWeatherTemperatureAdjustment(temp);
          }
        });
        return _ActionResult.ok('set_weather_adjustment', {
          'brightness': br,
          'temperature': temp,
        });

      case 'set_weather_temperature_adjustment':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateWeatherTemperatureAdjustment(enabled);
        });
        return _ActionResult.ok('set_weather_temperature_adjustment', {
          'enabled': enabled,
        });

      case 'set_weather_intensity':
        final val = _toDouble(mutablePayload['value']);
        if (val == null || val < 0.0 || val > 1.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a double between 0.0 and 1.0.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateWeatherAdjustmentIntensity(val);
        });
        return _ActionResult.accepted('set_weather_intensity', {'value': val});

      case 'set_smart_circadian':
        final enabled = mutablePayload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateSmartCircadian(enabled);
        });
        return _ActionResult.ok('set_smart_circadian', {'enabled': enabled});

      case 'set_smart_circadian_submodules':
        final windDown = mutablePayload['wind_down'] as bool?;
        final timeShift = mutablePayload['time_shift'] as bool?;
        final sleepPressure = mutablePayload['sleep_pressure'] as bool?;
        final sleepDebt = mutablePayload['sleep_debt'] as bool?;
        await safeStateMutator(() {
          if (windDown != null)
            _container
                .read(settingsProvider.notifier)
                .updateWindDownMaster(windDown);
          if (timeShift != null)
            _container
                .read(settingsProvider.notifier)
                .updateTimeShiftMaster(timeShift);
          if (sleepPressure != null)
            _container
                .read(settingsProvider.notifier)
                .updateSleepPressureMaster(sleepPressure);
          if (sleepDebt != null)
            _container
                .read(settingsProvider.notifier)
                .updateSleepDebtMaster(sleepDebt);
        });
        return _ActionResult.ok('set_smart_circadian_submodules', {
          'wind_down': windDown,
          'time_shift': timeShift,
          'sleep_pressure': sleepPressure,
          'sleep_debt': sleepDebt,
        });

      case 'set_map_animations':
        final rain = mutablePayload['rain'] as bool?;
        final snow = mutablePayload['snow'] as bool?;
        final thunder = mutablePayload['thunder'] as bool?;
        final cloud = mutablePayload['cloud'] as bool?;
        await safeStateMutator(() {
          if (rain != null)
            _container
                .read(settingsProvider.notifier)
                .updateShowRainAnimation(rain);
          if (snow != null)
            _container
                .read(settingsProvider.notifier)
                .updateShowSnowAnimation(snow);
          if (thunder != null)
            _container
                .read(settingsProvider.notifier)
                .updateShowThunderAnimation(thunder);
          if (cloud != null)
            _container
                .read(settingsProvider.notifier)
                .updateShowCloudAnimation(cloud);
        });
        return _ActionResult.ok('set_map_animations', {
          'rain': rain,
          'snow': snow,
          'thunder': thunder,
          'cloud': cloud,
        });

      case 'set_manual_location':
        final lat = _toDouble(mutablePayload['latitude']);
        final lon = _toDouble(mutablePayload['longitude']);
        if (lat == null ||
            lon == null ||
            lat < -90.0 ||
            lat > 90.0 ||
            lon < -180.0 ||
            lon > 180.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Fields 'latitude' [-90..90] and 'longitude' [-180..180] are required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(locationSettingsProvider.notifier)
              .setManualLocation(lat, lon);
        });
        return _ActionResult.ok('set_manual_location', {
          'latitude': lat,
          'longitude': lon,
        });

      case 'set_weather_provider':
        final providerStr = mutablePayload['provider'] as String?;
        final provider = _parseWeatherProvider(providerStr);
        if (provider == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'provider' must be one of: openMeteo, weatherApi, auto.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(settingsProvider.notifier)
              .updateWeatherProvider(provider);
        });
        return _ActionResult.ok('set_weather_provider', {
          'provider': providerStr,
        });

      case 'trigger_sun_sync':
        await safeStateMutator(() {
          _container.invalidate(currentWeatherProvider);
        });
        return _ActionResult.ok('trigger_sun_sync', {'synced': true});

      case 'push_sleep_status':
        final isSleeping = mutablePayload['is_sleeping'] as bool?;
        if (isSleeping == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'is_sleeping' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container
              .read(sleepProvider.notifier)
              .updatePushedSleepStatus(isSleeping);
        });
        return _ActionResult.ok('push_sleep_status', {
          'is_sleeping': isSleeping,
        });

      case 'manage_webhooks':
      case 'clear_failed_webhooks':
        final webhookId = mutablePayload['webhook_id'] as String?;
        if (webhookId == null || webhookId.isEmpty) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'webhook_id' (string) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(webhookServiceProvider.notifier).clearDLQ(webhookId);
        });
        return _ActionResult.ok('clear_failed_webhooks', {
          'webhook_id': webhookId,
        });

      default:
        return _ActionResult.error(
          HttpStatus.unprocessableEntity,
          'Unprocessable Entity',
          "Unknown action '$action'. Refer to OpenAPI documentation for supported actions.",
        );
    }
  }

  Future<void> _sendError(
    HttpRequest request,
    int statusCode,
    String title,
    String detail,
  ) async {
    final errorDto = Rfc7807Error(
      type:
          'https://solaris.local/errors/${statusCode == 404 ? 'not-found' : 'control-error'}',
      title: title,
      status: statusCode,
      detail: detail,
      instance: request.uri.path,
    );

    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType('application', 'problem+json')
      ..write(jsonEncode(errorDto.toJson()));
    await request.response.close();
  }

  double? _toDouble(dynamic val) {
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  int? _toInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  PresetType? _parsePresetType(String? str) {
    if (str == null) return null;
    switch (str.toLowerCase()) {
      case 'brightest':
        return PresetType.brightest;
      case 'bright':
        return PresetType.bright;
      case 'dim':
        return PresetType.dim;
      case 'dimmest':
        return PresetType.dimmest;
      default:
        return null;
    }
  }

  TemperaturePresetType? _parseTemperaturePresetType(String? str) {
    if (str == null) return null;
    switch (str.toLowerCase()) {
      case 'coolest':
        return TemperaturePresetType.coolest;
      case 'cool':
        return TemperaturePresetType.cool;
      case 'warm':
        return TemperaturePresetType.warm;
      case 'warmest':
        return TemperaturePresetType.warmest;
      default:
        return null;
    }
  }

  WeatherProvider? _parseWeatherProvider(String? str) {
    if (str == null) return null;
    switch (str.toLowerCase()) {
      case 'openmeteo':
        return WeatherProvider.openMeteo;
      case 'weatherapi':
        return WeatherProvider.weatherApi;
      case 'auto':
        return WeatherProvider.auto;
      default:
        return null;
    }
  }
}

class _ActionResult {
  final bool isError;
  final bool isDebounced;
  final int statusCode;
  final String errorTitle;
  final String errorMessage;
  final String action;
  final Map<String, dynamic> data;

  _ActionResult.ok(this.action, this.data)
    : isError = false,
      isDebounced = false,
      statusCode = 200,
      errorTitle = '',
      errorMessage = '';

  _ActionResult.accepted(this.action, this.data)
    : isError = false,
      isDebounced = true,
      statusCode = 202,
      errorTitle = '',
      errorMessage = '';

  _ActionResult.error(this.statusCode, this.errorTitle, this.errorMessage)
    : isError = true,
      isDebounced = false,
      action = '',
      data = const {};

  Map<String, dynamic> toResponseBody() {
    if (isError) {
      return {
        'status': 'error',
        'error': errorTitle.toLowerCase().replaceAll(' ', '_'),
        'message': errorMessage,
      };
    }
    if (isDebounced) {
      return {
        'status': 'accepted',
        'action': action,
        'queued': data,
        'note': 'Command queued; hardware will apply within ~200ms',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return {
      'status': 'ok',
      'action': action,
      'applied': data,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
