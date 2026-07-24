import 'dart:io';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/services/api_router.dart';

class PermissionCheckResult {
  final bool isAllowed;
  final String title;
  final String detail;

  const PermissionCheckResult.allow()
      : isAllowed = true,
        title = '',
        detail = '';

  const PermissionCheckResult.deny({
    required this.title,
    required this.detail,
  }) : isAllowed = false;
}

class ApiPermissionsChecker {
  /// Checks global Read-Only mode restriction.
  static PermissionCheckResult checkReadOnly(ApiPermissionsConfig config) {
    if (config.isReadOnly) {
      return const PermissionCheckResult.deny(
        title: 'Read-Only Mode Enabled',
        detail: 'API is currently running in Read-Only mode. Mutations are prohibited.',
      );
    }
    return const PermissionCheckResult.allow();
  }

  /// Checks if action category is allowed under current config.
  static PermissionCheckResult checkCategory(
    ApiPermissionsConfig config,
    ApiActionCategory? category,
  ) {
    final roCheck = checkReadOnly(config);
    if (!roCheck.isAllowed) return roCheck;

    if (category == null) {
      return const PermissionCheckResult.deny(
        title: 'Unknown Action Category',
        detail: 'The requested action does not belong to any recognized permission category.',
      );
    }

    if (!config.allowedCategories.contains(category)) {
      return PermissionCheckResult.deny(
        title: 'Action Category Prohibited',
        detail: 'Action category "${category.name}" is disabled in API permissions settings.',
      );
    }

    return const PermissionCheckResult.allow();
  }

  /// Checks if specific read permission flag is enabled.
  static PermissionCheckResult checkReadFlag(
    bool isFlagAllowed,
    String resourceName,
  ) {
    if (!isFlagAllowed) {
      return PermissionCheckResult.deny(
        title: 'Read Access Prohibited',
        detail: 'Access to resource "$resourceName" is disabled in API permissions settings.',
      );
    }
    return const PermissionCheckResult.allow();
  }

  /// Adapter for sending HTTP RFC 7807 error response if permission check is denied.
  static Future<bool> sendRfc7807IfDenied(
    HttpRequest request,
    PermissionCheckResult result,
  ) async {
    if (result.isAllowed) return false;
    final error = Rfc7807Error(
      type: 'https://solaris.local/errors/access-denied',
      title: result.title,
      status: HttpStatus.forbidden,
      detail: result.detail,
      instance: request.uri.path,
    );
    ApiRouter.sendRfc7807(request, error);
    return true;
  }
}
