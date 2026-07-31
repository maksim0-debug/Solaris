import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/api_router.dart';

/// Handler for /api/v1/app-overrides endpoints
class ApiAppOverridesHandler {
  final ProviderContainer _container;

  ApiAppOverridesHandler(this._container);

  static final RegExp _exeRegex = RegExp(r'^[a-z0-9_\-\.]+\.exe$');

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

  /// GET /api/v1/app-overrides
  Future<void> handleGetAppOverrides(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'get_app_overrides',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final settingsMap = _container.read(settingsProvider).value;
    final settings = settingsMap?['all'] ?? SettingsState();

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'total': settings.appOverrides.length,
      'exit_delay_seconds': settings.appOverrideExitDelaySeconds,
      'app_overrides': settings.appOverrides.map((e) => e.toJson()).toList(),
    });
  }

  /// GET /api/v1/app-overrides/active
  Future<void> handleGetActiveOverride(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'get_app_overrides',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final activeState = _container.read(activeProcessServiceProvider);
    final settingsMap = _container.read(settingsProvider).value;
    final settings = settingsMap?['all'] ?? SettingsState();

    AppOverrideRule? appliedRule;
    if (activeState.activeProcess.isNotEmpty &&
        activeState.suppressedPids.isEmpty) {
      appliedRule = settings.appOverrides.firstWhereOrNull(
        (r) => r.exeName == activeState.activeProcess && r.isEnabled,
      );
    }

    final evalBrightness = _container.read(currentBrightnessProvider);
    final evalTemp = _container.read(currentTemperatureProvider);

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'active_process': activeState.activeProcess,
      'window_title': activeState.windowTitle,
      'is_gaming': activeState.isGaming,
      'applied_override': appliedRule?.toJson(),
      'evaluated_brightness': evalBrightness,
      'evaluated_temperature': evalTemp,
    });
  }

  /// POST /api/v1/app-overrides
  Future<void> handleCreateOrUpdateAppOverride(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'manage_app_overrides',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    try {
      final String content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) {
        _sendError(
          request,
          HttpStatus.badRequest,
          'Bad Request',
          'Request body cannot be empty.',
        );
        return;
      }

      final dynamic jsonPayload = jsonDecode(content);
      if (jsonPayload is! Map<String, dynamic>) {
        _sendError(
          request,
          HttpStatus.badRequest,
          'Invalid JSON',
          'JSON body must be an object.',
        );
        return;
      }

      final exeInput = jsonPayload['exeName'] as String?;
      if (exeInput == null || exeInput.trim().isEmpty) {
        _sendError(
          request,
          HttpStatus.badRequest,
          'Validation Error',
          "Field 'exeName' is required.",
        );
        return;
      }

      final cleanExe = exeInput.trim().toLowerCase();

      // Sanitization & Path Traversal Guard
      if (cleanExe.contains('/') ||
          cleanExe.contains('\\') ||
          cleanExe.contains('..')) {
        _sendError(
          request,
          HttpStatus.badRequest,
          'Validation Error',
          "Invalid 'exeName': path traversal characters are strictly prohibited.",
        );
        return;
      }

      if (!_exeRegex.hasMatch(cleanExe)) {
        _sendError(
          request,
          HttpStatus.badRequest,
          'Validation Error',
          "Invalid 'exeName': must be a valid executable filename ending in .exe (e.g. photoshop.exe).",
        );
        return;
      }

      final rule = AppOverrideRule.fromJson(jsonPayload);

      await safeStateMutator(() {
        _container.read(settingsProvider.notifier).addAppOverride(rule);
      });

      ApiRouter.sendJson(request, HttpStatus.ok, {
        'status': 'ok',
        'app_override': rule.toJson(),
      });
    } catch (e) {
      debugPrint(
        '[ApiAppOverridesHandler] Error creating/updating app override: $e',
      );
      _sendError(
        request,
        HttpStatus.badRequest,
        'Malformed Request',
        'Failed to parse app override payload: ${e.toString()}',
      );
    }
  }

  /// DELETE /api/v1/app-overrides/:exe
  Future<void> handleDeleteAppOverride(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'manage_app_overrides',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    final exeParam = pathParams['exe'];
    if (exeParam == null || exeParam.trim().isEmpty) {
      _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        'Target executable parameter is required.',
      );
      return;
    }

    final cleanExe = exeParam.trim().toLowerCase();

    // Sanitization & Path Traversal Guard
    if (cleanExe.contains('/') ||
        cleanExe.contains('\\') ||
        cleanExe.contains('..')) {
      _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Invalid 'exe': path traversal characters are strictly prohibited.",
      );
      return;
    }

    if (!_exeRegex.hasMatch(cleanExe)) {
      _sendError(
        request,
        HttpStatus.badRequest,
        'Validation Error',
        "Invalid 'exe': must be a valid executable filename ending in .exe.",
      );
      return;
    }

    await safeStateMutator(() {
      _container.read(settingsProvider.notifier).removeAppOverride(cleanExe);
    });

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'status': 'ok',
      'deleted_exe': cleanExe,
    });
  }

  /// POST /api/v1/app-overrides/reset-builtin
  Future<void> handleResetBuiltInAppOverrides(
    HttpRequest request,
    Map<String, String> pathParams,
  ) async {
    final permissions = _getPermissions(request);
    final check = ApiPermissionsChecker.checkAction(
      permissions,
      'reset_builtin_app_overrides',
    );
    if (await ApiPermissionsChecker.sendRfc7807IfDenied(request, check)) return;

    await safeStateMutator(() {
      _container.read(settingsProvider.notifier).resetBuiltInAppOverrides();
    });

    ApiRouter.sendJson(request, HttpStatus.ok, {
      'status': 'ok',
      'message': 'Built-in app override rules reset to factory defaults.',
    });
  }

  void _sendError(
    HttpRequest request,
    int statusCode,
    String title,
    String detail,
  ) {
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/app-overrides-error',
      title: title,
      status: statusCode,
      detail: detail,
      instance: request.uri.path,
    );
    ApiRouter.sendRfc7807(request, error);
  }
}
