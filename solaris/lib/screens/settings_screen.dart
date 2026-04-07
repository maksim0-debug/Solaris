import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
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
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'package:solaris/widgets/deep_link_target.dart';
import 'package:solaris/screens/privacy_policy_screen.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<DeepLinkTargetState>> _anchorKeys = {
    'autorun': GlobalKey<DeepLinkTargetState>(),
    'weather_adjustment': GlobalKey<DeepLinkTargetState>(),
    'hotkeys': GlobalKey<DeepLinkTargetState>(),
    'circadian_regulation': GlobalKey<DeepLinkTargetState>(),
    'circadian_limits': GlobalKey<DeepLinkTargetState>(),
    'language': GlobalKey<DeepLinkTargetState>(),
    'schedule_view': GlobalKey<DeepLinkTargetState>(),
    'game_mode': GlobalKey<DeepLinkTargetState>(),
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
        alignment: 0.5, // Center the item
      );
      key.currentState?.highlight();
      
      // Clear the anchor after consuming it
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
    final selectedIds = ref.watch(selectedMonitorsProvider);

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

    return SingleChildScrollView(
      controller: _scrollController,
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
          DeepLinkTarget(
            key: _anchorKeys['circadian_regulation'],
            id: 'circadian_regulation',
            child: DeepLinkTarget(
              key: _anchorKeys['schedule_view'],
              id: 'schedule_view',
              child: Column(
                children: [
                  const _PresetSelector(),
                  const SizedBox(height: 8),
                  const _TypeSelector(),
                  const SizedBox(height: 8),
                  const CircadianChartWidget(),
                  const SizedBox(height: 8),
                  const _TempToggleCard(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Language Selection
          DeepLinkTarget(
            key: _anchorKeys['language'],
            id: 'language',
            child: _LanguageSelectorCard(anchorKeys: _anchorKeys),
          ),
          const SizedBox(height: 24),

          // App Settings (Autorun)
          DeepLinkTarget(
            key: _anchorKeys['autorun'],
            id: 'autorun',
            child: GlassCard(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Weather Settings
          DeepLinkTarget(
            key: _anchorKeys['weather_adjustment'],
            id: 'weather_adjustment',
            child: GlassCard(
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
                          LucideIcons.cloudSun,
                          color: Color(0xFFFDBA74),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weatherAdjustmentTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            l10n.weatherAdjustmentSubtitle,
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
                  
                  // Animated appearance of intensity slider
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final monitorId = selectedIds.firstOrNull ?? 'all';
                            final settings = settingsAsync.maybeWhen(
                              data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
                              orElse: () => SettingsState(),
                            );
                            
                            return Column(
                              children: [
                                _IntensitySlider(
                                  label: l10n.weatherIntensity,
                                  value: settings.weatherAdjustmentIntensity,
                                  color: const Color(0xFFFDBA74),
                                  onChanged: (val) => ref
                                      .read(settingsProvider.notifier)
                                      .updateWeatherAdjustmentIntensity(val),
                                ),
                                const SizedBox(height: 24),
                                _WeatherProviderSelector(
                                  selectedProvider: settings.weatherProvider,
                                  onChanged: (WeatherProvider provider) => ref
                                      .read(settingsProvider.notifier)
                                      .updateWeatherProvider(provider),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    crossFadeState: settingsAsync.maybeWhen(
                      data: (map) => (map[selectedIds.firstOrNull ?? 'all']?.isWeatherAdjustmentEnabled ?? map['all']?.isWeatherAdjustmentEnabled ?? true) 
                          ? CrossFadeState.showSecond 
                          : CrossFadeState.showFirst,
                      orElse: () => CrossFadeState.showFirst,
                    ),
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOutCubic,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          DeepLinkTarget(
            key: _anchorKeys['circadian_limits'],
            id: 'circadian_limits',
            child: _SmartExclusionsCard(anchorKeys: _anchorKeys),
          ),
          const SizedBox(height: 24),

          DeepLinkTarget(
            key: _anchorKeys['hotkeys'],
            id: 'hotkeys',
            child: _GlobalHotkeysCard(anchorKeys: _anchorKeys),
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
          const _LegalSection(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                l10n.legalSubtitle,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.fileText, color: Colors.white70, size: 20),
            title: Text(
              l10n.privacyPolicy,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              l10n.privacyPolicySubtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            trailing: const Icon(LucideIcons.chevronRight, color: Colors.white24, size: 18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
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

class _PresetSelector extends ConsumerStatefulWidget {
  const _PresetSelector();

  @override
  ConsumerState<_PresetSelector> createState() => _PresetSelectorState();
}

class _PresetSelectorState extends ConsumerState<_PresetSelector> {
  void _showNamingDialog({
    required BuildContext context,
    required bool isTemp,
    String? initialName,
    String? renameId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialName);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(renameId != null ? l10n.rename : l10n.savePreset),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.namePresetHint,
            labelText: l10n.presetName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (renameId != null) {
                  if (isTemp) {
                    ref
                        .read(temperatureSettingsProvider.notifier)
                        .renameUserPreset(renameId, controller.text);
                  } else {
                    ref
                        .read(settingsProvider.notifier)
                        .renameUserPreset(renameId, controller.text);
                  }
                } else {
                  if (isTemp) {
                    ref
                        .read(temperatureSettingsProvider.notifier)
                        .saveAsNewPreset(controller.text);
                  } else {
                    ref
                        .read(settingsProvider.notifier)
                        .saveAsNewPreset(controller.text);
                  }
                }
                Navigator.pop(context);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm({
    required BuildContext context,
    required bool isTemp,
    required String id,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(l10n.deletePresetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (isTemp) {
                ref
                    .read(temperatureSettingsProvider.notifier)
                    .deleteUserPreset(id);
              } else {
                ref.read(settingsProvider.notifier).deleteUserPreset(id);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTemp = ref.watch(editingTemperatureProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);

    if (isTemp) {
      final tempAsync = ref.watch(temperatureSettingsProvider);
      return tempAsync.maybeWhen(
        data: (tempMap) {
          final settings =
              tempMap[selectedIds.firstOrNull ?? 'all'] ?? tempMap['all']!;
          return _buildPresetBar(
            context: context,
            isTemp: true,
            systemPresets: TemperaturePresetType.values,
            userPresets: settings.userPresets,
            activePreset: settings.activePreset,
            activeUserPresetId: settings.activeUserPresetId,
            getName: (type) => (type as TemperaturePresetType).getName(l10n),
            onSystemSelected: (type) =>
                ref
                    .read(temperatureSettingsProvider.notifier)
                    .setPreset(type as TemperaturePresetType),
            onUserSelected: (id) =>
                ref
                    .read(temperatureSettingsProvider.notifier)
                    .setActiveUserPreset(id),
            onReorder: (oldIndex, newIndex) =>
                ref
                    .read(temperatureSettingsProvider.notifier)
                    .reorderAllPresets(oldIndex, newIndex),
            presetOrder: settings.presetOrder,
            resetButton: _ResetTempButton(settings: settings),
            saveButton: _SavePresetButton(
              isModified: _isTempModified(settings),
              onPressed: () => _showNamingDialog(context: context, isTemp: true),
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
              settingsMap[selectedIds.firstOrNull ?? 'all'] ??
              settingsMap['all']!;
          return _buildPresetBar(
            context: context,
            isTemp: false,
            systemPresets: PresetType.values,
            userPresets: settings.userPresets,
            activePreset: settings.activePreset,
            activeUserPresetId: settings.activeUserPresetId,
            getName: (type) => (type as PresetType).getName(l10n),
            onSystemSelected: (type) =>
                ref
                    .read(settingsProvider.notifier)
                    .setActivePreset(type as PresetType),
            onUserSelected: (id) =>
                ref.read(settingsProvider.notifier).setActiveUserPreset(id),
            onReorder: (oldIndex, newIndex) =>
                ref
                    .read(settingsProvider.notifier)
                    .reorderAllPresets(oldIndex, newIndex),
            presetOrder: settings.presetOrder,
            resetButton: _ResetButton(settings: settings),
            saveButton: _SavePresetButton(
              isModified: _isBrightnessModified(settings),
              onPressed:
                  () => _showNamingDialog(context: context, isTemp: false),
            ),
          );
        },
        orElse: () => const SizedBox(),
      );
    }
  }

  bool _isBrightnessModified(SettingsState settings) {
    final currentPoints = settings.curvePoints;
    List<FlSpot> defaultPoints;

    if (settings.activeUserPresetId != null) {
      try {
        final up = settings.userPresets.firstWhere(
          (p) => p.id == settings.activeUserPresetId,
        );
        defaultPoints = up.initialPoints;
      } catch (_) {
        return false;
      }
    } else {
      defaultPoints = PresetConstants.getDefaultPoints(settings.activePreset);
    }

    if (currentPoints.length != defaultPoints.length) return true;
    for (int i = 0; i < currentPoints.length; i++) {
      if ((currentPoints[i].x - defaultPoints[i].x).abs() > 0.01 ||
          (currentPoints[i].y - defaultPoints[i].y).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }

  bool _isTempModified(TemperatureState settings) {
    final currentPoints = settings.curvePoints;
    List<FlSpot> defaultPoints;

    if (settings.activeUserPresetId != null) {
      try {
        final up = settings.userPresets.firstWhere(
          (p) => p.id == settings.activeUserPresetId,
        );
        defaultPoints = up.initialPoints;
      } catch (_) {
        return false;
      }
    } else {
      defaultPoints = PresetConstants.getTemperatureDefaultPoints(
        settings.activePreset,
      );
    }

    if (currentPoints.length != defaultPoints.length) return true;
    for (int i = 0; i < currentPoints.length; i++) {
      if ((currentPoints[i].x - defaultPoints[i].x).abs() > 0.01 ||
          (currentPoints[i].y - defaultPoints[i].y).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }

  Widget _buildPresetBar({
    required BuildContext context,
    required bool isTemp,
    required List<dynamic> systemPresets,
    required List<UserPreset> userPresets,
    required dynamic activePreset,
    required String? activeUserPresetId,
    required String Function(dynamic) getName,
    required void Function(dynamic) onSystemSelected,
    required void Function(String) onUserSelected,
    required void Function(int, int) onReorder,
    required List<String> presetOrder,
    required Widget resetButton,
    required Widget saveButton,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: presetOrder.length,
                buildDefaultDragHandles: false,
                onReorder: onReorder,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final double animValue = Curves.easeInOut.transform(animation.value);
                      final double scale = lerpDouble(1, 1.05, animValue)!;
                      return Transform.scale(
                        scale: scale,
                        child: _WiggleWrapper(
                          enabled: true,
                          child: Material(
                            color: Colors.transparent,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final orderId = presetOrder[index];
                  if (orderId.startsWith('system:')) {
                    final typeName = orderId.substring(7);
                    final type = isTemp
                        ? TemperaturePresetType.values.firstWhere((e) => e.name == typeName)
                        : PresetType.values.firstWhere((e) => e.name == typeName);
                    
                    final isActive = activeUserPresetId == null && type == activePreset;
                    
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(orderId),
                      index: index,
                      child: _PresetChip(
                        label: getName(type),
                        isActive: isActive,
                        onPressed: () => onSystemSelected(type),
                      ),
                    );
                  } else {
                    final userId = orderId.substring(5);
                    final up = userPresets.firstWhere((p) => p.id == userId);
                    final isActive = activeUserPresetId == up.id;
                    
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(orderId),
                      index: index,
                      child: _PresetChip(
                        label: up.name,
                        isActive: isActive,
                        onPressed: () => onUserSelected(up.id),
                        onSecondaryTap: () => _showPresetMenu(context, up, isTemp),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          saveButton,
          const VerticalDivider(width: 1, indent: 8, endIndent: 8, color: Colors.white10),
          const SizedBox(width: 8),
          resetButton,
        ],
      ),
    );
  }

  void _showPresetMenu(BuildContext context, UserPreset up, bool isTemp) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.edit2, color: Colors.white70),
              title: Text(l10n.rename, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showNamingDialog(
                  context: context,
                  isTemp: isTemp,
                  initialName: up.name,
                  renameId: up.id,
                );
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(context: context, isTemp: isTemp, id: up.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback? onSecondaryTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onSecondaryTap: onSecondaryTap,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: isActive
                ? const Color(0xFFFDBA74).withOpacity(0.1)
                : Colors.transparent,
            foregroundColor:
                isActive ? const Color(0xFFFDBA74) : Colors.white24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isActive
                    ? const Color(0xFFFDBA74).withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _WiggleWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _WiggleWrapper({required this.child, this.enabled = true});

  @override
  State<_WiggleWrapper> createState() => _WiggleWrapperState();
}

class _WiggleWrapperState extends State<_WiggleWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WiggleWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Subtle wiggle: +/- 1.5 degrees
        final double rotation = widget.enabled 
            ? (math.sin(_controller.value * math.pi * 2) * 0.02) 
            : 0;
        return Transform.rotate(
          angle: rotation,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SavePresetButton extends StatelessWidget {
  final bool isModified;
  final VoidCallback onPressed;

  const _SavePresetButton({required this.isModified, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.plusCircle),
      onPressed: isModified ? onPressed : null,
      color: const Color(0xFFFDBA74),
      disabledColor: Colors.white10,
      tooltip: AppLocalizations.of(context)!.savePreset,
    );
  }
}

class _ResetTempButton extends ConsumerWidget {
  final TemperatureState settings;
  const _ResetTempButton({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isModified = _isModified();

    return IconButton(
      onPressed: isModified
          ? () =>
              ref.read(temperatureSettingsProvider.notifier).resetCurrentPreset()
          : null,
      icon: const Icon(LucideIcons.rotateCcw, size: 18),
      color: const Color(0xFFFDBA74),
      disabledColor: Colors.white10,
      tooltip: AppLocalizations.of(context)!.reset,
    );
  }

  bool _isModified() {
    final currentPoints = settings.curvePoints;
    List<FlSpot> defaultPoints;

    if (settings.activeUserPresetId != null) {
      try {
        final up = settings.userPresets.firstWhere(
          (p) => p.id == settings.activeUserPresetId,
        );
        defaultPoints = up.initialPoints;
      } catch (_) {
        return false;
      }
    } else {
      if (settings.activePreset == TemperaturePresetType.custom) return false;
      defaultPoints = PresetConstants.getTemperatureDefaultPoints(
        settings.activePreset,
      );
    }

    if (currentPoints.length != defaultPoints.length) return true;

    for (int i = 0; i < currentPoints.length; i++) {
      if ((currentPoints[i].x - defaultPoints[i].x).abs() > 0.01 ||
          (currentPoints[i].y - defaultPoints[i].y).abs() > 0.01) {
        return true;
      }
    }
    return false;
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
    List<FlSpot> defaultPoints;

    if (settings.activeUserPresetId != null) {
      try {
        final up = settings.userPresets.firstWhere(
          (p) => p.id == settings.activeUserPresetId,
        );
        defaultPoints = up.initialPoints;
      } catch (_) {
        return false;
      }
    } else {
      defaultPoints = PresetConstants.getDefaultPoints(settings.activePreset);
    }

    if (currentPoints.length != defaultPoints.length) return true;

    for (int i = 0; i < currentPoints.length; i++) {
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
        Expanded(
          child: Column(
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
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _SmartExclusionsCard({required this.anchorKeys});

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
              DeepLinkTarget(
                key: anchorKeys['game_mode'],
                id: 'game_mode',
                child: _SettingsRow(
                  title: l10n.enableGameMode,
                  subtitle: l10n.enableGameModeSubtitle,
                  value: settings.isGameModeEnabled,
                  onChanged: (val) => ref
                      .read(settingsProvider.notifier)
                      .updateGameModeEnabled(val),
                ),
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
                      l10n.chartPercentFormat(settings.gameModeBrightness.round()),
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

class _GlobalHotkeysCard extends ConsumerWidget {
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _GlobalHotkeysCard({required this.anchorKeys});

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
                label: l10n.nextPreset,
                hotKeyJson: settings.nextPresetHotKey,
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('next_preset', newHotKey?.toJson());
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              _HotkeyRow(
                label: l10n.prevPreset,
                hotKeyJson: settings.prevPresetHotKey,
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('prev_preset', newHotKey?.toJson());
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              _HotkeyRow(
                label: l10n.increaseBrightness,
                hotKeyJson: settings.brightnessUpHotKey,
                trailing: _StepAdjustmentControl(
                  value: settings.brightnessStepUp,
                  onChanged: (val) => ref
                      .read(settingsProvider.notifier)
                      .updateBrightnessStep(true, val),
                ),
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('brightness_up', newHotKey?.toJson());
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              _HotkeyRow(
                label: l10n.decreaseBrightness,
                hotKeyJson: settings.brightnessDownHotKey,
                trailing: _StepAdjustmentControl(
                  value: settings.brightnessStepDown,
                  onChanged: (val) => ref
                      .read(settingsProvider.notifier)
                      .updateBrightnessStep(false, val),
                ),
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('brightness_down', newHotKey?.toJson());
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              _HotkeyRow(
                label: l10n.toggleAutoBrightness,
                hotKeyJson: settings.autoBrightnessHotKey,
                onChanged: (newHotKey) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateHotkey('auto_brightness_toggle', newHotKey?.toJson());
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
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
    final l10n = AppLocalizations.of(context)!;
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
                  hintText: l10n.gameModeHint,
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

class _StepAdjustmentControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StepAdjustmentControl({required this.value, required this.onChanged});

  @override
  State<_StepAdjustmentControl> createState() => _StepAdjustmentControlState();
}

class _StepAdjustmentControlState extends State<_StepAdjustmentControl> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 32, // Fixed height to prevent row height from jumping
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              size: 16,
              color: _isExpanded ? const Color(0xFF60A5FA) : Colors.white24,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            tooltip: l10n.brightnessStep,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _PremiumSlider(
                      value: widget.value,
                      onChanged: widget.onChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PremiumSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PremiumSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 130, // Compact but clear
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: const Color(0xFF60A5FA),
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF60A5FA).withOpacity(0.1),
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 20,
                divisions: 19,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: Text(
              l10n.chartPercentFormat(value.round()),
              style: const TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotkeyRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? hotKeyJson;
  final ValueChanged<HotKey?> onChanged;
  final Widget? trailing;

  const _HotkeyRow({
    required this.label,
    required this.hotKeyJson,
    required this.onChanged,
    this.trailing,
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
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
        ),
        const SizedBox(width: 16),
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
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _LanguageSelectorCard({required this.anchorKeys});

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
              ButtonSegment<String>(value: 'uk', label: Text(l10n.ukrainian)),
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
class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider({
    required this.label,
    required this.value,
    this.onChanged,
    required this.color,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.chartPercentFormat((value * 100).toInt()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: color.withOpacity(0.5),
            inactiveTrackColor: Colors.white10,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _WeatherProviderSelector extends StatelessWidget {
  final WeatherProvider selectedProvider;
  final ValueChanged<WeatherProvider> onChanged;

  const _WeatherProviderSelector({
    required this.selectedProvider,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.weatherProvider,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SegmentedButton<WeatherProvider>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<WeatherProvider>(
                value: WeatherProvider.auto,
                label: Text(
                  l10n.weatherProviderAuto,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(LucideIcons.zap, size: 14),
              ),
              ButtonSegment<WeatherProvider>(
                value: WeatherProvider.weatherApi,
                label: Text(
                  l10n.weatherProviderWeatherApi,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(LucideIcons.cloudRain, size: 14),
              ),
              ButtonSegment<WeatherProvider>(
                value: WeatherProvider.openMeteo,
                label: Text(
                  l10n.weatherProviderOpenMeteo,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(LucideIcons.sun, size: 14),
              ),
            ],
            selected: {selectedProvider},
            onSelectionChanged: (Set<WeatherProvider> newSelection) {
              onChanged(newSelection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFDBA74).withOpacity(0.2);
                }
                return Colors.white.withOpacity(0.05);
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFDBA74);
                }
                return Colors.white38;
              }),
              side: WidgetStateProperty.all(BorderSide.none),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
