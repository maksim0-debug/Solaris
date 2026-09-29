import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SolarPhaseResetButton extends ConsumerWidget {
  const SolarPhaseResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isTemp = ref.watch(editingTemperatureProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final settingsMap = ref.watch(settingsProvider).value;
    final currentSettings =
        settingsMap?[selectedIds.firstOrNull ?? 'all'] ??
        settingsMap?['all'] ??
        SettingsState();
    final config = currentSettings.phasesConfig;

    if (!config.isModified(isTemp: isTemp)) {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () {
        ref
            .read(settingsProvider.notifier)
            .updatePhasesConfig(config.resetToDefault(isTemp: isTemp));
      },
      icon: const Icon(LucideIcons.rotateCcw, size: 13),
      label: Text(l10n.reset, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.accent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }
}

/// Renders the four circadian phase cards (Night, Sunrise, Day, Sunset).
///
/// [showResetButton] controls whether an embedded reset button is rendered in
/// the card header. In the primary settings screen, this is hosted in the
/// circadian mode selector to align with the section layout, but can be enabled
/// when this widget is displayed in isolated previews or standalone views.
class SolarPhaseCardsWidget extends ConsumerWidget {
  final bool showResetButton;
  const SolarPhaseCardsWidget({super.key, this.showResetButton = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isTemp = ref.watch(editingTemperatureProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final settingsMap = ref.watch(settingsProvider).value;
    final currentSettings =
        settingsMap?[selectedIds.firstOrNull ?? 'all'] ??
        settingsMap?['all'] ??
        SettingsState();
    final config = currentSettings.phasesConfig;
    final solarAsync = ref.watch(solarStateStreamProvider);
    final phases = solarAsync.value?.phases;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showResetButton && config.isModified(isTemp: isTemp))
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0, right: 4.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: SolarPhaseResetButton(),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cardList = [
              _PhaseCardItem(
                name: l10n.phaseNight,
                icon: LucideIcons.moon,
                phaseColor: const Color(0xFF818CF8),
                timeStr: phases != null
                    ? DateFormat.Hm().format(phases.astronomicalDusk)
                    : null,
                target: config.night,
                isTemp: isTemp,
                onChanged: (updated) {
                  ref
                      .read(settingsProvider.notifier)
                      .updatePhasesConfig(config.copyWith(night: updated));
                },
              ),
              _PhaseCardItem(
                name: l10n.phaseSunrise,
                icon: LucideIcons.sunrise,
                phaseColor: const Color(0xFFFB923C),
                timeStr: phases != null
                    ? DateFormat.Hm().format(phases.sunrise)
                    : null,
                target: config.sunrise,
                isTemp: isTemp,
                onChanged: (updated) {
                  ref
                      .read(settingsProvider.notifier)
                      .updatePhasesConfig(config.copyWith(sunrise: updated));
                },
              ),
              _PhaseCardItem(
                name: l10n.phaseDay,
                icon: LucideIcons.sun,
                phaseColor: const Color(0xFFFBBF24),
                timeStr: phases != null
                    ? DateFormat.Hm().format(phases.solarNoon)
                    : null,
                tooltip: l10n.phasePlateauTooltip,
                target: config.day,
                isTemp: isTemp,
                onChanged: (updated) {
                  ref
                      .read(settingsProvider.notifier)
                      .updatePhasesConfig(config.copyWith(day: updated));
                },
              ),
              _PhaseCardItem(
                name: l10n.phaseSunset,
                icon: LucideIcons.sunset,
                phaseColor: const Color(0xFFF43F5E),
                timeStr: phases != null
                    ? DateFormat.Hm().format(phases.sunset)
                    : null,
                target: config.sunset,
                isTemp: isTemp,
                onChanged: (updated) {
                  ref
                      .read(settingsProvider.notifier)
                      .updatePhasesConfig(config.copyWith(sunset: updated));
                },
              ),
            ];

            if (isWide) {
              return Row(
                children: cardList
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: card,
                        ),
                      ),
                    )
                    .toList(),
              );
            } else {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cardList
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 8.1) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            }
          },
        ),
      ],
    );
  }
}

class _PhaseCardItem extends StatefulWidget {
  final String name;
  final IconData icon;
  final Color phaseColor;
  final String? timeStr;
  final String? tooltip;
  final PhaseTarget target;
  final bool isTemp;
  final ValueChanged<PhaseTarget> onChanged;

  const _PhaseCardItem({
    required this.name,
    required this.icon,
    required this.phaseColor,
    this.timeStr,
    this.tooltip,
    required this.target,
    required this.isTemp,
    required this.onChanged,
  });

  @override
  State<_PhaseCardItem> createState() => _PhaseCardItemState();
}

class _PhaseCardItemState extends State<_PhaseCardItem> {
  bool _isHovered = false;

  void _showKeyboardInputDialog(BuildContext context) {
    final int minVal = widget.isTemp ? TemperatureConstants.min : 0;
    final int maxVal = widget.isTemp ? TemperatureConstants.max : 100;
    final int currentVal = widget.isTemp
        ? widget.target.temperature
        : widget.target.brightness.round();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return _PhaseTargetInputDialog(
          name: widget.name,
          icon: widget.icon,
          phaseColor: widget.phaseColor,
          isTemp: widget.isTemp,
          minVal: minVal,
          maxVal: maxVal,
          initialVal: currentVal,
          onSave: (clamped) {
            if (widget.isTemp) {
              widget.onChanged(widget.target.copyWith(temperature: clamped));
            } else {
              widget.onChanged(
                widget.target.copyWith(brightness: clamped.toDouble()),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valueDisplay = widget.isTemp
        ? '${widget.target.temperature}K'
        : '${widget.target.brightness.round()}%';
    final minVal = widget.isTemp ? TemperatureConstants.minDouble : 0.0;
    final maxVal = widget.isTemp ? TemperatureConstants.maxDouble : 100.0;
    final sliderVal = widget.isTemp
        ? widget.target.temperature.toDouble().clamp(minVal, maxVal)
        : widget.target.brightness.clamp(0.0, 100.0);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _isHovered = false);
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 14,
          opacity: 0.04,
          borderColor: _isHovered
              ? AppTheme.accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          borderWidth: 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.phaseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.phaseColor.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 14,
                      color: widget.phaseColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.tooltip != null) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: widget.tooltip!,
                                child: Icon(
                                  LucideIcons.info,
                                  size: 11,
                                  color: AppTheme.accent.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.timeStr != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.timeStr!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Value Badge - tap to edit via keyboard
                  Tooltip(
                    message: l10n.tapToEnterValue,
                    child: InkWell(
                      onTap: () => _showKeyboardInputDialog(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              valueDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.pencil,
                              size: 9.5,
                              color: AppTheme.accent.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Interactive Slider
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                    elevation: 1,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                  activeTrackColor: AppTheme.accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: Colors.white,
                  overlayColor: AppTheme.accent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: sliderVal,
                  min: minVal,
                  max: maxVal,
                  onChanged: (val) {
                    if (widget.isTemp) {
                      widget.onChanged(
                        widget.target.copyWith(temperature: val.round()),
                      );
                    } else {
                      widget.onChanged(
                        widget.target.copyWith(brightness: val.roundToDouble()),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseTargetInputDialog extends StatefulWidget {
  final String name;
  final IconData icon;
  final Color phaseColor;
  final bool isTemp;
  final int minVal;
  final int maxVal;
  final int initialVal;
  final ValueChanged<int> onSave;

  const _PhaseTargetInputDialog({
    required this.name,
    required this.icon,
    required this.phaseColor,
    required this.isTemp,
    required this.minVal,
    required this.maxVal,
    required this.initialVal,
    required this.onSave,
  });

  @override
  State<_PhaseTargetInputDialog> createState() =>
      _PhaseTargetInputDialogState();
}

class _PhaseTargetInputDialogState extends State<_PhaseTargetInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final valStr = widget.initialVal.toString();
    _controller = TextEditingController(text: valStr)
      ..selection = TextSelection(baseOffset: 0, extentOffset: valStr.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext dialogCtx, String raw) {
    final parsed = int.tryParse(raw);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.minVal, widget.maxVal);
      widget.onSave(clamped);
    }
    Navigator.of(dialogCtx).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Icon(widget.icon, color: widget.phaseColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.name} (${widget.isTemp ? l10n.chartModeTemperature : l10n.chartModeBrightness})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.tapToEnterValue} (${widget.minVal} - ${widget.maxVal}):',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              suffixText: widget.isTemp ? 'K' : '%',
              suffixStyle: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accent,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (value) => _submit(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
          ),
          onPressed: () => _submit(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
