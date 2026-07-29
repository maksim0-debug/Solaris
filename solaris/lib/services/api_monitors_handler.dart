import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

/// Handler for per-monitor reading and control endpoints (/api/v1/monitors)
class ApiMonitorsHandler {
  final ProviderContainer _container;

  ApiMonitorsHandler(this._container);

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

  /// GET /api/v1/monitors
  Future<void> handleGetMonitors(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkReadFlag(
      permissions.allowReadMonitors,
      'monitors',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    try {
      final monitors = _container.read(monitorListProvider).value ?? [];
      MonitorSlugResolver.updateMonitors(monitors);

      final settingsMap =
          _container.read(settingsProvider).value ?? {'all': SettingsState()};
      final tempSettingsMap =
          _container.read(temperatureSettingsProvider).value ?? {};

      final isAutoBrightness = _container.read(
        autoBrightnessAdjustmentProvider,
      );
      final isAutoTemperature = _container.read(
        autoTemperatureAdjustmentProvider,
      );
      final isColorTempEnabled = _container.read(
        isColorTemperatureEnabledProvider,
      );
      final targetBrightness = _container.read(currentBrightnessProvider);
      final targetTemperature = _container.read(currentTemperatureProvider);

      final List<Map<String, dynamic>> monitorListJson = [];

      for (int i = 0; i < monitors.length; i++) {
        final m = monitors[i];
        final id = m.id;

        final mSettings =
            settingsMap[id] ?? settingsMap['all'] ?? SettingsState();
        final mTempSettings = tempSettingsMap[id] ?? tempSettingsMap['all'];

        final friendlySlug = 'display-${i + 1}';
        final edidHash = m.deviceIdHash.length >= 4
            ? m.deviceIdHash.substring(0, 4)
            : '0000';

        monitorListJson.add({
          'id': id,
          'name': m.deviceName,
          'friendly_name': m.friendlyName.isNotEmpty
              ? m.friendlyName
              : 'Display ${i + 1}',
          'slug': friendlySlug,
          'hardware_slug':
              '${m.friendlyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-$edidHash',
          'is_primary': m.isPrimary,
          'brightness': {
            'current': m.realBrightness ?? targetBrightness.round(),
            'target': targetBrightness,
            'offset': mSettings.brightnessOffset,
            'mode': isAutoBrightness ? 'auto' : 'manual',
            'active_preset': mSettings.activePreset.name,
            'active_user_preset': mSettings.activeUserPresetId,
          },
          'temperature': {
            'enabled': isColorTempEnabled,
            'current': m.realTemperature ?? targetTemperature,
            'target': targetTemperature,
            'mode': isAutoTemperature ? 'auto' : 'manual',
            'active_preset': mTempSettings?.activePreset.name ?? 'cool',
          },
        });
      }

      final responseBody = {
        'count': monitors.length,
        'monitors': monitorListJson,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseBody));
      await request.response.close();
    } catch (e) {
      debugPrint('[ApiMonitorsHandler] Error getting monitors: $e');
      await _sendError(
        request,
        HttpStatus.internalServerError,
        'Internal Error',
        e.toString(),
      );
    }
  }

  /// GET /api/v1/monitors/:slug
  Future<void> handleGetMonitorBySlug(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkReadFlag(
      permissions.allowReadMonitors,
      'monitors',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final rawSlug = pathParams['slug'] ?? '';
    if (rawSlug.isEmpty) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Missing Parameter',
        'Slug parameter is required.',
      );
      return;
    }

    final monitors = _container.read(monitorListProvider).value ?? [];
    MonitorSlugResolver.updateMonitors(monitors);

    final resolvedId = MonitorSlugResolver.resolveToSystemId(rawSlug);
    MonitorInfo? targetMonitor;

    for (final m in monitors) {
      if (m.id == resolvedId || m.id == rawSlug || m.deviceName == rawSlug) {
        targetMonitor = m;
        break;
      }
    }

    if (targetMonitor == null && resolvedId == 'primary') {
      targetMonitor = monitors.firstWhere(
        (m) => m.isPrimary,
        orElse: () => monitors.first,
      );
    }

    if (targetMonitor == null) {
      await _sendError(
        request,
        HttpStatus.notFound,
        'Monitor Not Found',
        "Monitor with slug or ID '$rawSlug' was not found.",
      );
      return;
    }

    final settingsMap =
        _container.read(settingsProvider).value ?? {'all': SettingsState()};
    final mSettings =
        settingsMap[targetMonitor.id] ?? settingsMap['all'] ?? SettingsState();

    final responseBody = {
      'id': targetMonitor.id,
      'name': targetMonitor.deviceName,
      'friendly_name': targetMonitor.friendlyName,
      'is_primary': targetMonitor.isPrimary,
      'real_brightness': targetMonitor.realBrightness,
      'real_temperature': targetMonitor.realTemperature,
      'brightness_offset': mSettings.brightnessOffset,
      'smart_circadian_enabled': mSettings.isSmartCircadianEnabled,
      'weather_adjustment_enabled': mSettings.isWeatherAdjustmentEnabled,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    await request.response.close();
  }

  /// POST /api/v1/monitors/:slug/brightness
  Future<void> handleSetMonitorBrightness(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);

    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'set_brightness',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final rawSlug = pathParams['slug'] ?? '';
    final resolvedId = MonitorSlugResolver.resolveToSystemId(rawSlug);

    final String content = await utf8.decoder.bind(request).join();
    final dynamic body = jsonDecode(content);

    if (body is! Map<String, dynamic> || !body.containsKey('value')) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Field 'value' is required.",
      );
      return;
    }

    final val = (body['value'] as num).toDouble();
    if (val < 0.0 || val > 100.0) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Field 'value' must be between 0.0 and 100.0.",
      );
      return;
    }

    await safeStateMutator(() {
      _container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      _container.read(manualBrightnessProvider.notifier).update(val);
    });

    final responseBody = {
      'status': 'accepted',
      'action': 'set_monitor_brightness',
      'slug': rawSlug,
      'target_monitor': resolvedId ?? rawSlug,
      'queued': {'value': val},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    request.response
      ..statusCode = HttpStatus.accepted
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    await request.response.close();
  }

  /// POST /api/v1/monitors/:slug/temperature
  Future<void> handleSetMonitorTemperature(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);

    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'set_temperature',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final rawSlug = pathParams['slug'] ?? '';
    final resolvedId = MonitorSlugResolver.resolveToSystemId(rawSlug);

    final String content = await utf8.decoder.bind(request).join();
    final dynamic body = jsonDecode(content);

    if (body is! Map<String, dynamic> || !body.containsKey('value')) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Field 'value' is required.",
      );
      return;
    }

    final val = (body['value'] as num).toInt();
    if (val < 3300 || val > 6500) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Field 'value' must be an integer Kelvin between 3300 and 6500.",
      );
      return;
    }

    await safeStateMutator(() {
      _container
          .read(temperatureSettingsProvider.notifier)
          .toggleEnabled(false);
      _container.read(manualTemperatureProvider.notifier).setTemperature(val);
    });

    final responseBody = {
      'status': 'accepted',
      'action': 'set_monitor_temperature',
      'slug': rawSlug,
      'target_monitor': resolvedId ?? rawSlug,
      'queued': {'value': val},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    request.response
      ..statusCode = HttpStatus.accepted
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    await request.response.close();
  }

  Future<void> _sendError(
    HttpRequest request,
    int statusCode,
    String title,
    String detail,
  ) async {
    final errorDto = Rfc7807Error(
      type: 'https://solaris.app/errors/monitors-error',
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
}
