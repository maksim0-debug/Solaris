import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/curve_preset_dropdown.dart';
import 'package:solaris/widgets/back_navigation_handler.dart';
import 'package:solaris/widgets/deep_link_target.dart';
import 'package:solaris/widgets/glowing_app_icon.dart';
import 'package:solaris/utils/app_override_formatter.dart';

/// Screen for managing Per-App Brightness and Temperature Overrides.
class AppOverridesScreen extends ConsumerStatefulWidget {
  const AppOverridesScreen({super.key});

  @override
  ConsumerState<AppOverridesScreen> createState() => _AppOverridesScreenState();
}

class _AppOverridesScreenState extends ConsumerState<AppOverridesScreen> {
  bool _isBuiltInExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<DeepLinkTargetState>> _anchorKeys = {
    'app_override_exit_delay': GlobalKey<DeepLinkTargetState>(),
    'app_override_user_rules': GlobalKey<DeepLinkTargetState>(),
    'app_override_builtin_rules': GlobalKey<DeepLinkTargetState>(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAnchor(String anchorId) {
    final key = _anchorKeys[anchorId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
      key.currentState?.highlight();

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          ref.read(searchAnchorProvider.notifier).clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value?['all'] ?? SettingsState();
    final allOverrides = settings.appOverrides;

    final userRules = allOverrides
        .where((AppOverrideRule r) => !r.isBuiltIn)
        .toList();
    final builtInRules = allOverrides
        .where((AppOverrideRule r) => r.isBuiltIn)
        .toList();

    // Listen for deep link requests
    ref.listen<String?>(searchAnchorProvider, (previous, next) {
      if (next != null && _anchorKeys.containsKey(next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToAnchor(next);
        });
      }
    });

    // Handle initial anchor on first build/mount
    final initialAnchor = ref.read(searchAnchorProvider);
    if (initialAnchor != null && _anchorKeys.containsKey(initialAnchor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAnchor(initialAnchor);
      });
    }

    return BackNavigationHandler(
      onBack: () =>
          ref.read(activeScreenProvider.notifier).setScreen(AppScreen.settings),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            _buildHeader(ref, l10n),
            const SizedBox(height: 24),

            // Exit Delay Slider Card
            DeepLinkTarget(
              key: _anchorKeys['app_override_exit_delay'],
              id: 'app_override_exit_delay',
              child: _buildExitDelayCard(
                context,
                l10n,
                settings.appOverrideExitDelaySeconds,
              ),
            ),
            const SizedBox(height: 32),

            // User Rules Section Header + Add Button
            DeepLinkTarget(
              key: _anchorKeys['app_override_user_rules'],
              id: 'app_override_user_rules',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.sliders,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.userRulesSection,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${userRules.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openAddAppDialog(context, allOverrides),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(l10n.addAppOverride),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // User Rules List or Empty State
                  if (userRules.isEmpty)
                    _buildEmptyUserRulesCard(l10n)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: userRules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _AppOverrideRuleCard(
                          rule: userRules[index],
                          isBuiltIn: false,
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Built-in Presets Collapsible Section
            DeepLinkTarget(
              key: _anchorKeys['app_override_builtin_rules'],
              id: 'app_override_builtin_rules',
              child: _buildBuiltInSection(context, l10n, builtInRules),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref
              .read(activeScreenProvider.notifier)
              .setScreen(AppScreen.settings),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.arrowLeft,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.backToSettings,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                LucideIcons.layers,
                color: Color(0xFF818CF8),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appOverridesTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.appOverridesSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExitDelayCard(
    BuildContext context,
    AppLocalizations l10n,
    int currentDelaySeconds,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.timer,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appOverrideExitDelay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.appOverrideExitDelaySubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  l10n.appOverrideExitDelaySeconds(currentDelaySeconds),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFF59E0B),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: const Color(0xFFF59E0B),
              overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: currentDelaySeconds.toDouble().clamp(0.0, 300.0),
              min: 0,
              max: 300,
              divisions: 60,
              label: '${currentDelaySeconds}s',
              onChanged: (double val) {
                ref
                    .read(settingsProvider.notifier)
                    .updateAppOverrideExitDelay(val.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUserRulesCard(AppLocalizations l10n) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 40,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noCustomAppRulesYet,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noCustomAppRulesHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInSection(
    BuildContext context,
    AppLocalizations l10n,
    List<AppOverrideRule> builtInRules,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isBuiltInExpanded = !_isBuiltInExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(LucideIcons.box, color: Colors.white60, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.builtinRulesSection(builtInRules.length),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmResetBuiltIn(context, l10n),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: Text(
                      l10n.resetBuiltinRules,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isBuiltInExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_isBuiltInExpanded && builtInRules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: builtInRules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _AppOverrideRuleCard(
                    rule: builtInRules[index],
                    isBuiltIn: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmResetBuiltIn(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.resetBuiltinConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.resetBuiltinConfirmMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(l10n.resetBuiltinRules),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(settingsProvider.notifier).resetBuiltInAppOverrides();
    }
  }

  void _openAddAppDialog(
    BuildContext context,
    List<AppOverrideRule> existingRules,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddAppOverrideDialog(existingRules: existingRules),
    );
  }
}

/// Card representing a single App Override Rule
class _AppOverrideRuleCard extends ConsumerWidget {
  final AppOverrideRule rule;
  final bool isBuiltIn;

  const _AppOverrideRuleCard({required this.rule, required this.isBuiltIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value?['all'] ?? SettingsState();
    final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
    final tempSettings = tempSettingsAsync.value?['all'] ?? TemperatureState();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rule.isEnabled
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Names + Switch + Delete / Promote
          Row(
            children: [
              GlowingAppIcon(
                name: rule.exeName,
                fallbackLetter: rule.appDisplayName,
                size: 36,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.appDisplayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      rule.exeName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (isBuiltIn)
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .promoteBuiltInToUser(rule.exeName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.appPromotedToast(rule.appDisplayName),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.arrowUpRight, size: 14),
                  label: Text(
                    l10n.promoteToUser,
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                    foregroundColor: const Color(0xFFA5B4FC),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                )
              else ...[
                Switch(
                  value: rule.isEnabled,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleAppOverride(rule.exeName, val);
                  },
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: Colors.white54,
                  ),
                  onPressed: () => _confirmDelete(context, l10n, ref),
                ),
              ],
            ],
          ),

          if (isBuiltIn) ...[
            const SizedBox(height: 12),
            _buildBuiltInRuleSummary(context, l10n, settings, tempSettings),
          ] else if (rule.isEnabled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white12, height: 1),
            ),

            // Brightness Controls
            _buildBrightnessSection(context, l10n, ref, settings),
            const SizedBox(height: 16),

            // Temperature Controls
            _buildTemperatureSection(context, l10n, ref, tempSettings),
          ],
        ],
      ),
    );
  }

  Widget _buildBuiltInRuleSummary(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState settings,
    TemperatureState tempSettings,
  ) {
    final Map<String, String> brightnessCurveNames = {};
    for (final type in PresetType.values) {
      brightnessCurveNames[type.name] = type.getName(l10n);
    }
    for (final p in settings.userPresets) {
      brightnessCurveNames[p.id] = p.name;
    }

    final Map<String, String> temperatureCurveNames = {};
    for (final type in TemperaturePresetType.values) {
      temperatureCurveNames[type.name] = type.getName(l10n);
    }
    for (final p in tempSettings.userPresets) {
      temperatureCurveNames[p.id] = p.name;
    }

    final descriptors = AppOverrideRuleFormatter.getDescriptors(
      rule: rule,
      l10n: l10n,
      brightnessCurveNamesById: brightnessCurveNames,
      temperatureCurveNamesById: temperatureCurveNames,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 13,
                color: const Color(0xFF818CF8).withOpacity(0.9),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.builtinActiveParameters,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: descriptors.map((d) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: d.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: d.accentColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.icon, size: 14, color: d.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      '${d.label}: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      d.valueText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: d.accentColor,
                      ),
                    ),
                    if (d.badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: d.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          d.badgeText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: d.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessSection(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    SettingsState settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.sun, size: 16, color: Color(0xFFFDBA74)),
                const SizedBox(width: 6),
                Text(
                  l10n.brightnessMode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            _buildModeSelector(
              currentMode: rule.brightnessMode,
              onModeChanged: (mode) {
                final updated = rule.copyWith(brightnessMode: mode);
                ref.read(settingsProvider.notifier).updateAppOverride(updated);
              },
              l10n: l10n,
            ),
          ],
        ),
        if (rule.brightnessMode == AppOverrideMode.fixed) ...[
          const SizedBox(height: 8),
          _AppRuleBrightnessSlider(
            value: (rule.fixedBrightness ?? 80.0).clamp(0.0, 100.0),
            onChanged: (val) {
              final updated = rule.copyWith(fixedBrightness: val);
              ref.read(settingsProvider.notifier).updateAppOverride(updated);
            },
          ),
        ],
        if (rule.brightnessMode == AppOverrideMode.curve) ...[
          const SizedBox(height: 8),
          _buildBrightnessCurveDropdown(ref, settings, l10n),
        ],
      ],
    );
  }

  Widget _buildTemperatureSection(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    TemperatureState tempSettings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.thermometer,
                  size: 16,
                  color: Color(0xFF60A5FA),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.temperatureMode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            _buildModeSelector(
              currentMode: rule.temperatureMode,
              onModeChanged: (mode) {
                final updated = rule.copyWith(temperatureMode: mode);
                ref.read(settingsProvider.notifier).updateAppOverride(updated);
              },
              l10n: l10n,
            ),
          ],
        ),
        if (rule.temperatureMode == AppOverrideMode.fixed) ...[
          const SizedBox(height: 8),
          _AppRuleTemperatureSlider(
            value: (rule.fixedTemperature ?? 6500.0).clamp(3300.0, 6500.0),
            onChanged: (val) {
              final updated = rule.copyWith(fixedTemperature: val);
              ref.read(settingsProvider.notifier).updateAppOverride(updated);
            },
          ),
        ],
        if (rule.temperatureMode == AppOverrideMode.curve) ...[
          const SizedBox(height: 8),
          _buildTemperatureCurveDropdown(ref, tempSettings, l10n),
        ],
      ],
    );
  }

  Widget _buildModeSelector({
    required AppOverrideMode currentMode,
    required ValueChanged<AppOverrideMode> onModeChanged,
    required AppLocalizations l10n,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppOverrideMode.values.map((mode) {
          final isSelected = currentMode == mode;
          String label;
          switch (mode) {
            case AppOverrideMode.global:
              label = l10n.appOverrideModeGlobal;
              break;
            case AppOverrideMode.fixed:
              label = l10n.appOverrideModeFixed;
              break;
            case AppOverrideMode.curve:
              label = l10n.appOverrideModeCurve;
              break;
          }
          return InkWell(
            onTap: () => onModeChanged(mode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrightnessCurveDropdown(
    WidgetRef ref,
    SettingsState settings,
    AppLocalizations l10n,
  ) {
    final systemOptions = PresetType.values.map((type) {
      return CurvePresetOption(
        id: type.name,
        title: type.getName(l10n),
        isSystem: true,
      );
    }).toList();

    final userOptions = settings.userPresets.map((p) {
      return CurvePresetOption(id: p.id, title: p.name, isSystem: false);
    }).toList();

    final currentId = rule.brightnessCurvePresetId ?? PresetType.bright.name;

    return CurvePresetDropdown(
      currentId: currentId,
      systemOptions: systemOptions,
      userOptions: userOptions,
      l10n: l10n,
      icon: LucideIcons.sun,
      accentColor: const Color(0xFFFDBA74),
      onSelected: (val) {
        final updated = rule.copyWith(brightnessCurvePresetId: val);
        ref.read(settingsProvider.notifier).updateAppOverride(updated);
      },
    );
  }

  Widget _buildTemperatureCurveDropdown(
    WidgetRef ref,
    TemperatureState tempSettings,
    AppLocalizations l10n,
  ) {
    final systemOptions = TemperaturePresetType.values.map((type) {
      return CurvePresetOption(
        id: type.name,
        title: type.getName(l10n),
        isSystem: true,
      );
    }).toList();

    final userOptions = tempSettings.userPresets.map((p) {
      return CurvePresetOption(id: p.id, title: p.name, isSystem: false);
    }).toList();

    final currentId =
        rule.temperatureCurvePresetId ?? TemperaturePresetType.cool.name;

    return CurvePresetDropdown(
      currentId: currentId,
      systemOptions: systemOptions,
      userOptions: userOptions,
      l10n: l10n,
      icon: LucideIcons.thermometer,
      accentColor: const Color(0xFF60A5FA),
      onSelected: (val) {
        final updated = rule.copyWith(temperatureCurvePresetId: val);
        ref.read(settingsProvider.notifier).updateAppOverride(updated);
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.deleteOverrideConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.deleteOverrideConfirmMessage(rule.appDisplayName),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(l10n.deleteOverrideConfirmTitle),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(settingsProvider.notifier).removeAppOverride(rule.exeName);
    }
  }
}

/// Dialog for adding a new application rule
class _AddAppOverrideDialog extends ConsumerStatefulWidget {
  final List<AppOverrideRule> existingRules;

  const _AddAppOverrideDialog({required this.existingRules});

  @override
  ConsumerState<_AddAppOverrideDialog> createState() =>
      _AddAppOverrideDialogState();
}

class _AddAppOverrideDialogState extends ConsumerState<_AddAppOverrideDialog> {
  static const _namesChannel = MethodChannel('com.solaris.monitor/names');

  final TextEditingController _exeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> _runningProcesses = [];
  bool _isLoadingProcesses = true;
  String? _selectedProcessExe;

  @override
  void initState() {
    super.initState();
    _fetchProcesses();
  }

  @override
  void dispose() {
    _exeController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProcesses() async {
    try {
      final List<dynamic>? rawList = await _namesChannel
          .invokeMethod<List<dynamic>>('getRunningProcesses');
      if (rawList != null) {
        final parsed = rawList
            .map((item) {
              final map = Map<Object?, Object?>.from(item as Map);
              return {
                'exe': (map['exe'] ?? '').toString(),
                'title': (map['title'] ?? '').toString(),
              };
            })
            .where((m) => m['exe']!.isNotEmpty)
            .toList();

        setState(() {
          _runningProcesses = parsed;
          _isLoadingProcesses = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _isLoadingProcesses = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _searchController.text.trim().toLowerCase();

    final filteredProcesses = _runningProcesses.where((p) {
      if (query.isEmpty) return true;
      return p['exe']!.toLowerCase().contains(query) ||
          p['title']!.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(LucideIcons.appWindow, color: Color(0xFF6366F1)),
          const SizedBox(width: 10),
          Text(
            l10n.selectAppTitle,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchAppPlaceholder,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  color: Colors.white38,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Active Processes Header
            Text(
              l10n.runningApps,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // Processes Container
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: _isLoadingProcesses
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : filteredProcesses.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noRunningApps,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProcesses.length,
                      itemBuilder: (context, index) {
                        final item = filteredProcesses[index];
                        final exe = item['exe']!;
                        final title = item['title']!;
                        final isSelected = _selectedProcessExe == exe;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: const Color(
                            0xFF6366F1,
                          ).withOpacity(0.2),
                          leading: GlowingAppIcon(
                            key: ValueKey(exe),
                            name: exe,
                            fallbackLetter: title.isNotEmpty ? title : exe,
                            size: 28,
                            borderRadius: 8,
                          ),
                          title: Text(
                            exe,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: title.isNotEmpty
                              ? Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedProcessExe = exe;
                              _exeController.text = exe;
                              _nameController.text = title.isNotEmpty
                                  ? title.split(' - ').first
                                  : exe.replaceAll('.exe', '');
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Manual inputs
            TextField(
              controller: _exeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.customExeName,
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.customDisplayName,
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(l10n.addAppOverride),
        ),
      ],
    );
  }

  void _saveRule() {
    final l10n = AppLocalizations.of(context)!;
    var exe = _exeController.text.trim().toLowerCase();
    var name = _nameController.text.trim();

    if (exe.isEmpty) return;
    if (!exe.endsWith('.exe')) {
      exe = '$exe.exe';
    }
    if (name.isEmpty) {
      name = exe.replaceAll('.exe', '');
    }

    // Check if the rule exists in built-in rules (isBuiltIn == true) -> Automatic Promotion UX Flow
    final builtInMatch = widget.existingRules.firstWhere(
      (AppOverrideRule r) => r.isBuiltIn && r.exeName.toLowerCase() == exe,
      orElse: () => const AppOverrideRule(exeName: '', appDisplayName: ''),
    );

    if (builtInMatch.exeName.isNotEmpty) {
      // Automatic Promotion
      ref.read(settingsProvider.notifier).promoteBuiltInToUser(exe);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.appPromotedToast(builtInMatch.appDisplayName)),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      return;
    }

    // Otherwise create new user rule
    final newRule = AppOverrideRule(
      exeName: exe,
      appDisplayName: name,
      isBuiltIn: false,
      isEnabled: true,
      brightnessMode: AppOverrideMode.global,
      temperatureMode: AppOverrideMode.global,
    );

    ref.read(settingsProvider.notifier).addAppOverride(newRule);
    Navigator.of(context).pop();
  }
}

class _AppRuleBrightnessSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _AppRuleBrightnessSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AppRuleBrightnessSlider> createState() =>
      _AppRuleBrightnessSliderState();
}

class _AppRuleBrightnessSliderState extends State<_AppRuleBrightnessSlider> {
  late double _localValue;
  bool _isDragging = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AppRuleBrightnessSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != oldWidget.value) {
      _localValue = widget.value;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _notifyChanged(double val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        widget.onChanged(val);
      }
    });
  }

  void _notifyChangeEnd(double val) {
    _debounceTimer?.cancel();
    widget.onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = _localValue.clamp(0.0, 100.0);
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: const _AppRuleGradientTrackShape(
                gradient: LinearGradient(
                  colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
                ),
              ),
              activeTrackColor: const Color(0xFFF97316),
              thumbColor: const Color(0xFFFDBA74),
              overlayColor: const Color(0xFFFDBA74).withOpacity(0.12),
            ),
            child: Slider(
              value: clamped,
              min: 0,
              max: 100,
              activeColor: const Color(0xFFF97316),
              onChanged: (val) {
                setState(() {
                  _isDragging = true;
                  _localValue = val;
                });
                _notifyChanged(val);
              },
              onChangeEnd: (val) {
                setState(() {
                  _isDragging = false;
                  _localValue = val;
                });
                _notifyChangeEnd(val);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${clamped.round()}%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFDBA74),
          ),
        ),
      ],
    );
  }
}

class _AppRuleTemperatureSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _AppRuleTemperatureSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AppRuleTemperatureSlider> createState() =>
      _AppRuleTemperatureSliderState();
}

class _AppRuleTemperatureSliderState extends State<_AppRuleTemperatureSlider> {
  late double _localValue;
  bool _isDragging = false;
  Timer? _debounceTimer;

  static const double _minTemp = 3300.0;
  static const double _maxTemp = 6500.0;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AppRuleTemperatureSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != oldWidget.value) {
      _localValue = widget.value;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _notifyChanged(double val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        widget.onChanged(val);
      }
    });
  }

  void _notifyChangeEnd(double val) {
    _debounceTimer?.cancel();
    widget.onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = _localValue.clamp(_minTemp, _maxTemp);
    // progress: 0.0 (Cold/Left/6500K) to 1.0 (Warm/Right/3300K)
    final double progress = (_maxTemp - clamped) / (_maxTemp - _minTemp);

    final Color currentColor = Color.lerp(
      const Color(0xFF60A5FA),
      const Color(0xFFFDBA74),
      progress.clamp(0.0, 1.0),
    )!;

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: const _AppRuleGradientTrackShape(
                gradient: LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFFFDBA74)],
                ),
              ),
              activeTrackColor: currentColor,
              thumbColor: currentColor,
              overlayColor: currentColor.withOpacity(0.12),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              activeColor: currentColor,
              onChanged: (val) {
                final realTemp = _maxTemp - val * (_maxTemp - _minTemp);
                setState(() {
                  _isDragging = true;
                  _localValue = realTemp;
                });
                _notifyChanged(realTemp);
              },
              onChangeEnd: (val) {
                final realTemp = _maxTemp - val * (_maxTemp - _minTemp);
                setState(() {
                  _isDragging = false;
                  _localValue = realTemp;
                });
                _notifyChangeEnd(realTemp);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${clamped.round()}K',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: currentColor,
          ),
        ),
      ],
    );
  }
}

class _AppRuleGradientTrackShape extends RoundedRectSliderTrackShape {
  final LinearGradient gradient;

  const _AppRuleGradientTrackShape({required this.gradient});

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Inactive track
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white10;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      inactivePaint,
    );

    // Active track with gradient
    final activePaint = Paint()..shader = gradient.createShader(trackRect);

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
        topRight: Radius.zero,
        bottomRight: Radius.zero,
      ),
      activePaint,
    );
  }
}
