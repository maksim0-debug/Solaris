import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/circadian_chart.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/temperature_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: LucideIcons.settings,
            title: l10n.settings,
            subtitle: l10n.settingsSubtitle,
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Chart Preview
          const _PresetSelector(),
          const SizedBox(height: 8),
          const _TypeSelector(),
          const SizedBox(height: 8),
          const CircadianChartWidget(),
          const SizedBox(height: 8),
          const _TempToggleCard(),
          const SizedBox(height: 24),

          // App Settings (Autorun)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDBA74).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.monitor,
                        color: Color(0xFFFDBA74),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settings,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.autorunSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.autorun,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.autorunSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settingsAsync.maybeWhen(
                        data: (map) => map['all']?.isAutorunEnabled ?? false,
                        orElse: () => false,
                      ), // Autorun is global-ish, use 'all'
                      onChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateAutorun(val),
                      activeColor: const Color(0xFFFDBA74),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weatherAdjustmentTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.weatherAdjustmentSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settingsAsync.maybeWhen(
                        data: (map) =>
                            map[selectedIds.firstOrNull ?? 'all']
                                ?.isWeatherAdjustmentEnabled ??
                            true,
                        orElse: () => true,
                      ),
                      onChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWeatherAdjustment(val),
                      activeColor: const Color(0xFFFDBA74),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            opacity: 0.03,
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 18,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.realtimeApplyNotice,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String _getTempPresetName(
  BuildContext context,
  TemperaturePresetType type,
  AppLocalizations l10n,
) {
  switch (type) {
    case TemperaturePresetType.coolest:
      return l10n.tempCoolest;
    case TemperaturePresetType.cool:
      return l10n.tempCool;
    case TemperaturePresetType.warm:
      return l10n.tempWarm;
    case TemperaturePresetType.warmest:
      return l10n.tempWarmest;
    case TemperaturePresetType.custom:
      return l10n.tempCustom;
  }
}

String _getPresetName(
  BuildContext context,
  PresetType type,
  AppLocalizations l10n,
) {
  switch (type) {
    case PresetType.brightest:
      return l10n.presetBrightest;
    case PresetType.bright:
      return l10n.presetBright;
    case PresetType.dim:
      return l10n.presetDim;
    case PresetType.dimmest:
      return l10n.presetDimmest;
    case PresetType.custom:
      return l10n.presetCustom;
  }
}

class _PresetSelector extends ConsumerWidget {
  const _PresetSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isTemp = ref.watch(editingTemperatureProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);

    if (isTemp) {
      final tempAsync = ref.watch(temperatureSettingsProvider);
      return tempAsync.maybeWhen(
        data: (tempMap) {
          final settings = tempMap[selectedIds.firstOrNull ?? 'all'] ?? tempMap['all']!;
          final activePreset = settings.activePreset;

          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: TemperaturePresetType.values.map((type) {
                        final isActive = type == activePreset;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextButton(
                            onPressed: () => ref
                                .read(temperatureSettingsProvider.notifier)
                                .setPreset(type),
                            style: TextButton.styleFrom(
                              backgroundColor: isActive
                                  ? const Color(0xFFFDBA74).withOpacity(0.1)
                                  : Colors.transparent,
                              foregroundColor: isActive
                                  ? const Color(0xFFFDBA74)
                                  : Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isActive
                                      ? const Color(0xFFFDBA74).withOpacity(0.5)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              _getTempPresetName(context, type, l10n),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ResetTempButton(settings: settings),
              ],
            ),
          );
        },
        orElse: () => const SizedBox(),
      );
    } else {
      final settingsAsync = ref.watch(settingsProvider);
      return settingsAsync.maybeWhen(
        data: (settingsMap) {
          final settings =
              settingsMap[selectedIds.firstOrNull ?? 'all'] ?? settingsMap['all']!;
          final activePreset = settings.activePreset;

          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: PresetType.values.map((type) {
                        final isActive = type == activePreset;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextButton(
                            onPressed: () => ref
                                .read(settingsProvider.notifier)
                                .setActivePreset(type),
                            style: TextButton.styleFrom(
                              backgroundColor: isActive
                                  ? const Color(0xFFFDBA74).withOpacity(0.1)
                                  : Colors.transparent,
                              foregroundColor: isActive
                                  ? const Color(0xFFFDBA74)
                                  : Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isActive
                                      ? const Color(0xFFFDBA74).withOpacity(0.5)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(_getPresetName(context, type, l10n)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ResetButton(settings: settings),
              ],
            ),
          );
        },
        orElse: () => const SizedBox(),
      );
    }
  }
}

class _ResetTempButton extends ConsumerWidget {
  final TemperatureState settings;
  const _ResetTempButton({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (settings.activePreset == TemperaturePresetType.custom) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () {
        ref.read(temperatureSettingsProvider.notifier).resetCurrentPreset();
      },
      icon: const Icon(LucideIcons.rotateCcw, size: 18),
      color: Colors.white54,
      tooltip: AppLocalizations.of(context)!.reset,
    );
  }
}

class _ResetButton extends ConsumerWidget {
  final SettingsState settings;
  const _ResetButton({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isModified = _isModified();

    return IconButton(
      icon: const Icon(LucideIcons.refreshCcw),
      onPressed: isModified
          ? () => ref.read(settingsProvider.notifier).resetCurrentPreset()
          : null,
      color: const Color(0xFFFDBA74),
      disabledColor: Colors.white10,
      tooltip: AppLocalizations.of(context)!.reset,
    );
  }

  bool _isModified() {
    final currentPoints = settings.curvePoints;
    final defaultPoints = PresetConstants.getDefaultPoints(
      settings.activePreset,
    );

    if (currentPoints.length != defaultPoints.length) return true;

    for (int i = 0; i < currentPoints.length; i++) {
      // Comparison with a small epsilon for floating point safety if needed,
      // but FlSpot values are usually exact from UI interaction.
      if ((currentPoints[i].x - defaultPoints[i].x).abs() > 0.01 ||
          (currentPoints[i].y - defaultPoints[i].y).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFDBA74), size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeSelector extends ConsumerWidget {
  const _TypeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isTempMode = ref.watch(editingTemperatureProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Center(
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment<bool>(
              value: false,
              label: Text(l10n.chartModeBrightness),
              icon: const Icon(LucideIcons.sun),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(l10n.chartModeTemperature),
              icon: const Icon(LucideIcons.thermometer),
            ),
          ],
          selected: {isTempMode},
          onSelectionChanged: (Set<bool> newSelection) {
            ref
                .read(editingTemperatureProvider.notifier)
                .set(newSelection.first);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFF97316).withOpacity(0.2);
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFF97316);
              }
              return Colors.white70;
            }),
          ),
        ),
      ),
    );
  }
}

class _TempToggleCard extends ConsumerWidget {
  const _TempToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = ref.watch(isColorTemperatureEnabledProvider);
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.blueLightFilter,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.blueLightFilterSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (val) {
              ref.read(isColorTemperatureEnabledProvider.notifier).set(val);
            },
            activeColor: const Color(0xFFF97316),
          ),
        ],
      ),
    );
  }
}
