import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/app_override_rule.dart';

/// Category of rule descriptor for categorization and UI accents.
enum RuleDescriptorCategory { temperature, brightness, custom }

/// Structured descriptor representing a specific active setting within an AppOverrideRule.
class BuiltInRuleDescriptor {
  final RuleDescriptorCategory category;
  final IconData icon;
  final String label;
  final String valueText;
  final Color accentColor;
  final String? badgeText;

  const BuiltInRuleDescriptor({
    required this.category,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.accentColor,
    this.badgeText,
  });
}

/// Extensible formatter utility that inspects an [AppOverrideRule] and yields
/// structured, localized descriptors of active overrides.
abstract class AppOverrideRuleFormatter {
  /// Analyzes [rule] and returns a list of [BuiltInRuleDescriptor] badges.
  /// Accepts [brightnessCurveNamesById] and [temperatureCurveNamesById] to resolve curve preset IDs to human-readable names.
  static List<BuiltInRuleDescriptor> getDescriptors({
    required AppOverrideRule rule,
    required AppLocalizations l10n,
    Map<String, String>? brightnessCurveNamesById,
    Map<String, String>? temperatureCurveNamesById,
    @Deprecated(
      'Use brightnessCurveNamesById and temperatureCurveNamesById instead',
    )
    Map<String, String>? curveNamesById,
  }) {
    final List<BuiltInRuleDescriptor> descriptors = [];
    final tempNames = temperatureCurveNamesById ?? curveNamesById;
    final brightNames = brightnessCurveNamesById ?? curveNamesById;

    // 1. Temperature descriptor
    switch (rule.temperatureMode) {
      case AppOverrideMode.fixed:
        final tempVal = (rule.fixedTemperature ?? 6500.0).round();
        descriptors.add(
          BuiltInRuleDescriptor(
            category: RuleDescriptorCategory.temperature,
            icon: LucideIcons.thermometer,
            label: l10n.temperatureMode,
            valueText: '$tempVal K',
            accentColor: const Color(0xFF60A5FA),
            badgeText: l10n.appOverrideModeFixed,
          ),
        );
        break;

      case AppOverrideMode.curve:
        final curveId = rule.temperatureCurvePresetId;
        final curveName = (tempNames != null && curveId != null)
            ? (tempNames[curveId] ?? curveId)
            : (curveId ?? l10n.appOverrideModeCurve);
        descriptors.add(
          BuiltInRuleDescriptor(
            category: RuleDescriptorCategory.temperature,
            icon: LucideIcons.spline,
            label: l10n.temperatureMode,
            valueText: curveName,
            accentColor: const Color(0xFF60A5FA),
            badgeText: l10n.appOverrideModeCurve,
          ),
        );
        break;

      case AppOverrideMode.global:
        break;
    }

    // 2. Brightness descriptor
    switch (rule.brightnessMode) {
      case AppOverrideMode.fixed:
        final brightnessVal = (rule.fixedBrightness ?? 100.0).round();
        descriptors.add(
          BuiltInRuleDescriptor(
            category: RuleDescriptorCategory.brightness,
            icon: LucideIcons.sun,
            label: l10n.brightnessMode,
            valueText: '$brightnessVal%',
            accentColor: const Color(0xFFFDBA74),
            badgeText: l10n.appOverrideModeFixed,
          ),
        );
        break;

      case AppOverrideMode.curve:
        final curveId = rule.brightnessCurvePresetId;
        final curveName = (brightNames != null && curveId != null)
            ? (brightNames[curveId] ?? curveId)
            : (curveId ?? l10n.appOverrideModeCurve);
        descriptors.add(
          BuiltInRuleDescriptor(
            category: RuleDescriptorCategory.brightness,
            icon: LucideIcons.spline,
            label: l10n.brightnessMode,
            valueText: curveName,
            accentColor: const Color(0xFFFDBA74),
            badgeText: l10n.appOverrideModeCurve,
          ),
        );
        break;

      case AppOverrideMode.global:
        break;
    }

    // Fallback if no specific overrides are set (both global)
    if (descriptors.isEmpty) {
      descriptors.add(
        BuiltInRuleDescriptor(
          category: RuleDescriptorCategory.custom,
          icon: LucideIcons.globe,
          label: l10n.appOverrideModeGlobal,
          valueText: l10n.appOverrideModeGlobal,
          accentColor: const Color(0xFF9CA3AF),
          badgeText: l10n.appOverrideModeGlobal,
        ),
      );
    }

    return descriptors;
  }
}
