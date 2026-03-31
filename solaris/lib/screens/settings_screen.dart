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
                  onChanged: (val) =>
                      ref.read(settingsProvider.notifier).updateAutorun(val),
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

          const _SmartExclusionsCard(),
          const SizedBox(height: 24),

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
          final settings =
              tempMap[selectedIds.firstOrNull ?? 'all'] ?? tempMap['all']!;
          return _buildSelector<TemperaturePresetType>(
            context: context,
            values: TemperaturePresetType.values,
            activeValue: settings.activePreset,
            getName: (type) => type.getName(l10n),
            onSelected: (type) =>
                ref.read(temperatureSettingsProvider.notifier).setPreset(type),
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
              settingsMap[selectedIds.firstOrNull ?? 'all'] ??
              settingsMap['all']!;
          return _buildSelector<PresetType>(
            context: context,
            values: PresetType.values,
            activeValue: settings.activePreset,
            getName: (type) => type.getName(l10n),
            onSelected: (type) =>
                ref.read(settingsProvider.notifier).setActivePreset(type),
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

class _SmartExclusionsCard extends ConsumerWidget {
  const _SmartExclusionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedIds.firstOrNull ?? 'all';
    final l10n = AppLocalizations.of(context)!;

    return settingsAsync.maybeWhen(
      data: (map) {
        final settings = map[monitorId] ?? map['all']!;
        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.gamepad2,
                      color: Color(0xFFA855F7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.smartExclusions,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        l10n.smartExclusionsSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsRow(
                title: l10n.enableGameMode,
                subtitle: l10n.enableGameModeSubtitle,
                value: settings.isGameModeEnabled,
                onChanged: (val) => ref
                    .read(settingsProvider.notifier)
                    .updateGameModeEnabled(val),
              ),
              if (settings.isGameModeEnabled) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.lockedBrightness,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${settings.gameModeBrightness.round()}%',
                      style: const TextStyle(
                        color: Color(0xFFA855F7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.gameModeBrightness,
                  min: 0,
                  max: 100,
                  activeColor: const Color(0xFFA855F7),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateGameModeBrightness(val);
                  },
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                _AppListManager(
                  title: l10n.whitelist,
                  subtitle: l10n.whitelistSubtitle,
                  items: settings.gameModeWhitelist,
                  onAdd: (item) => ref
                      .read(settingsProvider.notifier)
                      .addWhitelistItem(item),
                  onRemove: (item) => ref
                      .read(settingsProvider.notifier)
                      .removeWhitelistItem(item),
                  accentColor: const Color(0xFFA855F7),
                ),
                const SizedBox(height: 24),
                _AppListManager(
                  title: l10n.blacklist,
                  subtitle: l10n.blacklistSubtitle,
                  items: settings.gameModeBlacklist,
                  onAdd: (item) => ref
                      .read(settingsProvider.notifier)
                      .addBlacklistItem(item),
                  onRemove: (item) => ref
                      .read(settingsProvider.notifier)
                      .removeBlacklistItem(item),
                  accentColor: Colors.redAccent,
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox(),
    );
  }
}

class _AppListManager extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final Color accentColor;

  const _AppListManager({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.accentColor,
  });

  @override
  State<_AppListManager> createState() => _AppListManagerState();
}

class _AppListManagerState extends State<_AppListManager> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim().toLowerCase();
    if (text.isNotEmpty) {
      if (!text.endsWith('.exe') && !text.contains('.')) {
        widget.onAdd('$text.exe');
      } else {
        widget.onAdd(text);
      }
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. game.exe',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _submit,
              icon: const Icon(LucideIcons.plus, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: widget.accentColor.withOpacity(0.1),
                foregroundColor: widget.accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.items.map((item) {
              return Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => widget.onRemove(item),
                      color: Colors.white30,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
