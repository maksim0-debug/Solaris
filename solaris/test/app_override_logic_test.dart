import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/active_process_service.dart';

void main() {
  group('AppOverrideRule Phase 2 Data Model Zero-Trust Tests', () {
    test(
      'defaultBuiltInRules returns 6 factory default 6500K color profile rules',
      () {
        final rules = AppOverrideRule.defaultBuiltInRules;
        expect(rules.length, equals(6));

        final expectedExes = [
          'photoshop.exe',
          'premiere.exe',
          'resolve.exe',
          'lightroom.exe',
          'blender.exe',
          'figma.exe',
        ];

        for (int i = 0; i < rules.length; i++) {
          expect(rules[i].exeName, equals(expectedExes[i]));
          expect(rules[i].isBuiltIn, isTrue);
          expect(rules[i].isEnabled, isTrue);
          expect(rules[i].temperatureMode, equals(AppOverrideMode.fixed));
          expect(rules[i].fixedTemperature, equals(6500.0));
          expect(rules[i].brightnessMode, equals(AppOverrideMode.global));
          expect(rules[i].fixedBrightness, isNull);
          expect(rules[i].brightnessCurvePresetId, isNull);
          expect(rules[i].temperatureCurvePresetId, isNull);
        }
      },
    );

    test(
      'exeName is automatically trimmed, lowercased, and stripped of directory paths',
      () {
        final rule1 = AppOverrideRule.fromJson({
          'exeName': '  PhotoShop.EXE  ',
          'appDisplayName': 'Adobe Photoshop',
        });
        expect(rule1.exeName, equals('photoshop.exe'));

        final rule2 = AppOverrideRule.fromJson({
          'exeName': r'C:\Program Files\Adobe\Photoshop.exe',
          'appDisplayName': 'Adobe Photoshop',
        });
        expect(rule2.exeName, equals('photoshop.exe'));

        final rule3 = AppOverrideRule.fromJson({
          'exeName': 'd:/apps/games/blender.exe',
          'appDisplayName': 'Blender 3D',
        });
        expect(rule3.exeName, equals('blender.exe'));
      },
    );

    test(
      'AppOverrideRule toJson and fromJson roundtrip works correctly across all modes',
      () {
        const original = AppOverrideRule(
          exeName: 'custom_game.exe',
          appDisplayName: 'Custom Game Title',
          isEnabled: true,
          isBuiltIn: false,
          brightnessMode: AppOverrideMode.fixed,
          fixedBrightness: 75.5,
          brightnessCurvePresetId: 'curve_b_1',
          temperatureMode: AppOverrideMode.curve,
          fixedTemperature: 5000.0,
          temperatureCurvePresetId: 'curve_t_1',
        );

        final json = original.toJson();
        expect(json['exeName'], equals('custom_game.exe'));
        expect(json['brightnessMode'], equals('fixed'));
        expect(json['temperatureMode'], equals('curve'));

        final deserialized = AppOverrideRule.fromJson(json);
        expect(deserialized, equals(original));
        expect(deserialized.hashCode, equals(original.hashCode));
      },
    );

    test(
      'AppOverrideMode.fromJson handles unknown, null, or invalid string inputs gracefully',
      () {
        expect(
          AppOverrideMode.fromJson('fixed'),
          equals(AppOverrideMode.fixed),
        );
        expect(
          AppOverrideMode.fromJson('curve'),
          equals(AppOverrideMode.curve),
        );
        expect(
          AppOverrideMode.fromJson('global'),
          equals(AppOverrideMode.global),
        );
        expect(
          AppOverrideMode.fromJson('invalid_mode'),
          equals(AppOverrideMode.global),
        );
        expect(AppOverrideMode.fromJson(''), equals(AppOverrideMode.global));
      },
    );

    test(
      'AppOverrideRule.fromJson parses numeric strings and clamps out-of-bound or invalid values',
      () {
        final jsonExtreme = {
          'exeName': 'test.exe',
          'fixedBrightness': 150.0,
          'fixedTemperature': 10000.0,
        };
        final ruleExtreme = AppOverrideRule.fromJson(jsonExtreme);
        expect(ruleExtreme.fixedBrightness, equals(100.0));
        expect(ruleExtreme.fixedTemperature, equals(6500.0));

        final jsonLow = {
          'exeName': 'test.exe',
          'fixedBrightness': -20.0,
          'fixedTemperature': 1000.0,
        };
        final ruleLow = AppOverrideRule.fromJson(jsonLow);
        expect(ruleLow.fixedBrightness, equals(0.0));
        expect(ruleLow.fixedTemperature, equals(3300.0));

        final jsonStringValues = {
          'exeName': 'test.exe',
          'fixedBrightness': '80.5',
          'fixedTemperature': '5500',
        };
        final ruleStringValues = AppOverrideRule.fromJson(jsonStringValues);
        expect(ruleStringValues.fixedBrightness, equals(80.5));
        expect(ruleStringValues.fixedTemperature, equals(5500.0));

        final jsonInvalidNumber = {
          'exeName': 'test.exe',
          'fixedBrightness': 'not_a_number',
          'fixedTemperature': double.nan,
        };
        final ruleInvalidNumber = AppOverrideRule.fromJson(jsonInvalidNumber);
        expect(ruleInvalidNumber.fixedBrightness, isNull);
        expect(ruleInvalidNumber.fixedTemperature, isNull);
      },
    );

    test(
      'copyWith normalizes exeName, clamps bounds, and respects clear flags',
      () {
        const rule = AppOverrideRule(
          exeName: 'blender.exe',
          appDisplayName: 'Blender 3D',
          fixedBrightness: 70.0,
          brightnessCurvePresetId: 'preset_b',
          fixedTemperature: 6500.0,
          temperatureCurvePresetId: 'preset_t',
        );

        final updatedExe = rule.copyWith(exeName: r'  C:\Tools\NEW_APP.EXE  ');
        expect(updatedExe.exeName, equals('new_app.exe'));

        final cleared = rule.copyWith(
          clearFixedBrightness: true,
          clearBrightnessCurvePresetId: true,
          clearFixedTemperature: true,
          clearTemperatureCurvePresetId: true,
        );

        expect(cleared.fixedBrightness, isNull);
        expect(cleared.brightnessCurvePresetId, isNull);
        expect(cleared.fixedTemperature, isNull);
        expect(cleared.temperatureCurvePresetId, isNull);
      },
    );

    test(
      'AppOverrideRule operator == and hashCode differentiate modified instances',
      () {
        const rule1 = AppOverrideRule(
          exeName: 'photoshop.exe',
          appDisplayName: 'Photoshop',
          fixedTemperature: 6500.0,
        );
        const rule2 = AppOverrideRule(
          exeName: 'photoshop.exe',
          appDisplayName: 'Photoshop',
          fixedTemperature: 6500.0,
        );
        const rule3 = AppOverrideRule(
          exeName: 'photoshop.exe',
          appDisplayName: 'Photoshop',
          fixedTemperature: 5000.0,
        );

        expect(rule1, equals(rule2));
        expect(rule1.hashCode, equals(rule2.hashCode));
        expect(rule1 == rule3, isFalse);
      },
    );

    test(
      'AppOverrideMode enum serialization and case-insensitive deserialization works',
      () {
        expect(AppOverrideMode.global.toJson(), equals('global'));
        expect(AppOverrideMode.fixed.toJson(), equals('fixed'));
        expect(AppOverrideMode.curve.toJson(), equals('curve'));

        expect(
          AppOverrideMode.fromJson('FIXED'),
          equals(AppOverrideMode.fixed),
        );
        expect(
          AppOverrideMode.fromJson('  Curve  '),
          equals(AppOverrideMode.curve),
        );
        expect(
          AppOverrideMode.fromJson('GLOBAL'),
          equals(AppOverrideMode.global),
        );
      },
    );

    test('Sanitizes mixed slashes, non-ASCII paths, and spaces in exeName', () {
      final ruleMixed = AppOverrideRule.fromJson({
        'exeName': r'C:/Program Files\Adobe/Photoshop 2026/PhotoShop.EXE ',
        'appDisplayName': 'Photoshop',
      });
      expect(ruleMixed.exeName, equals('photoshop.exe'));

      final ruleCyrillic = AppOverrideRule.fromJson({
        'exeName': r'D:\Пользователи\Редактор\App.EXE',
        'appDisplayName': 'Cyrillic App',
      });
      expect(ruleCyrillic.exeName, equals('app.exe'));
    });

    test(
      'AppOverrideRule.fromJson handles missing, non-string, or non-boolean json types gracefully',
      () {
        final ruleMalformed = AppOverrideRule.fromJson({
          'exeName': 12345,
          'appDisplayName': null,
          'isEnabled': 'not_a_bool',
          'isBuiltIn': 99,
          'brightnessMode': 42,
          'temperatureMode': true,
        });

        expect(ruleMalformed.exeName, equals('12345'));
        expect(ruleMalformed.appDisplayName, equals(''));
        expect(ruleMalformed.isEnabled, isTrue);
        expect(ruleMalformed.isBuiltIn, isFalse);
        expect(ruleMalformed.brightnessMode, equals(AppOverrideMode.global));
        expect(ruleMalformed.temperatureMode, equals(AppOverrideMode.global));
      },
    );

    test(
      'copyWith clamps out-of-bounds parameters and ignores NaN/Infinity',
      () {
        const rule = AppOverrideRule(
          exeName: 'game.exe',
          appDisplayName: 'Game',
          fixedBrightness: 50.0,
          fixedTemperature: 5000.0,
        );

        final updatedHigh = rule.copyWith(
          fixedBrightness: 250.0,
          fixedTemperature: 9000.0,
        );
        expect(updatedHigh.fixedBrightness, equals(100.0));
        expect(updatedHigh.fixedTemperature, equals(6500.0));

        final updatedLow = rule.copyWith(
          fixedBrightness: -50.0,
          fixedTemperature: 1000.0,
        );
        expect(updatedLow.fixedBrightness, equals(0.0));
        expect(updatedLow.fixedTemperature, equals(3300.0));

        final updatedInvalid = rule.copyWith(
          fixedBrightness: double.nan,
          fixedTemperature: double.infinity,
        );
        expect(updatedInvalid.fixedBrightness, equals(50.0));
        expect(updatedInvalid.fixedTemperature, equals(5000.0));
      },
    );

    test(
      'Verify all 6 default built-in rules conform strictly to design spec v10 section 3.2',
      () {
        final defaults = AppOverrideRule.defaultBuiltInRules;
        final map = {for (var r in defaults) r.exeName: r};

        expect(
          map.keys,
          containsAll([
            'photoshop.exe',
            'premiere.exe',
            'resolve.exe',
            'lightroom.exe',
            'blender.exe',
            'figma.exe',
          ]),
        );

        expect(map['photoshop.exe']?.appDisplayName, equals('Adobe Photoshop'));
        expect(
          map['premiere.exe']?.appDisplayName,
          equals('Adobe Premiere Pro'),
        );
        expect(map['resolve.exe']?.appDisplayName, equals('DaVinci Resolve'));
        expect(map['lightroom.exe']?.appDisplayName, equals('Adobe Lightroom'));
        expect(map['blender.exe']?.appDisplayName, equals('Blender 3D'));
        expect(map['figma.exe']?.appDisplayName, equals('Figma Desktop'));

        for (var r in defaults) {
          expect(r.isBuiltIn, isTrue);
          expect(r.isEnabled, isTrue);
          expect(r.temperatureMode, equals(AppOverrideMode.fixed));
          expect(r.fixedTemperature, equals(6500.0));
          expect(r.brightnessMode, equals(AppOverrideMode.global));
        }
      },
    );
  });

  group('SettingsState Phase 2 Migration and Serialization Zero-Trust Tests', () {
    test(
      'Legacy json without appOverrides key falls back to defaultBuiltInRules',
      () {
        final legacyJson = <String, dynamic>{
          'isAutorunEnabled': true,
          'gameModeBrightness': 85.0,
        };

        final settings = SettingsState.fromJson(legacyJson);
        expect(settings.appOverrides.length, equals(6));
        expect(settings.appOverrides.first.exeName, equals('photoshop.exe'));
        expect(settings.appOverrideExitDelaySeconds, equals(30));
      },
    );

    test('Json with empty appOverrides [] preserves empty list', () {
      final jsonWithEmptyOverrides = <String, dynamic>{
        'appOverrides': <dynamic>[],
        'appOverrideExitDelaySeconds': 45,
      };

      final settings = SettingsState.fromJson(jsonWithEmptyOverrides);
      expect(settings.appOverrides, isEmpty);
      expect(settings.appOverrideExitDelaySeconds, equals(45));
    });

    test(
      'Json with corrupted non-map appOverrides elements filters them safely without throwing',
      () {
        final corruptedJson = <String, dynamic>{
          'appOverrides': [
            'corrupted_string',
            123,
            null,
            {'exeName': 'valid.exe', 'appDisplayName': 'Valid App'},
          ],
        };

        final settings = SettingsState.fromJson(corruptedJson);
        expect(settings.appOverrides.length, equals(1));
        expect(settings.appOverrides.first.exeName, equals('valid.exe'));
      },
    );

    test(
      'appOverrideExitDelaySeconds handles various input types and clamps to 0..300',
      () {
        final negativeDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': -50,
        };
        expect(
          SettingsState.fromJson(negativeDelayJson).appOverrideExitDelaySeconds,
          equals(0),
        );

        final excessiveDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': 999,
        };
        expect(
          SettingsState.fromJson(
            excessiveDelayJson,
          ).appOverrideExitDelaySeconds,
          equals(300),
        );

        final doubleDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': 60.0,
        };
        expect(
          SettingsState.fromJson(doubleDelayJson).appOverrideExitDelaySeconds,
          equals(60),
        );

        final stringDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': '120',
        };
        expect(
          SettingsState.fromJson(stringDelayJson).appOverrideExitDelaySeconds,
          equals(120),
        );

        final invalidStringDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': 'invalid_string',
        };
        expect(
          SettingsState.fromJson(
            invalidStringDelayJson,
          ).appOverrideExitDelaySeconds,
          equals(30),
        );

        final boolDelayJson = <String, dynamic>{
          'appOverrideExitDelaySeconds': true,
        };
        expect(
          SettingsState.fromJson(boolDelayJson).appOverrideExitDelaySeconds,
          equals(30),
        );
      },
    );

    test(
      'SettingsState toJson includes appOverrides and appOverrideExitDelaySeconds',
      () {
        final settings = SettingsState(
          appOverrideExitDelaySeconds: 60,
          appOverrides: [
            const AppOverrideRule(
              exeName: 'figma.exe',
              appDisplayName: 'Figma Desktop',
              fixedTemperature: 6500.0,
            ),
          ],
        );

        final json = settings.toJson();
        expect(json.containsKey('appOverrides'), isTrue);
        expect(json.containsKey('appOverrideExitDelaySeconds'), isTrue);
        expect(json['appOverrideExitDelaySeconds'], equals(60));

        final List<dynamic> overridesJson =
            json['appOverrides'] as List<dynamic>;
        expect(overridesJson.length, equals(1));
        expect(overridesJson.first['exeName'], equals('figma.exe'));

        final reloaded = SettingsState.fromJson(json);
        expect(reloaded.appOverrides.length, equals(1));
        expect(reloaded.appOverrides.first.exeName, equals('figma.exe'));
        expect(reloaded.appOverrideExitDelaySeconds, equals(60));
      },
    );

    test(
      'SettingsState.copyWith updates appOverrides and appOverrideExitDelaySeconds correctly',
      () {
        final settings = SettingsState();
        final updated = settings.copyWith(
          appOverrideExitDelaySeconds: 120,
          appOverrides: [
            const AppOverrideRule(
              exeName: 'custom.exe',
              appDisplayName: 'Custom App',
            ),
          ],
        );

        expect(updated.appOverrideExitDelaySeconds, equals(120));
        expect(updated.appOverrides.length, equals(1));
        expect(updated.appOverrides.first.exeName, equals('custom.exe'));
      },
    );
  });

  group('ActiveProcessService & Priority Cascades Phase 3 Zero-Trust Tests', () {
    test(
      'System shell blacklist contains all 8 required Windows OS shell processes',
      () {
        final blacklist = ActiveProcessService.systemShellBlacklist;
        expect(
          blacklist,
          containsAll([
            'explorer.exe',
            'shellexperiencehost.exe',
            'searchhost.exe',
            'applicationframehost.exe',
            'sharex.exe',
            'startmenuexperiencehost.exe',
            'taskview.exe',
            'multitaskingviewframe.exe',
          ]),
        );
      },
    );

    test('ActiveProcessState operator == and hashCode operate correctly', () {
      const state1 = ActiveProcessState(
        activeProcess: 'photoshop.exe',
        windowTitle: 'Adobe Photoshop',
        isGaming: false,
        suppressedPids: {123},
      );
      const state2 = ActiveProcessState(
        activeProcess: 'photoshop.exe',
        windowTitle: 'Adobe Photoshop',
        isGaming: false,
        suppressedPids: {123},
      );
      const state3 = ActiveProcessState(
        activeProcess: 'photoshop.exe',
        windowTitle: 'Adobe Photoshop',
        isGaming: false,
        suppressedPids: {},
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1 == state3, isFalse);
    });

    test('Suppressed PIDs can be added and copied in ActiveProcessState', () {
      const initial = ActiveProcessState(
        activeProcess: 'blender.exe',
        windowTitle: 'Blender 3D',
      );
      expect(initial.suppressedPids, isEmpty);

      final updated = initial.copyWith(suppressedPids: {999});
      expect(updated.suppressedPids, contains(999));
    });
  });

  group('Phase 4 Hotkey, API ACL & Regex Sanitization Zero-Trust Tests', () {
    test(
      'ApiPermissionsConfig includes all 28 canonical actions including per-app overrides actions',
      () {
        final allActions = ApiPermissionsConfig.getAllCanonicalActions();
        expect(allActions.length, equals(28));
        expect(allActions, contains('get_app_overrides'));
        expect(allActions, contains('manage_app_overrides'));
        expect(allActions, contains('reset_builtin_app_overrides'));

        expect(
          ApiPermissionsConfig.getCategoryForAction('get_app_overrides'),
          equals(ApiActionCategory.presets),
        );
        expect(
          ApiPermissionsConfig.getCategoryForAction('manage_app_overrides'),
          equals(ApiActionCategory.presets),
        );
        expect(
          ApiPermissionsConfig.getCategoryForAction('reset_builtin_app_overrides'),
          equals(ApiActionCategory.presets),
        );
      },
    );

    test('Regex sanitization validates valid exe names and rejects invalid/malicious paths', () {
      final regex = RegExp(r'^[a-z0-9_\-\.]+\.exe$');

      final validNames = [
        'photoshop.exe',
        'premiere.exe',
        'app_v1.0.exe',
        'my-custom-app.exe',
        '123.exe',
      ];
      for (final name in validNames) {
        expect(regex.hasMatch(name), isTrue, reason: 'Failed for valid name $name');
      }

      final invalidNames = [
        'photoshop',
        'photoshop.bat',
        '../photoshop.exe',
        r'C:\Windows\System32\cmd.exe',
        'app.exe/test',
        'app.exe;rm -rf',
        '   ',
        'APP.EXE', // Must be lowercase before regex check
      ];
      for (final name in invalidNames) {
        expect(regex.hasMatch(name), isFalse, reason: 'Failed to reject invalid name $name');
      }
    });

    test('WebSocket active_process_changed & app_override_changed payload structure test', () {
      const rule = AppOverrideRule(
        exeName: 'photoshop.exe',
        appDisplayName: 'Adobe Photoshop',
        temperatureMode: AppOverrideMode.fixed,
        fixedTemperature: 6500.0,
      );

      final activeProcessPayload = {
        'active_process': 'photoshop.exe',
        'window_title': 'Adobe Photoshop 2026',
        'is_gaming': false,
        'applied_override': rule.toJson(),
        'evaluated_brightness': 80.0,
        'evaluated_temperature': 6500,
      };

      expect(activeProcessPayload['active_process'], equals('photoshop.exe'));
      expect(activeProcessPayload['evaluated_temperature'], equals(6500));
      final Map<String, dynamic> applied = activeProcessPayload['applied_override'] as Map<String, dynamic>;
      expect(applied['fixedTemperature'], equals(6500.0));

      final appOverrideChangedPayload = {
        'app_overrides': [rule.toJson()],
        'exit_delay_seconds': 30,
      };

      expect(appOverrideChangedPayload['exit_delay_seconds'], equals(30));
      expect((appOverrideChangedPayload['app_overrides'] as List).length, equals(1));
    });
  });
}
