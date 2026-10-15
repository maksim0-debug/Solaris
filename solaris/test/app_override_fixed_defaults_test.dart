import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations_en.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/utils/app_override_formatter.dart';

void main() {
  const empty = AppOverrideRule(
    exeName: 'editor.exe',
    appDisplayName: 'Editor',
  );

  test('switching to fixed mode stores the value displayed by the editor', () {
    final rule = empty.copyWith(
      brightnessMode: AppOverrideMode.fixed,
      temperatureMode: AppOverrideMode.fixed,
    );
    expect(rule.fixedBrightness, 80);
    expect(rule.fixedTemperature, 6500);
    expect(AppOverrideRule.fromJson(rule.toJson()), rule);
  });

  test('switching away and back to fixed mode preserves customized values', () {
    final configured = empty.copyWith(
      fixedBrightness: 42,
      fixedTemperature: 4500,
    );
    for (final mode in [
      AppOverrideMode.fixed,
      AppOverrideMode.curve,
      AppOverrideMode.global,
      AppOverrideMode.fixed,
    ]) {
      final switched = configured.copyWith(
        brightnessMode: mode,
        temperatureMode: mode,
      );
      expect(switched.fixedBrightness, 42);
      expect(switched.fixedTemperature, 4500);
    }
  });

  test('saving a legacy fixed rule makes the effective defaults explicit', () {
    final legacy = AppOverrideRule.fromJson({
      'exeName': 'cs2.exe',
      'appDisplayName': 'Counter-Strike 2',
      'brightnessMode': 'fixed',
      'fixedBrightness': 100,
      'temperatureMode': 'fixed',
      'fixedTemperature': null,
    });
    expect(legacy.effectiveFixedTemperature, 6500);
    final json = legacy.toJson();
    expect(json['fixedTemperature'], 6500);
    expect(json['fixedBrightness'], 100);
    expect(AppOverrideRule.fromJson(json).effectiveFixedTemperature, 6500);
  });

  test('global modes do not persist or activate unused fixed defaults', () {
    expect(empty.toJson()['fixedBrightness'], isNull);
    expect(empty.toJson()['fixedTemperature'], isNull);
    expect(empty.brightnessMode, AppOverrideMode.global);
    expect(empty.temperatureMode, AppOverrideMode.global);
    expect(AppOverrideRule.fromJson(empty.toJson()), empty);
  });

  for (final sample in [
    (double.nan, double.infinity, 80.0, 6500.0),
    (-5.0, 500.0, 0.0, 1000.0),
    (150.0, 9000.0, 100.0, 6500.0),
    (0.0, 1000.0, 0.0, 1000.0),
  ]) {
    test(
      'fixed values are finite and bounded for ${sample.$1}, ${sample.$2}',
      () {
        final rule = AppOverrideRule(
          exeName: 'editor.exe',
          appDisplayName: 'Editor',
          brightnessMode: AppOverrideMode.fixed,
          fixedBrightness: sample.$1,
          temperatureMode: AppOverrideMode.fixed,
          fixedTemperature: sample.$2,
        );
        expect(rule.effectiveFixedBrightness, sample.$3);
        expect(rule.effectiveFixedTemperature, sample.$4);
        expect(rule.toJson()['fixedBrightness'], sample.$3);
        expect(rule.toJson()['fixedTemperature'], sample.$4);
      },
    );
  }

  test('descriptors show the same defaults as fixed target resolution', () {
    final rule = AppOverrideRule.fromJson({
      'exeName': 'editor.exe',
      'appDisplayName': 'Editor',
      'brightnessMode': 'fixed',
      'temperatureMode': 'fixed',
    });
    final descriptors = AppOverrideRuleFormatter.getDescriptors(
      rule: rule,
      l10n: AppLocalizationsEn(),
    );
    expect(descriptors.map((descriptor) => descriptor.valueText), [
      '6500 K',
      '80%',
    ]);
  });
}
