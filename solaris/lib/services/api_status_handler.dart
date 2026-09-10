import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_permissions_filter.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';
import 'package:solaris/services/openapi_spec.dart';

class ApiStatusHandler {
  final ProviderContainer container;
  final DateTime _startTime = DateTime.now();

  ApiStatusHandler(this.container);

  int get uptimeSeconds => DateTime.now().difference(_startTime).inSeconds;

  ApiPermissionsConfig _getPermissions([HttpRequest? request]) {
    if (request != null && request.attachedPermissions != null) {
      return request.attachedPermissions!;
    }
    final settingsMap =
        container.read(settingsProvider).value ??
        container.read(settingsProvider).asData?.value;
    final globalSettings = settingsMap?['all'];
    return globalSettings?.apiPermissions ?? const ApiPermissionsConfig();
  }

  /// GET /api/v1/health
  Future<void> handleHealth(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final appVersionAsync = container.read(appVersionProvider);
    final version = appVersionAsync.value ?? fallbackAppVersion;
    final uptimeSeconds = this.uptimeSeconds;

    final settingsMap = container.read(settingsProvider).value;
    final globalSettings = settingsMap?['all'];
    final isApiEnabled = globalSettings?.isApiServerEnabled ?? false;
    final isSleepEnabled = globalSettings?.isSleepIpcServerEnabled ?? false;

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'status': 'ok',
      'version': version,
      'uptime_seconds': uptimeSeconds,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'subsystems': {
        'solaris_control': isApiEnabled,
        'sleep_integration': isSleepEnabled,
      },
    });
  }

  /// GET /api/v1/status
  Future<void> handleStatus(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);

    final appVersionAsync = container.read(appVersionProvider);
    final version = appVersionAsync.value ?? fallbackAppVersion;

    final solarStateAsync = container.read(solarStateStreamProvider);
    final solar = solarStateAsync.value;

    final weatherAsync = container.read(currentWeatherProvider);
    final weather = weatherAsync.value;

    final monitors = await container
        .read(monitorServiceProvider)
        .getConnectedMonitors();
    MonitorSlugResolver.updateMonitors(monitors);

    final settingsMap = container.read(settingsProvider).value;
    final globalSettings = settingsMap?['all'];

    final tempSettingsMap = container.read(temperatureSettingsProvider).value;
    final isColorTempEnabled = container.read(
      isColorTemperatureEnabledProvider,
    );
    final currentTemp = container.read(currentTemperatureProvider);

    final currentBrightness = container.read(currentBrightnessProvider);
    final autoBrightnessEnabled = container.read(
      autoBrightnessAdjustmentProvider,
    );
    final autoTempEnabled = container.read(autoTemperatureAdjustmentProvider);

    final sleepState = container.read(sleepProvider);
    final gamingModeActive = container.read(gamingModeProvider);
    final ipcState = container.read(localIpcServiceProvider);

    final smartCircadianData = container.read(
      smartCircadianDataProvider('all'),
    );

    final monitorsJson = monitors.map((mon) {
      final monSettings = settingsMap?[mon.id] ?? globalSettings;
      final monTempSettings =
          tempSettingsMap?[mon.id] ?? tempSettingsMap?['all'];

      return {
        'id': mon.id,
        'name': mon.name,
        'friendly_name': mon.friendlyName,
        'slug': MonitorSlugResolver.getSlugForSystemId(mon.id),
        'device_id_hash': mon.deviceIdHash,
        'is_primary': mon.isPrimary,
        'brightness': {
          'current': mon.realBrightness ?? currentBrightness.round(),
          'target': currentBrightness,
          'offset': monSettings?.brightnessOffset ?? 0.0,
          'mode': autoBrightnessEnabled ? 'auto' : 'manual',
          'active_preset': monSettings?.activePreset.name ?? 'bright',
          'active_user_preset': monSettings?.activeUserPresetId,
        },
        'temperature': {
          'enabled': isColorTempEnabled,
          'current': mon.realTemperature ?? currentTemp,
          'target': currentTemp,
          'mode': autoTempEnabled ? 'auto' : 'manual',
          'active_preset': monTempSettings?.activePreset.name ?? 'cool',
          'active_user_preset': monTempSettings?.activeUserPresetId,
        },
      };
    }).toList();

    final responseJson = <String, dynamic>{
      'version': version,
      'uptime_seconds': uptimeSeconds,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    if (permissions.allowReadSolar) {
      responseJson['solar'] = solar != null
          ? {
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
            }
          : null;
    }

    if (permissions.allowReadWeather) {
      responseJson['weather'] = weather != null
          ? {
              'available': true,
              'cloud_cover': weather.cloudCover,
              'temperature_celsius': weather.temperature,
              'weather_code': weather.weatherCode,
              'uv_index': weather.uvIndex,
              'provider': globalSettings?.weatherProvider.name ?? 'auto',
            }
          : {'available': false};
    }

    if (permissions.allowReadMonitors) {
      responseJson['monitors'] = monitorsJson;
    }

    final rawAutomation = {
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
        'whitelist_count': globalSettings?.gameModeWhitelist.length ?? 0,
        'blacklist_count': globalSettings?.gameModeBlacklist.length ?? 0,
      },
      'multi_monitor_offset':
          globalSettings?.isMultiMonitorOffsetEnabled ?? false,
      'map_animations': {
        'rain': globalSettings?.showRainAnimation ?? true,
        'snow': globalSettings?.showSnowAnimation ?? true,
        'thunder': globalSettings?.showThunderAnimation ?? true,
        'cloud': globalSettings?.showCloudAnimation ?? true,
      },
    };
    responseJson['automation'] = ApiPermissionsFilter.filterAutomation(
      rawAutomation,
      permissions,
    );

    if (permissions.allowReadCircadian) {
      final rawSmartCircadian = {
        'master_enabled': globalSettings?.isSmartCircadianEnabled ?? false,
        'submodules': {
          'wind_down_master': globalSettings?.isWindDownMasterEnabled ?? true,
          'time_shift_master': globalSettings?.isTimeShiftMasterEnabled ?? true,
          'sleep_pressure_master':
              globalSettings?.isSleepPressureMasterEnabled ?? true,
          'sleep_debt_master': globalSettings?.isSleepDebtMasterEnabled ?? true,
        },
        'wind_down': {
          'active': smartCircadianData.isWindDownActive,
          'impact_brightness': smartCircadianData.windDownAbsoluteImpact,
          'impact_temperature': smartCircadianData.windDownTemperatureImpact,
        },
        'sleep_pressure': {
          'active': smartCircadianData.isSleepPressureActive,
          'impact_brightness': smartCircadianData.sleepPressureAbsoluteImpact,
          'impact_temperature':
              smartCircadianData.sleepPressureTemperatureImpact,
        },
        'sleep_debt': {
          'active': smartCircadianData.isSleepDebtActive,
          'impact_brightness': smartCircadianData.sleepDebtAbsoluteImpact,
          'impact_temperature': smartCircadianData.sleepDebtTemperatureImpact,
        },
        'time_shift': {
          'active': smartCircadianData.isTimeShiftActive,
          'offset_minutes': smartCircadianData.timeOffset.inMinutes,
        },
      };
      final filteredCircadian = ApiPermissionsFilter.filterSmartCircadian(
        rawSmartCircadian,
        permissions,
      );
      if (filteredCircadian != null) {
        responseJson['smart_circadian'] = filteredCircadian;
      }
    }

    if (permissions.allowReadSleep) {
      responseJson['sleep'] = {
        'is_sleeping': sleepState.isCurrentlySleeping,
        'sessions_count': sleepState.sessions.length,
        'last_session_end': sleepState.lastSessionEnd?.toIso8601String(),
      };
    }

    if (permissions.allowedCategories.contains(ApiActionCategory.system)) {
      responseJson['server'] = {
        'port': ipcState.port ?? globalSettings?.apiServerPort ?? 45321,
        'bind_address': globalSettings?.isApiLanAccessEnabled == true
            ? '0.0.0.0'
            : '127.0.0.1',
        'lan_access': globalSettings?.isApiLanAccessEnabled ?? false,
        'rate_limit_per_minute': globalSettings?.apiRateLimitPerMinute ?? 120,
      };
    }

    ApiRouter.sendJson(request, HttpStatus.ok, responseJson);
  }

  /// GET /api/v1/solar
  Future<void> handleSolar(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkReadFlag(
      permissions.allowReadSolar,
      'solar',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final solar = container.read(solarStateStreamProvider).value;
    if (solar == null) {
      ApiRouter.sendJson(request, HttpStatus.ok, {
        'available': false,
        'message': 'Solar calculations pending.',
      });
      return;
    }

    ApiRouter.sendJson(request, HttpStatus.ok, {
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
      'trends': {
        'elevation': solar.elevationTrend,
        'azimuth': solar.azimuthTrend,
        'zenith': solar.zenithTrend,
      },
    });
  }

  /// GET /api/v1/presets
  Future<void> handlePresets(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final settings = container.read(settingsProvider).value?['all'];
    final tempSettings = container
        .read(temperatureSettingsProvider)
        .value?['all'];

    final rawPresets = {
      'brightness': {
        'system': PresetType.values.map((e) => e.name).toList(),
        'user':
            settings?.userPresets
                .map(
                  (p) => {
                    'id': p.id,
                    'name': p.name,
                    'active': p.id == settings.activeUserPresetId,
                  },
                )
                .toList() ??
            [],
        'active': {
          'type': settings?.activeUserPresetId != null ? 'user' : 'system',
          'name':
              settings?.activeUserPresetId ??
              settings?.activePreset.name ??
              'bright',
        },
      },
      'temperature': {
        'system': TemperaturePresetType.values.map((e) => e.name).toList(),
        'user':
            tempSettings?.userPresets
                .map(
                  (p) => {
                    'id': p.id,
                    'name': p.name,
                    'active': p.id == tempSettings.activeUserPresetId,
                  },
                )
                .toList() ??
            [],
        'active': {
          'type': tempSettings?.activeUserPresetId != null ? 'user' : 'system',
          'name':
              tempSettings?.activeUserPresetId ??
              tempSettings?.activePreset.name ??
              'cool',
        },
      },
    };

    final filtered = ApiPermissionsFilter.filterPresets(
      rawPresets,
      permissions,
    );
    if (filtered == null) {
      final check = ApiPermissionsChecker.checkReadFlag(false, 'presets');
      await ApiPermissionsChecker.sendRfc7807IfDenied(request, check);
      return;
    }

    ApiRouter.sendJson(request, HttpStatus.ok, filtered);
  }

  /// GET /api/v1/sleep/sessions (Paginated)
  Future<void> handleSleepSessions(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkReadFlag(
      permissions.allowReadSleep,
      'sleep',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;
    final query = request.uri.queryParameters;
    final limitParam = int.tryParse(query['limit'] ?? '50') ?? 50;
    final limit = limitParam.clamp(1, 200);
    final offsetParam = int.tryParse(query['offset'] ?? '0') ?? 0;
    final offset = offsetParam < 0 ? 0 : offsetParam;

    final fromStr = query['from'];
    final toStr = query['to'];
    final fromDate = fromStr != null ? DateTime.tryParse(fromStr) : null;
    final toDate = toStr != null ? DateTime.tryParse(toStr) : null;

    final sleepState = container.read(sleepProvider);
    var filtered = sleepState.sessions.toList();

    if (fromDate != null) {
      filtered = filtered
          .where(
            (s) =>
                s.startTime.isAfter(fromDate) ||
                s.startTime.isAtSameMomentAs(fromDate),
          )
          .toList();
    }
    if (toDate != null) {
      filtered = filtered
          .where(
            (s) =>
                s.startTime.isBefore(toDate) ||
                s.startTime.isAtSameMomentAs(toDate),
          )
          .toList();
    }

    final total = filtered.length;
    final paginated = filtered
        .skip(offset)
        .take(limit)
        .map(
          (s) => {
            'id': s.id,
            'start_time': s.startTime.toIso8601String(),
            'end_time': s.endTime.toIso8601String(),
            'duration_minutes': s.duration.inMinutes,
            'source': s.source,
          },
        )
        .toList();

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'total': total,
      'limit': limit,
      'offset': offset,
      'sessions': paginated,
    });
  }

  /// GET /api/v1/docs (Interactive OpenAPI Docs / RapiDoc HTML)
  Future<void> handleDocs(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Solaris Control API Documentation</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script type="module" src="https://unpkg.com/rapidoc/dist/rapidoc-min.js"></script>
</head>
<body>
  <rapi-doc
    spec-url="/api/v1/openapi.json"
    theme="dark"
    bg-color="#0f172a"
    text-color="#f8fafc"
    primary-color="#38bdf8"
    render-style="read"
    show-header="true"
    allow-authentication="true"
    allow-server-selection="true"
  > </rapi-doc>
</body>
</html>
''';

    try {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(html);
      await request.response.close();
    } catch (e) {
      debugPrint('ApiStatusHandler: Error serving docs HTML: $e');
    }
  }

  /// GET /api/v1/openapi.json
  Future<void> handleOpenApiJson(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final settingsMap =
        container.read(settingsProvider).value ??
        container.read(settingsProvider).asData?.value;
    final port = settingsMap?['all']?.apiServerPort ?? 45321;
    final jsonSpec = OpenApiSpec.generateSpec(
      port: port,
      permissions: permissions,
    );
    ApiRouter.sendJson(request, HttpStatus.ok, jsonSpec);
  }
}
