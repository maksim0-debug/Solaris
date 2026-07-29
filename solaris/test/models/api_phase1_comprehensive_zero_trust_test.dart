import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';

void main() {
  group('Zero-Trust Phase 1 Verification Suite', () {
    // ------------------------------------------------------------------------
    // 1. BDD / Behavior-Driven Specifications
    // ------------------------------------------------------------------------
    group('BDD Scenarios: Granular Permission Rules & Aliases', () {
      test('Given an API Key with allowedActions set to only set_brightness, '
          'When set_brightness or its alias set_monitor_brightness is requested, '
          'Then access is granted, but set_temperature is denied', () {
        // Given
        final config = ApiPermissionsConfig(allowedActions: {'set_brightness'});

        // When & Then
        expect(
          config.isActionAllowed('set_brightness'),
          isTrue,
          reason: 'Canonical action should be permitted',
        );
        expect(
          config.isActionAllowed('set_monitor_brightness'),
          isTrue,
          reason: 'Alias of permitted canonical action should be allowed',
        );
        expect(
          config.isActionAllowed('set_temperature'),
          isFalse,
          reason: 'Unlisted action in same category should be denied',
        );
      });

      test(
        'Given an API Key with allowedActions containing set_brightness_preset, '
        'When shorthand aliases (brightest, dim, etc.) are evaluated, '
        'Then all map to set_brightness_preset and are allowed',
        () {
          // Given
          final config = ApiPermissionsConfig(
            allowedActions: {'set_brightness_preset'},
          );

          // When & Then
          final aliases = ['brightest', 'bright', 'dim', 'dimmest'];
          for (final alias in aliases) {
            expect(
              config.isActionAllowed(alias),
              isTrue,
              reason: 'Alias "$alias" must map to set_brightness_preset',
            );
          }

          // Temperature preset aliases should remain forbidden
          final tempAliases = ['coolest', 'cool', 'warm', 'warmest'];
          for (final alias in tempAliases) {
            expect(
              config.isActionAllowed(alias),
              isFalse,
              reason:
                  'Alias "$alias" must not be allowed when set_temperature_preset is missing',
            );
          }
        },
      );

      test('Given an API Key with allowedActions set to clear_failed_webhooks, '
          'When getCanonicalAction and isActionAllowed are invoked, '
          'Then it normalizes to manage_webhooks in category system', () {
        // Given
        final canonicalFromAlias = ApiPermissionsConfig.getCanonicalAction(
          'clear_failed_webhooks',
        );
        expect(canonicalFromAlias, equals('manage_webhooks'));

        final config = ApiPermissionsConfig(
          allowedActions: {'manage_webhooks'},
        );

        // When & Then
        expect(config.isActionAllowed('clear_failed_webhooks'), isTrue);
        expect(config.isActionAllowed('manage_webhooks'), isTrue);
        expect(
          ApiPermissionsConfig.getCategoryForAction('clear_failed_webhooks'),
          equals(ApiActionCategory.system),
        );
      });

      test(
        'Given an API Key in Read-Only mode, '
        'When any action or alias is requested, '
        'Then isActionAllowed always returns false regardless of allowedActions',
        () {
          // Given
          final allCanonical = ApiPermissionsConfig.getAllCanonicalActions();
          final config = ApiPermissionsConfig(
            isReadOnly: true,
            allowedActions: allCanonical,
          );

          // When & Then
          for (final action in allCanonical) {
            expect(
              config.isActionAllowed(action),
              isFalse,
              reason:
                  'Read-only mode must override allowedActions for "$action"',
            );
          }
        },
      );
    });

    // ------------------------------------------------------------------------
    // 2. Property-Based Testing (PBT)
    // ------------------------------------------------------------------------
    group('Property-Based Testing (PBT): Randomized Subsets & Invariants', () {
      final random = Random(42);
      final allCanonicalList = ApiPermissionsConfig.getAllCanonicalActions()
          .toList();

      test(
        'PBT Invariant: For any subset of actions S, isActionAllowed(a) is true iff canonical(a) in S',
        () {
          for (var i = 0; i < 100; i++) {
            // Shuffle and pick a random subset size between 1 and 24
            final subsetSize = random.nextInt(24) + 1;
            final shuffled = List<String>.from(allCanonicalList)
              ..shuffle(random);
            final selectedSubset = shuffled.take(subsetSize).toSet();

            final config = ApiPermissionsConfig(allowedActions: selectedSubset);

            // Verify every single canonical action
            for (final canonical in allCanonicalList) {
              final expected = selectedSubset.contains(canonical);
              expect(
                config.isActionAllowed(canonical),
                equals(expected),
                reason:
                    'PBT Iteration $i failed for action $canonical with subset $selectedSubset',
              );
            }
          }
        },
      );

      test(
        'PBT Invariant: Roundtrip JSON serialization maintains equality and null reset invariant',
        () {
          for (var i = 0; i < 100; i++) {
            final subsetSize = random.nextInt(25); // 0 to 24 actions
            final shuffled = List<String>.from(allCanonicalList)
              ..shuffle(random);
            final selectedSubset = subsetSize == 0
                ? <String>{}
                : shuffled.take(subsetSize).toSet();

            final original = ApiPermissionsConfig(
              allowedActions: selectedSubset,
              allowReadMonitors: random.nextBool(),
              allowReadSolar: random.nextBool(),
              allowReadWeather: random.nextBool(),
              allowReadSleep: random.nextBool(),
              allowReadCircadian: random.nextBool(),
              isReadOnly: random.nextBool(),
            );

            final json = original.toJson();
            final restored = ApiPermissionsConfig.fromJson(json);

            expect(
              restored,
              equals(original),
              reason: 'PBT Roundtrip failed on iteration $i',
            );
            expect(restored.hashCode, equals(original.hashCode));
          }
        },
      );
    });

    // ------------------------------------------------------------------------
    // 3. Mutation Testing & Edge Case Defense
    // ------------------------------------------------------------------------
    group('Edge Cases & Zero-Trust Malformed JSON Payload Defense', () {
      test(
        'fromJson robustly handles malformed non-list and non-string values without throwing',
        () {
          final malformedPayloads = [
            {'allowedCategories': 12345, 'allowedActions': 'not_a_list'},
            {'allowedCategories': true, 'allowedActions': 99.99},
            {
              'allowedCategories': {'key': 'val'},
              'allowedActions': {'nested': 'object'},
            },
            {
              'allowedCategories': ['monitors', 999, null, 'invalid_cat'],
              'allowedActions': [
                'set_brightness',
                123,
                null,
                true,
                'non_existent_action_xyz',
              ],
            },
          ];

          for (final payload in malformedPayloads) {
            expect(
              () => ApiPermissionsConfig.fromJson(payload),
              returnsNormally,
            );
            final restored = ApiPermissionsConfig.fromJson(payload);
            expect(restored.allowedCategories, isNotNull);
          }
        },
      );

      test('toJson sanitizes orphaned actions from disabled categories', () {
        // Given: allowedActions has set_brightness (category monitors), but allowedCategories excludes monitors
        final config = ApiPermissionsConfig(
          allowedCategories: {ApiActionCategory.presets},
          allowedActions: {'set_brightness', 'set_brightness_preset'},
        );

        final json = config.toJson();
        final restored = ApiPermissionsConfig.fromJson(json);

        // set_brightness should be excluded from sanitized JSON because its parent category is not allowed
        expect(config.isActionAllowed('set_brightness'), isFalse);
        expect(config.isActionAllowed('set_brightness_preset'), isTrue);
        expect(restored.isActionAllowed('set_brightness'), isFalse);
        expect(restored.isActionAllowed('set_brightness_preset'), isTrue);

        if (json.containsKey('allowedActions')) {
          final actionsInJson = (json['allowedActions'] as List<dynamic>)
              .cast<String>();
          expect(actionsInJson, contains('set_brightness_preset'));
          expect(actionsInJson, isNot(contains('set_brightness')));
        }
      });

      test(
        'Clean Storage Protocol: 25 canonical actions automatically serialize to null allowedActions',
        () {
          final all25 = ApiPermissionsConfig.getAllCanonicalActions();
          final config = ApiPermissionsConfig(allowedActions: all25);

          final json = config.toJson();
          expect(
            json.containsKey('allowedActions'),
            isFalse,
            reason:
                'JSON must omit allowedActions key when all 25 actions are enabled',
          );

          final restored = ApiPermissionsConfig.fromJson(json);
          expect(restored.allowedActions, isNull);
          expect(restored, equals(const ApiPermissionsConfig()));
        },
      );

      test('Set order does not affect operator == or hashCode calculation', () {
        final setA = {'set_brightness', 'set_temperature', 'push_sleep_status'};
        final setB = {'push_sleep_status', 'set_brightness', 'set_temperature'};

        final configA = ApiPermissionsConfig(allowedActions: setA);
        final configB = ApiPermissionsConfig(allowedActions: setB);

        expect(configA, equals(configB));
        expect(configA.hashCode, equals(configB.hashCode));
      });
    });
  });
}
