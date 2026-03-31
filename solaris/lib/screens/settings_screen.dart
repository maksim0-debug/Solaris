import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hotkey_manager/hotkey_manager.dart';

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

          // Language Selection
          const _LanguageSelectorCard(),
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

          const _GlobalHotkeysCard(),
          const SizedBox(height: 24),

          const _LanguageSelectorCard(),
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

class _GlobalHotkeysCard extends ConsumerWidget {
  const _GlobalHotkeysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedIds.firstOrNull ?? 'all';

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
                      color: const Color(0xFF60A5FA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.keyboard,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.globalHotkeys,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        l10n.globalHotkeysSubtitle,
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
              _HotkeyRow(
                label: l10n.brighterPreset,
                hotKeyJson: settings.brighterHotKey,
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('brighter', newHotKey?.toJson());
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              _HotkeyRow(
                label: l10n.darkerPreset,
                hotKeyJson: settings.darkerHotKey,
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('darker', newHotKey?.toJson());
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox(),
    );
  }
}

class _HotkeyRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? hotKeyJson;
  final ValueChanged<HotKey?> onChanged;

  const _HotkeyRow({
    required this.label,
    required this.hotKeyJson,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    HotKey? hotKey;
    if (hotKeyJson != null) {
      try {
        hotKey = HotKey.fromJson(hotKeyJson!);
      } catch (e) {
        debugPrint('Error parsing hotkey: $e');
        hotKey = null;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hotKey == null ? l10n.disabled : _formatHotKey(hotKey),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _PremiumHotkeyRecorder(
              initialHotKey: hotKey,
              onHotKeyRecorded: onChanged,
            ),
            if (hotKey != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () => onChanged(null),
                color: Colors.white24,
                hoverColor: Colors.red.withOpacity(0.1),
                tooltip: l10n.reset,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatHotKey(HotKey hotKey) {
    final List<String> parts = [];
    if (hotKey.modifiers != null) {
      for (final modifier in hotKey.modifiers!) {
        switch (modifier) {
          case HotKeyModifier.control:
            parts.add('Ctrl');
            break;
          case HotKeyModifier.shift:
            parts.add('Shift');
            break;
          case HotKeyModifier.alt:
            parts.add('Alt');
            break;
          case HotKeyModifier.meta:
            parts.add('Win');
            break;
          case HotKeyModifier.capsLock:
            parts.add('Caps');
            break;
          case HotKeyModifier.fn:
            parts.add('Fn');
            break;
        }
      }
    }

    String keyLabel = hotKey.logicalKey.keyLabel;
    if (hotKey.logicalKey == LogicalKeyboardKey.arrowUp) {
      keyLabel = '\u2191';
    } else if (hotKey.logicalKey == LogicalKeyboardKey.arrowDown) {
      keyLabel = '\u2193';
    } else if (hotKey.logicalKey == LogicalKeyboardKey.arrowLeft) {
      keyLabel = '\u2190';
    } else if (hotKey.logicalKey == LogicalKeyboardKey.arrowRight) {
      keyLabel = '\u2192';
    } else if (keyLabel.isEmpty) {
      keyLabel = hotKey.logicalKey.debugName ?? 'Key';
      if (keyLabel.startsWith('Key ')) keyLabel = keyLabel.substring(4);
    }

    parts.add(keyLabel.toUpperCase());
    return parts.join(' + ');
  }
}

class _PremiumHotkeyRecorder extends StatefulWidget {
  final HotKey? initialHotKey;
  final ValueChanged<HotKey?> onHotKeyRecorded;

  const _PremiumHotkeyRecorder({
    required this.initialHotKey,
    required this.onHotKeyRecorded,
  });

  @override
  State<_PremiumHotkeyRecorder> createState() => _PremiumHotkeyRecorderState();
}

class _PremiumHotkeyRecorderState extends State<_PremiumHotkeyRecorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isRecording = false;
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _pressedKeys.clear();
    });
    _focusNode.requestFocus();
  }

  void _stopRecording(HotKey? hotKey) {
    setState(() {
      _isRecording = false;
      _pressedKeys.clear();
    });
    _focusNode.unfocus();
    if (hotKey != null) {
      widget.onHotKeyRecorded(hotKey);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isRecording) return;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _stopRecording(null);
        return;
      }

      setState(() {
        _pressedKeys.add(event.logicalKey);
      });

      // Check if it's a non-modifier key
      if (!_isModifier(event.logicalKey)) {
        final modifiers = _currentModifiers();
        final key = event.physicalKey;

        final hotKey = HotKey(key: key, modifiers: modifiers);
        _stopRecording(hotKey);
      }
    } else if (event is KeyUpEvent) {
      setState(() {
        _pressedKeys.remove(event.logicalKey);
      });
    }
  }

  bool _isModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  List<HotKeyModifier> _currentModifiers() {
    final modifiers = <HotKeyModifier>[];
    if (_pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.controlRight)) {
      modifiers.add(HotKeyModifier.control);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.shiftRight)) {
      modifiers.add(HotKeyModifier.shift);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.altRight)) {
      modifiers.add(HotKeyModifier.alt);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.metaRight)) {
      modifiers.add(HotKeyModifier.meta);
    }
    return modifiers;
  }

  // Helper removed as direct access to physicalKey/logicalKey is easier

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: _startRecording,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glowColor = const Color(0xFF60A5FA).withOpacity(
              _isRecording ? 0.2 + (0.1 * _pulseController.value) : 0,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isRecording
                      ? const Color(0xFF60A5FA).withOpacity(0.5)
                      : Colors.white.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  if (_isRecording)
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildContent(l10n),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(AppLocalizations l10n) {
    if (_isRecording) {
      if (_pressedKeys.isEmpty) {
        return [
          const Icon(LucideIcons.circle, size: 10, color: Color(0xFF60A5FA)),
          const SizedBox(width: 10),
          Text(
            l10n.pressToRecord,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ];
      }

      return _pressedKeys.map((key) => _buildKeyBadge(key)).toList();
    }

    if (widget.initialHotKey == null) {
      return [
        Text(
          l10n.disabled,
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.2)),
        ),
      ];
    }

    // Display current hotkey nicely
    final hotKey = widget.initialHotKey!;
    final List<Widget> widgets = [];

    for (final modifier in hotKey.modifiers ?? <HotKeyModifier>[]) {
      widgets.add(_buildModifierBadge(modifier));
      widgets.add(const SizedBox(width: 4));
    }

    widgets.add(_buildKeyBadge(hotKey.logicalKey));

    return widgets;
  }

  Widget _buildKeyBadge(LogicalKeyboardKey key) {
    String? label = key.keyLabel;
    IconData? icon;

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      label = 'Ctrl';
    } else if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      label = 'Shift';
      icon = LucideIcons.arrowUp;
    } else if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      label = 'Alt';
      icon = LucideIcons.option;
    } else if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      label = 'Win';
      icon = LucideIcons.command;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      label = null;
      icon = LucideIcons.arrowBigUp;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      label = null;
      icon = LucideIcons.arrowBigDown;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      label = null;
      icon = LucideIcons.arrowBigLeft;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      label = null;
      icon = LucideIcons.arrowBigRight;
    } else if (key == LogicalKeyboardKey.space) {
      label = 'Space';
    } else if (key == LogicalKeyboardKey.enter) {
      label = 'Enter';
    } else {
      // For character keys (A-Z, 0-9), keyLabel is exactly what we want.
      // We capitalize it for consistency.
      if (label.isEmpty) {
        label = key.debugName ?? '';
        if (label.startsWith('Key ')) label = label.substring(4);
      }
      label = label.toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _Badge(label: label, icon: icon, isModifier: _isModifier(key)),
    );
  }

  Widget _buildModifierBadge(HotKeyModifier modifier) {
    String label = modifier.name;
    IconData? icon;
    switch (modifier) {
      case HotKeyModifier.control:
        label = 'Ctrl';
        break;
      case HotKeyModifier.shift:
        label = 'Shift';
        icon = LucideIcons.arrowUp;
        break;
      case HotKeyModifier.alt:
        label = 'Alt';
        icon = LucideIcons.option;
        break;
      case HotKeyModifier.meta:
        label = 'Win';
        icon = LucideIcons.command;
        break;
      default:
        break;
    }
    return _Badge(label: label, icon: icon, isModifier: true);
  }

  // consolidated into _buildKeyBadge
}

class _Badge extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isModifier;

  const _Badge({this.label, this.icon, this.isModifier = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isModifier
            ? const Color(0xFF60A5FA).withOpacity(0.15)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isModifier
              ? const Color(0xFF60A5FA).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 10,
              color: isModifier ? const Color(0xFF60A5FA) : Colors.white70,
            ),
            if (label != null) const SizedBox(width: 4),
          ],
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isModifier ? const Color(0xFF60A5FA) : Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageSelectorCard extends ConsumerWidget {
  const _LanguageSelectorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF60A5FA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.languages,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.language,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(value: 'en', label: Text(l10n.english)),
              ButtonSegment<String>(value: 'ru', label: Text(l10n.russian)),
            ],
            selected: {currentLocale.languageCode},
            onSelectionChanged: (Set<String> newSelection) {
              ref.read(localeProvider.notifier).setLocale(newSelection.first);
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.transparent,
              selectedBackgroundColor: const Color(0xFF60A5FA).withOpacity(0.2),
              selectedForegroundColor: const Color(0xFF60A5FA),
              foregroundColor: Colors.white24,
              side: BorderSide(color: Colors.white.withOpacity(0.05)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
