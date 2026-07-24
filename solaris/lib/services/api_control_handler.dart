import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

/// Безопасная мутация состояния Riverpod вне фазы рендеринга Flutter кадра.
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

/// Обработчик POST /api/v1/control
class ApiControlHandler {
  final ProviderContainer _container;

  ApiControlHandler(this._container);

  Future<void> handleControl(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
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

      if (jsonPayload.containsKey('actions') && jsonPayload['actions'] is List) {
        await _handleBatchControl(request, jsonPayload);
        return;
      }

      final actionResult = await _executeSingleAction(jsonPayload);
      if (actionResult.isError) {
        await _sendError(
          request,
          actionResult.statusCode,
          actionResult.errorTitle,
          actionResult.errorMessage,
        );
        return;
      }

      final statusCode = actionResult.isDebounced ? HttpStatus.accepted : HttpStatus.ok;
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
  ) async {
    final rawActions = jsonPayload['actions'] as List;
    final mode = (jsonPayload['mode'] as String?)?.toLowerCase() ?? 'fail_fast';

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

      final res = await _executeSingleAction(actionItem);
      results.add({'index': i, ...res.toResponseBody()});

      if (!res.isError) {
        successfulActions++;
      } else if (mode == 'fail_fast') {
        break;
      }
    }

    final responseBody = {
      'status': successfulActions == rawActions.length ? 'completed' : 'partial',
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

  Future<_ActionResult> _executeSingleAction(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    if (action == null || action.isEmpty) {
      return _ActionResult.error(
        HttpStatus.unprocessableEntity,
        'Missing Action',
        "Field 'action' is required.",
      );
    }

    final monitorIdInput = payload['monitor_id'] as String? ?? 'all';
    final resolvedMonitorId = MonitorSlugResolver.resolveToSystemId(monitorIdInput);

    if (resolvedMonitorId != 'all' && resolvedMonitorId != 'primary') {
      final monitors = _container.read(monitorListProvider).value ?? [];
      final exists = monitors.any((m) => m.id == resolvedMonitorId || m.deviceName == resolvedMonitorId);
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
        final val = _toDouble(payload['value']);
        if (val == null || val < 0.0 || val > 100.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a number between 0.0 and 100.0.",
          );
        }
        await safeStateMutator(() {
          _container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(false);
          _container.read(manualBrightnessProvider.notifier).update(val);
        });
        return _ActionResult.accepted('set_brightness', {'value': val, 'monitor_id': monitorIdInput});

      case 'set_auto_brightness':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(enabled);
        });
        return _ActionResult.ok('set_auto_brightness', {'enabled': enabled});

      case 'toggle_auto_brightness':
        await safeStateMutator(() {
          _container.read(autoBrightnessAdjustmentProvider.notifier).toggle();
        });
        final current = _container.read(autoBrightnessAdjustmentProvider);
        return _ActionResult.ok('toggle_auto_brightness', {'enabled': current});

      case 'set_temperature':
        final val = _toInt(payload['value']);
        if (val == null || val < 3300 || val > 6500) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be an integer Kelvin between 3300 and 6500.",
          );
        }
        await safeStateMutator(() {
          _container.read(temperatureSettingsProvider.notifier).toggleEnabled(false);
          _container.read(manualTemperatureProvider.notifier).setTemperature(val);
        });
        return _ActionResult.accepted('set_temperature', {'value': val, 'monitor_id': monitorIdInput});

      case 'set_color_temperature_enabled':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(isColorTemperatureEnabledProvider.notifier).set(enabled);
        });
        return _ActionResult.ok('set_color_temperature_enabled', {'enabled': enabled});

      case 'set_auto_temperature':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(temperatureSettingsProvider.notifier).toggleEnabled(enabled);
        });
        return _ActionResult.ok('set_auto_temperature', {'enabled': enabled});

      case 'toggle_auto_temperature':
        await safeStateMutator(() {
          _container.read(autoTemperatureAdjustmentProvider.notifier).toggle();
        });
        final current = _container.read(autoTemperatureAdjustmentProvider);
        return _ActionResult.ok('toggle_auto_temperature', {'enabled': current});

      case 'set_brightness_preset':
        final presetStr = payload['preset'] as String?;
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
        final presetStr = payload['preset'] as String?;
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
        return _ActionResult.ok('set_temperature_preset', {'preset': presetStr});

      case 'set_user_preset':
        final id = payload['id'] as String?;
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
        final dir = payload['direction'] as String? ?? 'next';
        final isBrighter = dir == 'next';
        await safeStateMutator(() {
          final settings = _container.read(settingsProvider).value?['all'] ?? SettingsState();
          final currentType = settings.activePreset;
          final nextIndex = isBrighter
              ? (currentType.index + 1) % PresetType.values.length
              : (currentType.index - 1 + PresetType.values.length) % PresetType.values.length;
          _container.read(settingsProvider.notifier).setActivePreset(PresetType.values[nextIndex]);
        });
        return _ActionResult.ok('cycle_preset', {'direction': dir});

      case 'set_game_mode':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateGameModeEnabled(enabled);
        });
        return _ActionResult.ok('set_game_mode', {'enabled': enabled});

      case 'set_game_mode_brightness':
        final val = _toDouble(payload['value']);
        if (val == null || val < 0.0 || val > 100.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a number between 0.0 and 100.0.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateGameModeBrightness(val);
        });
        return _ActionResult.accepted('set_game_mode_brightness', {'value': val});

      case 'manage_game_mode_whitelist':
        final op = payload['op'] as String?;
        final app = payload['app'] as String?;
        if (op == null || app == null || app.isEmpty || (op != 'add' && op != 'remove')) {
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
        return _ActionResult.ok('manage_game_mode_whitelist', {'op': op, 'app': app});

      case 'set_monitor_offset':
        final offset = _toDouble(payload['offset']);
        if (offset == null || offset < -50.0 || offset > 50.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'offset' must be a double between -50.0 and +50.0.",
          );
        }
        final targetId = resolvedMonitorId ?? 'all';
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateMonitorOffset(targetId, offset);
        });
        return _ActionResult.accepted('set_monitor_offset', {'monitor_id': targetId, 'offset': offset});

      case 'set_weather_adjustment':
        final br = payload['brightness'] as bool?;
        final temp = payload['temperature'] as bool?;
        await safeStateMutator(() {
          if (br != null) {
            _container.read(settingsProvider.notifier).updateWeatherAdjustment(br);
          }
          if (temp != null) {
            _container.read(settingsProvider.notifier).updateWeatherTemperatureAdjustment(temp);
          }
        });
        return _ActionResult.ok('set_weather_adjustment', {'brightness': br, 'temperature': temp});

      case 'set_weather_temperature_adjustment':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateWeatherTemperatureAdjustment(enabled);
        });
        return _ActionResult.ok('set_weather_temperature_adjustment', {'enabled': enabled});

      case 'set_weather_intensity':
        final val = _toDouble(payload['value']);
        if (val == null || val < 0.0 || val > 1.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'value' must be a double between 0.0 and 1.0.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateWeatherAdjustmentIntensity(val);
        });
        return _ActionResult.accepted('set_weather_intensity', {'value': val});

      case 'set_smart_circadian':
        final enabled = payload['enabled'] as bool?;
        if (enabled == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'enabled' (boolean) is required.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateSmartCircadian(enabled);
        });
        return _ActionResult.ok('set_smart_circadian', {'enabled': enabled});

      case 'set_smart_circadian_submodules':
        final windDown = payload['wind_down'] as bool?;
        final timeShift = payload['time_shift'] as bool?;
        final sleepPressure = payload['sleep_pressure'] as bool?;
        final sleepDebt = payload['sleep_debt'] as bool?;
        await safeStateMutator(() {
          if (windDown != null) _container.read(settingsProvider.notifier).updateWindDownMaster(windDown);
          if (timeShift != null) _container.read(settingsProvider.notifier).updateTimeShiftMaster(timeShift);
          if (sleepPressure != null) _container.read(settingsProvider.notifier).updateSleepPressureMaster(sleepPressure);
          if (sleepDebt != null) _container.read(settingsProvider.notifier).updateSleepDebtMaster(sleepDebt);
        });
        return _ActionResult.ok('set_smart_circadian_submodules', {
          'wind_down': windDown,
          'time_shift': timeShift,
          'sleep_pressure': sleepPressure,
          'sleep_debt': sleepDebt,
        });

      case 'set_map_animations':
        final rain = payload['rain'] as bool?;
        final snow = payload['snow'] as bool?;
        final thunder = payload['thunder'] as bool?;
        final cloud = payload['cloud'] as bool?;
        await safeStateMutator(() {
          if (rain != null) _container.read(settingsProvider.notifier).updateShowRainAnimation(rain);
          if (snow != null) _container.read(settingsProvider.notifier).updateShowSnowAnimation(snow);
          if (thunder != null) _container.read(settingsProvider.notifier).updateShowThunderAnimation(thunder);
          if (cloud != null) _container.read(settingsProvider.notifier).updateShowCloudAnimation(cloud);
        });
        return _ActionResult.ok('set_map_animations', {
          'rain': rain,
          'snow': snow,
          'thunder': thunder,
          'cloud': cloud,
        });

      case 'set_manual_location':
        final lat = _toDouble(payload['latitude']);
        final lon = _toDouble(payload['longitude']);
        if (lat == null || lon == null || lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Fields 'latitude' [-90..90] and 'longitude' [-180..180] are required.",
          );
        }
        await safeStateMutator(() {
          _container.read(locationSettingsProvider.notifier).setManualLocation(lat, lon);
        });
        return _ActionResult.ok('set_manual_location', {'latitude': lat, 'longitude': lon});

      case 'set_weather_provider':
        final providerStr = payload['provider'] as String?;
        final provider = _parseWeatherProvider(providerStr);
        if (provider == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'provider' must be one of: openMeteo, weatherApi, auto.",
          );
        }
        await safeStateMutator(() {
          _container.read(settingsProvider.notifier).updateWeatherProvider(provider);
        });
        return _ActionResult.ok('set_weather_provider', {'provider': providerStr});

      case 'trigger_sun_sync':
        await safeStateMutator(() {
          _container.invalidate(currentWeatherProvider);
        });
        return _ActionResult.ok('trigger_sun_sync', {'synced': true});

      case 'push_sleep_status':
        final isSleeping = payload['is_sleeping'] as bool?;
        if (isSleeping == null) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'is_sleeping' (boolean) is required.",
          );
        }
        final now = DateTime.now();
        final session = SleepSession(
          id: 'ipc_${now.millisecondsSinceEpoch}',
          startTime: isSleeping ? now : now.subtract(const Duration(hours: 8)),
          endTime: now,
          source: 'local_api',
        );
        await safeStateMutator(() {
          _container.read(sleepProvider.notifier).updateSessionsFromIpc([session]);
        });
        return _ActionResult.ok('push_sleep_status', {'is_sleeping': isSleeping});

      case 'clear_failed_webhooks':
        final webhookId = payload['webhook_id'] as String?;
        if (webhookId == null || webhookId.isEmpty) {
          return _ActionResult.error(
            HttpStatus.badRequest,
            'Validation Error',
            "Field 'webhook_id' (string) is required.",
          );
        }
        return _ActionResult.ok('clear_failed_webhooks', {'webhook_id': webhookId});

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
      type: 'https://solaris.app/errors/${statusCode == 404 ? 'not-found' : 'control-error'}',
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
