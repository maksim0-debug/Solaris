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
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:intl/intl.dart';

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
                _SettingsRow(
                  title: l10n.autorun,
                  subtitle: l10n.autorunSubtitle,
                  value: settingsAsync.maybeWhen(
                    data: (map) => map['all']?.isAutorunEnabled ?? false,
                    orElse: () => false,
                  ),
                  onChanged: (val) => ref
                      .read(settingsProvider.notifier)
                      .updateAutorun(val),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                _SettingsRow(
                  title: l10n.weatherAdjustmentTitle,
                  subtitle: l10n.weatherAdjustmentSubtitle,
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

extension TemperaturePresetTypeExtension on TemperaturePresetType {
  String getName(AppLocalizations l10n) {
    switch (this) {
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
}

extension PresetTypeExtension on PresetType {
  String getName(AppLocalizations l10n) {
    switch (this) {
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
}

class _PresetSelector extends ConsumerWidget {
  const _PresetSelector();

  Widget _buildSelector<T>({
    required BuildContext context,
    required List<T> values,
    required T activeValue,
    required String Function(T) getName,
    required void Function(T) onSelected,
    required Widget resetButton,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: values.map((type) {
                  final isActive = type == activeValue;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextButton(
                      onPressed: () => onSelected(type),
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
                      child: Text(getName(type)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          resetButton,
        ],
      ),
    );
  }

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
          return _buildSelector<TemperaturePresetType>(
            context: context,
            values: TemperaturePresetType.values,
            activeValue: settings.activePreset,
            getName: (type) => type.getName(l10n),
            onSelected: (type) => ref
                .read(temperatureSettingsProvider.notifier)
                .setPreset(type),
            resetButton: _ResetTempButton(settings: settings),
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
          return _buildSelector<PresetType>(
            context: context,
            values: PresetType.values,
            activeValue: settings.activePreset,
            getName: (type) => type.getName(l10n),
            onSelected: (type) => ref
                .read(settingsProvider.notifier)
                .setActivePreset(type),
            resetButton: _ResetButton(settings: settings),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFFDBA74),
        ),
      ],
    );
  }
}

class _SleepDataSection extends ConsumerWidget {
  const _SleepDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final googleFitState = ref.watch(googleFitProvider);
    final isConnected = googleFitState.status == GoogleFitStatus.connected;
    final isConnecting = googleFitState.status == GoogleFitStatus.connecting;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref.read(googleFitProvider.notifier).toggleExpanded(),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.moon,
                    color: Color(0xFF60A5FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sleepData,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        l10n.sleepDataSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  googleFitState.isExpanded 
                    ? LucideIcons.chevronUp 
                    : LucideIcons.chevronDown,
                  color: Colors.white24,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? l10n.googleFitConnected : l10n.googleFitDisconnected,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? const Color(0xFF4ADE80) : Colors.white70,
                    ),
                  ),
                  if (googleFitState.lastFetchTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      googleFitState.lastFetchSuccess == true 
                        ? l10n.lastSyncSuccess 
                        : l10n.lastSyncFailed,
                      style: TextStyle(
                        fontSize: 11,
                        color: googleFitState.lastFetchSuccess == true 
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ],
              ),
              isConnecting 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF60A5FA)),
                  )
                : ElevatedButton(
                    onPressed: () {
                      if (isConnected) {
                        ref.read(googleFitProvider.notifier).signOut();
                      } else {
                        ref.read(googleFitProvider.notifier).signIn();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected 
                        ? Colors.white.withOpacity(0.05) 
                        : const Color(0xFF60A5FA).withOpacity(0.1),
                      foregroundColor: isConnected ? Colors.white70 : const Color(0xFF60A5FA),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isConnected 
                            ? Colors.white10 
                            : const Color(0xFF60A5FA).withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Text(isConnected ? l10n.disconnectGoogleFit : l10n.connectGoogleFit),
                  ),
            ],
          ),
          
          if (isConnected) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    if (googleFitState.sessions != null && googleFitState.sessions!.isNotEmpty) ...[
                      ...googleFitState.sessions!.take(5).map((session) {
                        final start = DateTime.fromMillisecondsSinceEpoch(int.parse(session.startTimeMillis!));
                        final end = DateTime.fromMillisecondsSinceEpoch(int.parse(session.endTimeMillis!));
                        final duration = end.difference(start);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, HH:mm').format(start),
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                  Text(
                                    'to ${DateFormat('HH:mm').format(end)}',
                                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF60A5FA),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (googleFitState.lastFetchTime != null) ...[
                      const Center(
                        child: Text(
                          'No sleep sessions found in the last 7 days.',
                          style: TextStyle(fontSize: 12, color: Colors.white24),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref.read(googleFitProvider.notifier).testSync(),
                      icon: const Icon(LucideIcons.refreshCcw, size: 14),
                      label: Text(l10n.testSync),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white24,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: googleFitState.isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ],
      ),
    );
  }
}
