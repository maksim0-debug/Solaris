import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/sleep_regime_card.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:intl/intl.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sleepState = ref.watch(sleepProvider);
    final googleFitState = ref.watch(googleFitProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: LucideIcons.moon,
            title: l10n.sleep, 
            subtitle: l10n.sleepSubtitle,
          ),
          const SizedBox(height: 24),

          // Google Fit Sync Card
          _GoogleFitSyncCard(googleFitState: googleFitState, isLoading: sleepState.isLoading, error: sleepState.error),
          const SizedBox(height: 24),

          // Circadian Regulation Section
          if (googleFitState.status == GoogleFitStatus.connected) ...[
            const _CircadianRegulationSection(),
            const SizedBox(height: 32),
          ],

          // Sleep Regimes / History
          if (sleepState.regimes.isEmpty && !sleepState.isLoading)
             Center(child: Text(l10n.sleepDataSubtitle, style: const TextStyle(color: Colors.white24)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.detectedRegimes,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                ...sleepState.regimes.asMap().entries.map((entry) {
                  final regime = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SleepRegimeCard(
                      regime: regime,
                      initiallyExpanded: false, // All collapsed by default as requested
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoogleFitSyncCard extends ConsumerWidget {
  const _GoogleFitSyncCard({required this.googleFitState, required this.isLoading, this.error});
  final GoogleFitState googleFitState;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.refreshCw, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Text(
                l10n.googleFitSync,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              if (googleFitState.status == GoogleFitStatus.connected && !isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(l10n.connectedStatusSmall, style: const TextStyle(color: Colors.green, fontSize: 12)),
                ),
              if (isLoading)
                 const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          if (googleFitState.status != GoogleFitStatus.connected)
            ElevatedButton(
              onPressed: () => ref.read(googleFitProvider.notifier).signIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(l10n.connectGoogleFit),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.lastFetchLabel, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    Text(
                      googleFitState.lastFetchTime != null 
                        ? DateFormat('HH:mm, d MMM').format(googleFitState.lastFetchTime!)
                        : l10n.never,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () => ref.read(sleepProvider.notifier).syncWithGoogleFit(),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(l10n.syncNow),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircadianRegulationSection extends ConsumerWidget {
  const _CircadianRegulationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedIds.firstOrNull ?? 'all';

    final settings = settingsAsync.maybeWhen(
      data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
      orElse: () => SettingsState(),
    );

    final tempSettings = tempSettingsAsync.maybeWhen(
      data: (map) => map[monitorId] ?? map['all'] ?? TemperatureState(),
      orElse: () => TemperatureState(),
    );

    final l10n = AppLocalizations.of(context)!;
    final smartData = ref.watch(smartCircadianDataProvider(monitorId));

    String formatMins(int mins) {
      if (mins < 0) return "";
      final h = mins ~/ 60;
      final m = mins % 60;
      if (h > 0) return "${h}${l10n.hoursAbbreviation} ${m}${l10n.minutesAbbreviation}";
      return "${m}${l10n.minutesAbbreviation}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.circadianRegulation,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Switch(
              value: settings.isSmartCircadianEnabled,
              onChanged: (val) => ref.read(settingsProvider.notifier).updateSmartCircadian(val),
              activeColor: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (settings.isSmartCircadianEnabled || tempSettings.isSmartCircadianEnabled) ? 1.0 : 0.4,
            child: AbsorbPointer(
              absorbing: !settings.isSmartCircadianEnabled && !tempSettings.isSmartCircadianEnabled,
              child: Column(
                children: [
                  _RegulationToggle(
                    title: l10n.featureWindDown,
                    subtitle: l10n.featureWindDownSubtitle,
                    info: l10n.featureWindDownInfo,
                    masterValue: settings.isWindDownMasterEnabled,
                    brightnessValue: settings.isWindDownEnabled,
                    temperatureValue: tempSettings.isWindDownEnabled,
                    onMasterChanged: (val) => ref.read(settingsProvider.notifier).updateWindDownMaster(val),
                    onBrightnessChanged: (val) => ref.read(settingsProvider.notifier).updateWindDown(val),
                    onTemperatureChanged: (val) => ref.read(temperatureSettingsProvider.notifier).updateWindDown(val),
                    brightnessLabel: l10n.influenceBrightness,
                    temperatureLabel: l10n.influenceTemperature,
                    isActive: smartData.isWindDownActive,
                    timingText: (smartData.isWindDownActive && smartData.minutesUntilSleep != null) 
                        ? l10n.remainingLower(formatMins(smartData.minutesUntilSleep!))
                        : null,
                    brightnessIntensity: settings.windDownBrightnessIntensity,
                    temperatureIntensity: settings.windDownTemperatureIntensity,
                    onBrightnessIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateWindDownIntensity(val, settings.windDownTemperatureIntensity),
                    onTemperatureIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateWindDownIntensity(settings.windDownBrightnessIntensity, val),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  _RegulationToggle(
                    title: l10n.featureTimeShift,
                    subtitle: l10n.featureTimeShiftSubtitle,
                    info: l10n.featureTimeShiftInfo,
                    masterValue: settings.isTimeShiftMasterEnabled,
                    brightnessValue: settings.isTimeShiftEnabled,
                    temperatureValue: tempSettings.isTimeShiftEnabled,
                    onMasterChanged: (val) => ref.read(settingsProvider.notifier).updateTimeShiftMaster(val),
                    onBrightnessChanged: (val) => ref.read(settingsProvider.notifier).updateTimeShift(val),
                    onTemperatureChanged: (val) => ref.read(temperatureSettingsProvider.notifier).updateTimeShift(val),
                    brightnessLabel: l10n.influenceBrightness,
                    temperatureLabel: l10n.influenceTemperature,
                    isActive: smartData.isTimeShiftActive,
                    brightnessIntensity: settings.timeShiftIntensity,
                    onBrightnessIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateTimeShiftIntensity(val),
                    showTemperatureIntensity: false, // Time shift is a single factor
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  _RegulationToggle(
                    title: l10n.featureSleepPressure,
                    subtitle: l10n.featureSleepPressureSubtitle,
                    info: l10n.featureSleepPressureInfo,
                    masterValue: settings.isSleepPressureMasterEnabled,
                    brightnessValue: settings.isSleepPressureEnabled,
                    temperatureValue: tempSettings.isSleepPressureEnabled,
                    onMasterChanged: (val) => ref.read(settingsProvider.notifier).updateSleepPressureMaster(val),
                    onBrightnessChanged: (val) => ref.read(settingsProvider.notifier).updateSleepPressure(val),
                    onTemperatureChanged: (val) => ref.read(temperatureSettingsProvider.notifier).updateSleepPressure(val),
                    brightnessLabel: l10n.influenceBrightness,
                    temperatureLabel: l10n.influenceTemperature,
                    isActive: smartData.isSleepPressureActive,
                    brightnessIntensity: settings.sleepPressureBrightnessIntensity,
                    onBrightnessIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateSleepPressureIntensity(val),
                    showTemperatureIntensity: false, // Currently only brightness
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  _RegulationToggle(
                    title: l10n.featureSleepDebt,
                    subtitle: l10n.featureSleepDebtSubtitle,
                    info: l10n.featureSleepDebtInfo,
                    masterValue: settings.isSleepDebtMasterEnabled,
                    brightnessValue: settings.isSleepDebtEnabled,
                    temperatureValue: tempSettings.isSleepDebtEnabled,
                    onMasterChanged: (val) => ref.read(settingsProvider.notifier).updateSleepDebtMaster(val),
                    onBrightnessChanged: (val) => ref.read(settingsProvider.notifier).updateSleepDebt(val),
                    onTemperatureChanged: (val) => ref.read(temperatureSettingsProvider.notifier).updateSleepDebt(val),
                    brightnessLabel: l10n.influenceBrightness,
                    temperatureLabel: l10n.influenceTemperature,
                    isActive: smartData.isSleepDebtActive,
                    brightnessIntensity: settings.sleepDebtBrightnessIntensity,
                    temperatureIntensity: settings.sleepDebtTemperatureIntensity,
                    onBrightnessIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateSleepDebtIntensity(val, settings.sleepDebtTemperatureIntensity),
                    onTemperatureIntensityChanged: (val) => ref.read(settingsProvider.notifier).updateSleepDebtIntensity(settings.sleepDebtBrightnessIntensity, val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegulationToggle extends ConsumerStatefulWidget {
  const _RegulationToggle({
    required this.title,
    required this.subtitle,
    required this.info,
    required this.masterValue,
    required this.brightnessValue,
    required this.temperatureValue,
    required this.onMasterChanged,
    required this.onBrightnessChanged,
    required this.onTemperatureChanged,
    required this.brightnessLabel,
    required this.temperatureLabel,
    this.isActive = false,
    this.timingText,
    this.brightnessIntensity = 1.0,
    this.temperatureIntensity = 1.0,
    this.onBrightnessIntensityChanged,
    this.onTemperatureIntensityChanged,
    this.showTemperatureIntensity = true,
  });

  final String title;
  final String subtitle;
  final String info;
  final bool masterValue;
  final bool brightnessValue;
  final bool temperatureValue;
  final ValueChanged<bool> onMasterChanged;
  final ValueChanged<bool> onBrightnessChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final String brightnessLabel;
  final String temperatureLabel;
  final bool isActive;
  final String? timingText;
  final double brightnessIntensity;
  final double temperatureIntensity;
  final ValueChanged<double>? onBrightnessIntensityChanged;
  final ValueChanged<double>? onTemperatureIntensityChanged;
  final bool showTemperatureIntensity;

  @override
  ConsumerState<_RegulationToggle> createState() => _RegulationToggleState();
}

class _RegulationToggleState extends ConsumerState<_RegulationToggle> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isActive ? Colors.white.withOpacity(0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.isActive ? [
           BoxShadow(
             color: const Color(0xFF8B5CF6).withOpacity(0.15),
             blurRadius: 20,
             spreadRadius: -5,
           )
        ] : [],
        border: Border.all(
          color: widget.isActive ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isActive ? const Color(0xFFC4B5FD) : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.isActive) ...[
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                             decoration: BoxDecoration(
                               color: const Color(0xFF8B5CF6).withOpacity(0.2),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               widget.timingText ?? l10n.active,
                               style: const TextStyle(
                                 color: Color(0xFFC4B5FD),
                                 fontSize: 10,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ),
                           const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: Icon(
                            LucideIcons.settings,
                            size: 14,
                            color: _isExpanded ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.3),
                          ),
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          tooltip: l10n.settings,
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                         message: widget.info,
                         padding: const EdgeInsets.all(12),
                         margin: const EdgeInsets.symmetric(horizontal: 24),
                         decoration: BoxDecoration(
                           color: const Color(0xFF1E1B4B),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.white10),
                         ),
                         textStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                         preferBelow: false,
                         child: Icon(
                           LucideIcons.info,
                           size: 14,
                           color: Colors.white.withOpacity(0.3),
                         ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: widget.masterValue,
                onChanged: widget.onMasterChanged,
                activeColor: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.masterValue ? 1.0 : 0.3,
          child: AbsorbPointer(
            absorbing: !widget.masterValue,
            child: Column(
              children: [
                Row(
                  children: [
                    _SmallToggle(
                      label: widget.brightnessLabel,
                      value: widget.brightnessValue,
                      onChanged: widget.onBrightnessChanged,
                      color: const Color(0xFFFDBA74),
                    ),
                    const SizedBox(width: 24),
                    _SmallToggle(
                      label: widget.temperatureLabel,
                      value: widget.temperatureValue,
                      onChanged: widget.onTemperatureChanged,
                      color: const Color(0xFF818CF8),
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  if (widget.brightnessValue)
                    _IntensitySlider(
                      label: l10n.brightnessIntensity,
                      value: widget.brightnessIntensity,
                      onChanged: widget.onBrightnessIntensityChanged,
                      color: const Color(0xFFFDBA74),
                    ),
                  if (widget.temperatureValue && widget.showTemperatureIntensity)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _IntensitySlider(
                        label: l10n.temperatureIntensity,
                        value: widget.temperatureIntensity,
                        onChanged: widget.onTemperatureIntensityChanged,
                        color: const Color(0xFF818CF8),
                      ),
                    ),
                ],
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
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

class _SmallToggle extends StatelessWidget {
  const _SmallToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: value ? Colors.white70 : Colors.white24,
          ),
        ),
      ],
    );
  }
}
