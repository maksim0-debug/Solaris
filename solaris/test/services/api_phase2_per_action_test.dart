import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_permissions_checker.dart';
import 'package:solaris/services/openapi_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 2: ApiPermissionsChecker.checkAction Tests', () {
    test('checkAction denies when isReadOnly is true', () {
      const config = ApiPermissionsConfig(isReadOnly: true);
      final result = ApiPermissionsChecker.checkAction(
        config,
        'set_brightness',
      );

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Read-Only Mode Enabled'));
    });

    test('checkAction denies unknown action with 422 error details', () {
      const config = ApiPermissionsConfig();
      final result = ApiPermissionsChecker.checkAction(
        config,
        'invalid_action_xyz',
      );

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Unknown Action'));
      expect(result.detail, contains('not recognized'));
    });

    test('checkAction denies action if parent category is disabled', () {
      const config = ApiPermissionsConfig(
        allowedCategories: {ApiActionCategory.presets},
        allowedActions: {'set_brightness'}, // even if in allowedActions
      );
      final result = ApiPermissionsChecker.checkAction(
        config,
        'set_brightness',
      );

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Action Category Prohibited'));
      expect(result.detail, contains('monitors'));
    });

    test(
      'checkAction allows action when category is enabled and allowedActions is null',
      () {
        const config = ApiPermissionsConfig();
        final result = ApiPermissionsChecker.checkAction(
          config,
          'set_brightness',
        );

        expect(result.isAllowed, isTrue);
      },
    );

    test('checkAction denies action when missing from allowedActions set', () {
      const config = ApiPermissionsConfig(allowedActions: {'set_temperature'});
      final result = ApiPermissionsChecker.checkAction(
        config,
        'set_brightness',
      );

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Action Prohibited'));
      expect(result.detail, contains('set_brightness'));
    });

    test('checkAction allows action present in allowedActions set', () {
      const config = ApiPermissionsConfig(allowedActions: {'set_brightness'});
      final result = ApiPermissionsChecker.checkAction(
        config,
        'set_brightness',
      );

      expect(result.isAllowed, isTrue);
    });

    test('checkAction handles alias normalization correctly', () {
      const config = ApiPermissionsConfig(
        allowedActions: {'set_brightness_preset'},
      );
      // 'brightest' normalizes to 'set_brightness_preset'
      final result = ApiPermissionsChecker.checkAction(config, 'brightest');

      expect(result.isAllowed, isTrue);
    });

    test('checkAction denies alias when canonical action is excluded', () {
      const config = ApiPermissionsConfig(
        allowedActions: {'set_temperature_preset'},
      );
      // 'dim' normalizes to 'set_brightness_preset', which is excluded
      final result = ApiPermissionsChecker.checkAction(config, 'dim');

      expect(result.isAllowed, isFalse);
      expect(result.title, equals('Action Prohibited'));
    });
  });

  group(
    'Stage 2: ApiControlHandler Per-Action ACL & Alias Parameters Injection',
    () {
      late ProviderContainer container;
      late ApiControlHandler handler;

      setUp(() {
        container = ProviderContainer();
        handler = ApiControlHandler(container);
      });

      tearDown(() {
        container.dispose();
      });

      test(
        'executeAction denies action excluded from allowedActions',
        () async {
          const perms = ApiPermissionsConfig(
            allowedActions: {'set_temperature'},
          );

          final result = await handler.executeAction({
            'action': 'set_brightness',
            'value': 50,
          }, permissions: perms);

          expect(result['status'], equals('error'));
          expect(result['message'], contains('set_brightness'));
        },
      );

      test(
        'executeAction permits alias and injects parameter into payload',
        () async {
          const perms = ApiPermissionsConfig(
            allowedActions: {'set_brightness_preset'},
          );

          // Sending shorthand alias 'brightest' without preset key
          final result = await handler.executeAction({
            'action': 'brightest',
          }, permissions: perms);

          expect(result['status'], equals('ok'));
          expect(result['action'], equals('set_brightness_preset'));
          expect(result['applied']['preset'], equals('brightest'));
        },
      );

      test(
        'executeAction permits toggle alias without requiring enabled boolean',
        () async {
          const perms = ApiPermissionsConfig(
            allowedActions: {'set_auto_brightness'},
          );

          // Sending 'toggle_auto_brightness'
          final result = await handler.executeAction({
            'action': 'toggle_auto_brightness',
          }, permissions: perms);

          expect(result['status'], equals('ok'));
          expect(result['action'], equals('toggle_auto_brightness'));
        },
      );

      test(
        'executeAction permits webhook alias clear_failed_webhooks via manage_webhooks permission',
        () async {
          const perms = ApiPermissionsConfig(
            allowedActions: {'manage_webhooks'},
          );

          final result = await handler.executeAction({
            'action': 'clear_failed_webhooks',
            'webhook_id': 'wh_123',
          }, permissions: perms);

          expect(result['status'], equals('ok'));
          expect(result['action'], equals('clear_failed_webhooks'));
        },
      );
    },
  );

  group('Stage 2: OpenApiSpec allowedActions Reflection', () {
    test(
      'generateSpec includes AllowedActions in info description when active',
      () {
        const perms = ApiPermissionsConfig(
          allowedActions: {'set_brightness', 'set_temperature'},
        );

        final spec = OpenApiSpec.generateSpec(permissions: perms);
        final description = spec['info']['description'] as String;

        expect(description, contains('[Permissions Active]'));
        expect(
          description,
          contains('AllowedActions=[set_brightness, set_temperature]'),
        );
      },
    );
  });
}
