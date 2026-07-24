import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/services/api_permissions_checker.dart';

void main() {
  group('ApiPermissionsChecker Unit Tests', () {
    test('checkReadOnly denies when isReadOnly is true', () {
      const config = ApiPermissionsConfig(isReadOnly: true);
      final result = ApiPermissionsChecker.checkReadOnly(config);

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Read-Only Mode Enabled'));
      expect(result.detail, contains('Read-Only mode'));
    });

    test('checkReadOnly allows when isReadOnly is false', () {
      const config = ApiPermissionsConfig(isReadOnly: false);
      final result = ApiPermissionsChecker.checkReadOnly(config);

      expect(result.isAllowed, isTrue);
    });

    test('checkCategory denies when category is null', () {
      const config = ApiPermissionsConfig();
      final result = ApiPermissionsChecker.checkCategory(config, null);

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Unknown Action Category'));
    });

    test('checkCategory denies when category is disabled in config', () {
      const config = ApiPermissionsConfig(
        allowedCategories: {ApiActionCategory.monitors},
      );
      final result = ApiPermissionsChecker.checkCategory(
        config,
        ApiActionCategory.gaming,
      );

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Action Category Prohibited'));
      expect(result.detail, contains('gaming'));
    });

    test('checkCategory allows when category is enabled', () {
      const config = ApiPermissionsConfig(
        allowedCategories: {ApiActionCategory.monitors},
      );
      final result = ApiPermissionsChecker.checkCategory(
        config,
        ApiActionCategory.monitors,
      );

      expect(result.isAllowed, isTrue);
    });

    test('checkReadFlag checks read permission flag correctly', () {
      final allowed = ApiPermissionsChecker.checkReadFlag(true, 'monitors');
      expect(allowed.isAllowed, isTrue);

      final denied = ApiPermissionsChecker.checkReadFlag(false, 'monitors');
      expect(denied.isAllowed, isFalse);
      expect(denied.title, equals('Read Access Prohibited'));
      expect(denied.detail, contains('monitors'));
    });
  });
}
