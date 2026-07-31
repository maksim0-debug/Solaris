import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations_en.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/utils/app_override_formatter.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('AppOverrideRuleFormatter Tests', () {
    test('formats fixed temperature built-in rule correctly', () {
      const rule = AppOverrideRule(
        exeName: 'photoshop.exe',
        appDisplayName: 'Adobe Photoshop',
        isBuiltIn: true,
        temperatureMode: AppOverrideMode.fixed,
        fixedTemperature: 6500.0,
      );

      final descriptors = AppOverrideRuleFormatter.getDescriptors(
        rule: rule,
        l10n: l10n,
      );

      expect(descriptors.length, 1);
      expect(descriptors.first.category, RuleDescriptorCategory.temperature);
      expect(descriptors.first.valueText, '6500 K');
      expect(descriptors.first.badgeText, 'Fixed');
    });

    test('formats fixed brightness and fixed temperature rule correctly', () {
      const rule = AppOverrideRule(
        exeName: 'blender.exe',
        appDisplayName: 'Blender 3D',
        isBuiltIn: true,
        brightnessMode: AppOverrideMode.fixed,
        fixedBrightness: 80.0,
        temperatureMode: AppOverrideMode.fixed,
        fixedTemperature: 6500.0,
      );

      final descriptors = AppOverrideRuleFormatter.getDescriptors(
        rule: rule,
        l10n: l10n,
      );

      expect(descriptors.length, 2);
      expect(descriptors[0].category, RuleDescriptorCategory.temperature);
      expect(descriptors[0].valueText, '6500 K');
      expect(descriptors[1].category, RuleDescriptorCategory.brightness);
      expect(descriptors[1].valueText, '80%');
    });

    test('formats curve presets with resolved separate curve names', () {
      const rule = AppOverrideRule(
        exeName: 'custom.exe',
        appDisplayName: 'Custom App',
        temperatureMode: AppOverrideMode.curve,
        temperatureCurvePresetId: 'same_key',
        brightnessMode: AppOverrideMode.curve,
        brightnessCurvePresetId: 'same_key',
      );

      final brightnessCurveNames = {'same_key': 'Brightness Curve Name'};

      final temperatureCurveNames = {'same_key': 'Temperature Curve Name'};

      final descriptors = AppOverrideRuleFormatter.getDescriptors(
        rule: rule,
        l10n: l10n,
        brightnessCurveNamesById: brightnessCurveNames,
        temperatureCurveNamesById: temperatureCurveNames,
      );

      expect(descriptors.length, 2);
      expect(descriptors[0].valueText, 'Temperature Curve Name');
      expect(descriptors[1].valueText, 'Brightness Curve Name');
    });

    test('fallback descriptor for global mode only', () {
      const rule = AppOverrideRule(
        exeName: 'default.exe',
        appDisplayName: 'Default App',
        temperatureMode: AppOverrideMode.global,
        brightnessMode: AppOverrideMode.global,
      );

      final descriptors = AppOverrideRuleFormatter.getDescriptors(
        rule: rule,
        l10n: l10n,
      );

      expect(descriptors.length, 1);
      expect(descriptors.first.category, RuleDescriptorCategory.custom);
      expect(descriptors.first.valueText, 'Global');
    });
  });
}
