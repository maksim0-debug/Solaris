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
import 'package:intl/intl.dart';

class SolarPhaseCardsWidget extends ConsumerWidget {
  const SolarPhaseCardsWidget({super.key});

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

    const def = SolarPhasesConfig.defaultBalanced;
    final isModified = isTemp
        ? (config.night.temperature != def.night.temperature ||
              config.sunrise.temperature != def.sunrise.temperature ||
              config.day.temperature != def.day.temperature ||
              config.sunset.temperature != def.sunset.temperature)
        : (config.night.brightness != def.night.brightness ||
              config.sunrise.brightness != def.sunrise.brightness ||
              config.day.brightness != def.day.brightness ||
              config.sunset.brightness != def.sunset.brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isModified)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final newConfig = isTemp
                        ? config.copyWith(
                            night: config.night.copyWith(
                              temperature: def.night.temperature,
                            ),
                            sunrise: config.sunrise.copyWith(
                              temperature: def.sunrise.temperature,
                            ),
                            day: config.day.copyWith(
                              temperature: def.day.temperature,
                            ),
                            sunset: config.sunset.copyWith(
                              temperature: def.sunset.temperature,
                            ),
                          )
                        : config.copyWith(
                            night: config.night.copyWith(
                              brightness: def.night.brightness,
                            ),
                            sunrise: config.sunrise.copyWith(
                              brightness: def.sunrise.brightness,
                            ),
                            day: config.day.copyWith(
                              brightness: def.day.brightness,
                            ),
                            sunset: config.sunset.copyWith(
                              brightness: def.sunset.brightness,
                            ),
                          );
                    ref
                        .read(settingsProvider.notifier)
                        .updatePhasesConfig(newConfig);
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 13),
                  label: Text(l10n.reset, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFDBA74),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cardList = [
              _PhaseCardItem(
                name: l10n.phaseNight,
                icon: LucideIcons.moon,
                accentColor: const Color(0xFF818CF8),
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
                accentColor: const Color(0xFFFB923C),
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
                accentColor: const Color(0xFFFBBF24),
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
                accentColor: const Color(0xFFF43F5E),
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

class _PhaseCardItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color accentColor;
  final String? timeStr;
  final String? tooltip;
  final PhaseTarget target;
  final bool isTemp;
  final ValueChanged<PhaseTarget> onChanged;

  const _PhaseCardItem({
    required this.name,
    required this.icon,
    required this.accentColor,
    this.timeStr,
    this.tooltip,
    required this.target,
    required this.isTemp,
    required this.onChanged,
  });

  void _showKeyboardInputDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int minVal = isTemp ? TemperatureConstants.min : 0;
    final int maxVal = isTemp ? TemperatureConstants.max : 100;
    final int currentVal = isTemp
        ? target.temperature
        : target.brightness.round();
    final controller = TextEditingController(text: currentVal.toString());

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$name (${isTemp ? l10n.chartModeTemperature : l10n.chartModeBrightness})',
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
                '${l10n.tapToEnterValue} ($minVal - $maxVal):',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
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
                  suffixText: isTemp ? 'K' : '%',
                  suffixStyle: TextStyle(
                    color: accentColor,
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
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                ),
                onSubmitted: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    final clamped = parsed.clamp(minVal, maxVal);
                    if (isTemp) {
                      onChanged(target.copyWith(temperature: clamped));
                    } else {
                      onChanged(
                        target.copyWith(brightness: clamped.toDouble()),
                      );
                    }
                  }
                  Navigator.of(dialogCtx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                if (parsed != null) {
                  final clamped = parsed.clamp(minVal, maxVal);
                  if (isTemp) {
                    onChanged(target.copyWith(temperature: clamped));
                  } else {
                    onChanged(target.copyWith(brightness: clamped.toDouble()));
                  }
                }
                Navigator.of(dialogCtx).pop();
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valueDisplay = isTemp
        ? '${target.temperature}K'
        : '${target.brightness.round()}%';
    final minVal = isTemp ? TemperatureConstants.minDouble : 0.0;
    final maxVal = isTemp ? TemperatureConstants.maxDouble : 100.0;
    final sliderVal = isTemp
        ? target.temperature.toDouble().clamp(minVal, maxVal)
        : target.brightness.clamp(0.0, 100.0);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 12,
      opacity: 0.04,
      glowColor: accentColor.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: accentColor),
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
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tooltip != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: tooltip!,
                            child: Icon(
                              LucideIcons.info,
                              size: 11,
                              color: accentColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (timeStr != null)
                      Text(
                        timeStr!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
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
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          valueDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          LucideIcons.edit2,
                          size: 9,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Interactive Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: accentColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: sliderVal,
              min: minVal,
              max: maxVal,
              onChanged: (val) {
                if (isTemp) {
                  onChanged(target.copyWith(temperature: val.round()));
                } else {
                  onChanged(target.copyWith(brightness: val));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
