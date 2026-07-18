import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/env/env.dart';
import 'package:solaris/widgets/sleep_regime_card.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/local_ipc_server_state.dart';
import 'package:intl/intl.dart';

import 'package:solaris/widgets/deep_link_target.dart';

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<DeepLinkTargetState>> _anchorKeys = {
    'google_fit': GlobalKey<DeepLinkTargetState>(),
    'circadian_regulation': GlobalKey<DeepLinkTargetState>(),
    'wind_down': GlobalKey<DeepLinkTargetState>(),
    'time_shift': GlobalKey<DeepLinkTargetState>(),
    'sleep_pressure': GlobalKey<DeepLinkTargetState>(),
    'sleep_debt': GlobalKey<DeepLinkTargetState>(),
    'sleep_regimes': GlobalKey<DeepLinkTargetState>(),
    'sleep_analysis': GlobalKey<DeepLinkTargetState>(),
    'local_sleep_integration': GlobalKey<DeepLinkTargetState>(),
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
    final sleepState = ref.watch(sleepProvider);
    final regimes = ref.watch(sleepRegimesProvider);
    final googleFitState = ref.watch(googleFitProvider);

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
            icon: LucideIcons.moon,
            title: l10n.sleep,
            subtitle: l10n.sleepSubtitle,
          ),
          const SizedBox(height: 24),

          // Google Fit Sync Card
          DeepLinkTarget(
            key: _anchorKeys['google_fit'],
            id: 'google_fit',
            child: _GoogleFitSyncCard(
              googleFitState: googleFitState,
              sleepState: sleepState,
            ),
          ),
          const SizedBox(height: 24),

          // Sleep Integration API Settings
          DeepLinkTarget(
            key: _anchorKeys['local_sleep_integration'],
            id: 'local_sleep_integration',
            child: const _LocalIpcServerCard(),
          ),
          const SizedBox(height: 24),

          // Circadian Regulation Section
          _CircadianRegulationSection(anchorKeys: _anchorKeys),
          const SizedBox(height: 32),

          // Sleep Regimes / History
          DeepLinkTarget(
            key: _anchorKeys['sleep_regimes'],
            id: 'sleep_regimes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (regimes.isEmpty)
                  Center(
                    child: Text(
                      sleepState.isLoading ? l10n.syncing : l10n.sleepDataSubtitle,
                      style: const TextStyle(color: Colors.white24),
                    ),
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final currentRegime = regimes.firstWhere(
                        (r) => r.isCurrent,
                        orElse: () => regimes.first,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.currentRegime,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SleepRegimeCard(
                            regime: currentRegime,
                            initiallyExpanded: false,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          DeepLinkTarget(
            key: _anchorKeys['sleep_analysis'],
            id: 'sleep_analysis',
            child: const _SleepAnalysisSettingsSection(),
          ),
          const SizedBox(height: 48),
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
        Expanded(
          child: Column(
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
        ),
      ],
    );
  }
}

class _GoogleFitSyncCard extends ConsumerWidget {
  const _GoogleFitSyncCard({
    required this.googleFitState,
    required this.sleepState,
  });

  final GoogleFitState googleFitState;
  final SleepState sleepState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isSyncing = sleepState.isSyncing ||
        googleFitState.status == GoogleFitStatus.connecting;
    
    final settingsAsync = ref.watch(settingsProvider);
    final isGoogleKeysValid = settingsAsync.maybeWhen(
      data: (map) => map['all']?.isGoogleFitKeysAvailable ?? Env.isGoogleFitKeysValid,
      orElse: () => Env.isGoogleFitKeysValid,
    );

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.refreshCw,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.googleFitSync,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (googleFitState.status == GoogleFitStatus.connected &&
                  !isSyncing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.connectedStatusSmall,
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              if (isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (googleFitState.status == GoogleFitStatus.disconnected ||
              googleFitState.status == GoogleFitStatus.initial)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: isSyncing
                      ? null
                      : () {
                          if (!isGoogleKeysValid) {
                            _showGoogleFitKeysMissingDialog(context, ref);
                          } else {
                            ref.read(googleFitProvider.notifier).signIn();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(l10n.connectGoogleFit),
                ),
                if (!isGoogleKeysValid) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Color(0xFFF87171), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.googleFitKeysMissingWarning,
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          else if (googleFitState.status == GoogleFitStatus.connecting)
            Text(
              l10n.verifyingConnection,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            )
          else if (googleFitState.status == GoogleFitStatus.error)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  googleFitState.errorMessage ?? l10n.connectionError,
                  style:
                      const TextStyle(color: Color(0xFFF87171), fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (!isGoogleKeysValid) {
                      _showGoogleFitKeysMissingDialog(context, ref);
                    } else {
                      ref.read(googleFitProvider.notifier).signIn();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                  ),
                  child: Text(l10n.connectGoogleFit),
                ),
                if (!isGoogleKeysValid) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Color(0xFFF87171), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.googleFitKeysMissingWarning,
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lastFetchLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      googleFitState.lastFetchTime != null
                          ? DateFormat(
                              'HH:mm, d MMM',
                            ).format(googleFitState.lastFetchTime!)
                          : l10n.never,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () =>
                              ref.read(googleFitProvider.notifier).signOut(),
                      icon: const Icon(LucideIcons.logOut, size: 14),
                      label: Text(
                        l10n.signOut,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: isSyncing
                      ? null
                      : () => ref
                          .read(sleepProvider.notifier)
                          .syncWithGoogleFit(forceSync: true),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(LucideIcons.refreshCw),
                  label: Text(
                    sleepState.isSyncing ? l10n.syncing : l10n.syncNow,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                  ),
                ),
              ],
            ),
          if (sleepState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              sleepState.error!,
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _showGoogleFitKeysMissingDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFFDBA74)),
              const SizedBox(width: 12),
              Text(
                l10n.googleFitReleaseWarningTitle,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            l10n.googleFitReleaseWarningBody,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(activeScreenProvider.notifier).setScreen(AppScreen.settings);
                ref.read(searchAnchorProvider.notifier).setAnchor('api_keys');
              },
              child: Text(l10n.goToSettings),
            ),
          ],
        );
      },
    );
  }
}

class _CircadianRegulationSection extends ConsumerWidget {
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _CircadianRegulationSection({required this.anchorKeys});

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
      if (h > 0)
        return "${h}${l10n.hoursAbbreviation} ${m}${l10n.minutesAbbreviation}";
      return "${m}${l10n.minutesAbbreviation}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeepLinkTarget(
          key: anchorKeys['circadian_regulation'],
          id: 'circadian_regulation',
          child: Column(
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
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSmartCircadian(val),
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.circadianRegulationBetaNote,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (settings.isSmartCircadianEnabled ||
                    tempSettings.isSmartCircadianEnabled)
                ? 1.0
                : 0.4,
            child: AbsorbPointer(
              absorbing: !settings.isSmartCircadianEnabled &&
                  !tempSettings.isSmartCircadianEnabled,
              child: Column(
                children: [
                  DeepLinkTarget(
                    key: anchorKeys['wind_down'],
                    id: 'wind_down',
                    child: _RegulationToggle(
                      title: l10n.featureWindDown,
                      subtitle: l10n.featureWindDownSubtitle,
                      info: l10n.featureWindDownInfo,
                      masterValue: settings.isWindDownMasterEnabled,
                      brightnessValue: settings.isWindDownEnabled,
                      temperatureValue: tempSettings.isWindDownEnabled,
                      onMasterChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWindDownMaster(val),
                      onBrightnessChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWindDown(val),
                      onTemperatureChanged: (val) => ref
                          .read(temperatureSettingsProvider.notifier)
                          .updateWindDown(val),
                      brightnessLabel: l10n.influenceBrightness,
                      temperatureLabel: l10n.influenceTemperature,
                      isActive: smartData.isWindDownActive,
                      timingText: smartData.isWindDownActive
                          ? (smartData.minutesUntilSleep != null &&
                                  smartData.minutesUntilSleep! > 0)
                              ? l10n.remainingUntilSleep(
                                  formatMins(smartData.minutesUntilSleep!),
                                )
                              : (smartData.minutesUntilWakeUp != null)
                                  ? l10n.remainingUntilWakeUp
                                  : l10n.active
                          : null,
                      brightnessIntensity: settings.windDownBrightnessIntensity,
                      temperatureIntensity:
                          settings.windDownTemperatureIntensity,
                      onBrightnessIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWindDownIntensity(
                            val,
                            settings.windDownTemperatureIntensity,
                          ),
                      onTemperatureIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWindDownIntensity(
                            settings.windDownBrightnessIntensity,
                            val,
                          ),
                      durationValue:
                          settings.windDownDurationMinutes.toDouble(),
                      durationMin: 30,
                      durationMax: 360,
                      durationLabel: l10n.windDownDuration,
                      onDurationChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateWindDownDuration(val.toInt()),
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  DeepLinkTarget(
                    key: anchorKeys['time_shift'],
                    id: 'time_shift',
                    child: _RegulationToggle(
                      title: l10n.featureTimeShift,
                      subtitle: l10n.featureTimeShiftSubtitle,
                      info: l10n.featureTimeShiftInfo,
                      masterValue: settings.isTimeShiftMasterEnabled,
                      brightnessValue: settings.isTimeShiftEnabled,
                      temperatureValue: tempSettings.isTimeShiftEnabled,
                      onMasterChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateTimeShiftMaster(val),
                      onBrightnessChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateTimeShift(val),
                      onTemperatureChanged: (val) => ref
                          .read(temperatureSettingsProvider.notifier)
                          .updateTimeShift(val),
                      brightnessLabel: l10n.influenceBrightness,
                      temperatureLabel: l10n.influenceTemperature,
                      isActive: smartData.isTimeShiftActive,
                      brightnessIntensity: settings.timeShiftIntensity,
                      onBrightnessIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateTimeShiftIntensity(val),
                      showTemperatureIntensity:
                          false, // Time shift is a single factor
                      durationValue:
                          settings.timeShiftDurationMinutes.toDouble(),
                      durationMin: 60,
                      durationMax: 720,
                      durationLabel: l10n.timeShiftDuration,
                      onDurationChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateTimeShiftDuration(val.toInt()),
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  DeepLinkTarget(
                    key: anchorKeys['sleep_pressure'],
                    id: 'sleep_pressure',
                    child: _RegulationToggle(
                      title: l10n.featureSleepPressure,
                      subtitle: l10n.featureSleepPressureSubtitle,
                      info: l10n.featureSleepPressureInfo,
                      masterValue: settings.isSleepPressureMasterEnabled,
                      brightnessValue: settings.isSleepPressureEnabled,
                      temperatureValue: tempSettings.isSleepPressureEnabled,
                      onMasterChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepPressureMaster(val),
                      onBrightnessChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepPressure(val),
                      onTemperatureChanged: (val) => ref
                          .read(temperatureSettingsProvider.notifier)
                          .updateSleepPressure(val),
                      brightnessLabel: l10n.influenceBrightness,
                      temperatureLabel: l10n.influenceTemperature,
                      isActive: smartData.isSleepPressureActive,
                      brightnessIntensity:
                          settings.sleepPressureBrightnessIntensity,
                      onBrightnessIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepPressureIntensity(
                            val,
                            settings.sleepPressureTemperatureIntensity,
                          ),
                      temperatureIntensity:
                          settings.sleepPressureTemperatureIntensity,
                      onTemperatureIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepPressureIntensity(
                            settings.sleepPressureBrightnessIntensity,
                            val,
                          ),
                      durationValue: settings.sleepPressureWakeLimitHours,
                      durationMin: 10,
                      durationMax: 20,
                      durationLabel: l10n.sleepPressureLimit,
                      durationUnit: l10n.hoursAbbreviation,
                      onDurationChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepPressureLimit(val),
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  DeepLinkTarget(
                    key: anchorKeys['sleep_debt'],
                    id: 'sleep_debt',
                    child: _RegulationToggle(
                      title: l10n.featureSleepDebt,
                      subtitle: l10n.featureSleepDebtSubtitle,
                      info: l10n.featureSleepDebtInfo,
                      masterValue: settings.isSleepDebtMasterEnabled,
                      brightnessValue: settings.isSleepDebtEnabled,
                      temperatureValue: tempSettings.isSleepDebtEnabled,
                      onMasterChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepDebtMaster(val),
                      onBrightnessChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepDebt(val),
                      onTemperatureChanged: (val) => ref
                          .read(temperatureSettingsProvider.notifier)
                          .updateSleepDebt(val),
                      brightnessLabel: l10n.influenceBrightness,
                      temperatureLabel: l10n.influenceTemperature,
                      isActive: smartData.isSleepDebtActive,
                      brightnessIntensity:
                          settings.sleepDebtBrightnessIntensity,
                      temperatureIntensity:
                          settings.sleepDebtTemperatureIntensity,
                      onBrightnessIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepDebtIntensity(
                            val,
                            settings.sleepDebtTemperatureIntensity,
                          ),
                      onTemperatureIntensityChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepDebtIntensity(
                            settings.sleepDebtBrightnessIntensity,
                            val,
                          ),
                      durationValue:
                          settings.sleepDebtThresholdMinutes.toDouble(),
                      durationMin: 240,
                      durationMax: 540,
                      durationLabel: l10n.sleepDebtThreshold,
                      onDurationChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSleepDebtThreshold(val.toInt()),
                    ),
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
    this.durationValue,
    this.onDurationChanged,
    this.durationMin = 0,
    this.durationMax = 100,
    this.durationLabel,
    this.durationUnit,
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
  final double? durationValue;
  final ValueChanged<double>? onDurationChanged;
  final double durationMin;
  final double durationMax;
  final String? durationLabel;
  final String? durationUnit;

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
        color: widget.isActive
            ? Colors.white.withOpacity(0.03)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ]
            : [],
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFF8B5CF6).withOpacity(0.3)
              : Colors.transparent,
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
                            color: widget.isActive
                                ? const Color(0xFFC4B5FD)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.isActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                            color: _isExpanded
                                ? const Color(0xFF8B5CF6)
                                : Colors.white.withOpacity(0.3),
                          ),
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
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
                          textStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
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
                    if (widget.temperatureValue &&
                        widget.showTemperatureIntensity)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _IntensitySlider(
                          label: l10n.temperatureIntensity,
                          value: widget.temperatureIntensity,
                          onChanged: widget.onTemperatureIntensityChanged,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    if (widget.durationValue != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _DurationSlider(
                          label: widget.durationLabel ?? "",
                          value: widget.durationValue!,
                          min: widget.durationMin,
                          max: widget.durationMax,
                          unit: widget.durationUnit,
                          onChanged: widget.onDurationChanged,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            Text(
              l10n.chartPercentFormat((value * 100).toInt()),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
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
          child: Slider(value: value, min: 0.0, max: 1.0, onChanged: onChanged),
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

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String? unit;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Format label for mins if no unit provided
    String formatValue(double val) {
      if (unit != null) return "${val.toStringAsFixed(1)}$unit";

      final mins = val.toInt();
      final h = mins ~/ 60;
      final m = mins % 60;
      if (h > 0)
        return "${h}${l10n.hoursAbbreviation} ${m}${l10n.minutesAbbreviation}";
      return "${m}${l10n.minutesAbbreviation}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            Text(
              formatValue(value),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC4B5FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: const Color(0xFF8B5CF6).withOpacity(0.5),
            inactiveTrackColor: Colors.white10,
            thumbColor: const Color(0xFFC4B5FD),
            overlayColor: const Color(0xFF8B5CF6).withOpacity(0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _SleepAnalysisSettingsSection extends ConsumerStatefulWidget {
  const _SleepAnalysisSettingsSection();

  @override
  ConsumerState<_SleepAnalysisSettingsSection> createState() =>
      _SleepAnalysisSettingsSectionState();
}

class _SleepAnalysisSettingsSectionState
    extends ConsumerState<_SleepAnalysisSettingsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final selectedMonitors = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedMonitors.firstOrNull ?? 'all';

    final settings = settingsAsync.maybeWhen(
      data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
      orElse: () => SettingsState(),
    );

    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  l10n.sleepAnalysisSettings,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: Colors.white60,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _AnalysisSlider(
                      title: l10n.toleranceWindow,
                      subtitle: l10n.toleranceWindowDesc,
                      value: settings.sleepToleranceWindow.toDouble(),
                      min: 30,
                      max: 180,
                      unit: l10n.minutesAbbreviation,
                      onChanged: (val) =>
                          notifier.updateSleepToleranceWindow(val.toInt()),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _AnalysisSlider(
                      title: l10n.maxAnomalies,
                      subtitle: l10n.maxAnomaliesDesc,
                      value: settings.sleepMaxAnomalies.toDouble(),
                      min: 1,
                      max: 7,
                      unit: l10n.daysCount(1)
                          .replaceAll(RegExp(r'[0-9]'), '')
                          .trim(),
                      onChanged: (val) =>
                          notifier.updateSleepMaxAnomalies(val.toInt()),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _AnalysisSlider(
                      title: l10n.minRegimeLength,
                      subtitle: l10n.minRegimeLengthDesc,
                      value: settings.sleepMinRegimeLength.toDouble(),
                      min: 1,
                      max: 7,
                      unit: l10n.daysCount(1)
                          .replaceAll(RegExp(r'[0-9]'), '')
                          .trim(),
                      onChanged: (val) =>
                          notifier.updateSleepMinRegimeLength(val.toInt()),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _AnalysisSlider(
                      title: l10n.anchorSize,
                      subtitle: l10n.anchorSizeDesc,
                      value: settings.sleepAnchorSize.toDouble(),
                      min: 1,
                      max: 7,
                      unit: l10n.daysCount(1)
                          .replaceAll(RegExp(r'[0-9]'), '')
                          .trim(),
                      onChanged: (val) =>
                          notifier.updateSleepAnchorSize(val.toInt()),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _AnalysisSlider(
                      title: l10n.maxSpread,
                      subtitle: l10n.maxSpreadDesc,
                      value: settings.sleepMaxSpread.toDouble(),
                      min: 30,
                      max: 240,
                      unit: l10n.minutesAbbreviation,
                      onChanged: (val) =>
                          notifier.updateSleepMaxSpread(val.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _AnalysisSlider extends StatelessWidget {
  const _AnalysisSlider({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${value.toInt()} $unit',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC4B5FD),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: const Color(0xFF818CF8),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF8B5CF6).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt() > 0 ? (max - min).toInt() : null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _LocalIpcServerCard extends ConsumerStatefulWidget {
  const _LocalIpcServerCard();

  @override
  ConsumerState<_LocalIpcServerCard> createState() => _LocalIpcServerCardState();
}

class _LocalIpcServerCardState extends ConsumerState<_LocalIpcServerCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final ipcState = ref.read(localIpcServiceProvider);
    if (ipcState.error != null) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);

    ref.listen<LocalIpcServerState>(localIpcServiceProvider, (previous, next) {
      if (next.error != null && previous?.error == null) {
        setState(() => _isExpanded = true);
      }
    });

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.server,
                      color: Color(0xFFA78BFA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.sleepIntegrationTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {}, // Prevent InkWell tap propagation
                              child: IconButton(
                                icon: Icon(
                                  LucideIcons.info,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                onPressed: () => _showHelpDialog(context, l10n),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                splashRadius: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          l10n.sleepIntegrationSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: Colors.white60,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _SettingsRow(
                  title: l10n.enableLocalIpcServer,
                  subtitle: l10n.enableLocalIpcServerSubtitle,
                  value: settingsAsync.maybeWhen(
                    data: (map) => map['all']?.isLocalIpcServerEnabled ?? false,
                    orElse: () => false,
                  ),
                  onChanged: (val) =>
                      ref.read(settingsProvider.notifier).updateLocalIpcServerEnabled(val),
                ),
                if (settingsAsync.maybeWhen(
                  data: (map) => map['all']?.isLocalIpcServerEnabled ?? false,
                  orElse: () => false,
                )) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.serverPort,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.serverPortSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          controller: TextEditingController(
                            text: settingsAsync.maybeWhen(
                              data: (map) => (map['all']?.localIpcServerPort ?? 45321).toString(),
                              orElse: () => '45321',
                            ),
                          )..selection = TextSelection.collapsed(
                              offset: settingsAsync.maybeWhen(
                                data: (map) => (map['all']?.localIpcServerPort ?? 45321).toString().length,
                                orElse: () => 5,
                              ),
                            ),
                          onSubmitted: (val) {
                            final port = int.tryParse(val);
                            if (port != null && port > 0 && port < 65535) {
                              ref.read(settingsProvider.notifier).updateLocalIpcServerPort(port);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final ipcService = ref.watch(localIpcServiceProvider);
                      final isRunning = ipcService.isRunning;
                      final activePort = ipcService.port;
                      final hasError = ipcService.error != null;
                      final failedPort = ipcService.failedPort ?? 45321;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRunning ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                                color: isRunning ? Colors.greenAccent : Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isRunning
                                    ? l10n.serverRunningStatus(activePort ?? 45321)
                                    : l10n.serverStoppedStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isRunning ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (!isRunning && hasError) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.alertTriangle,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.serverPortBusyAlertTitle(failedPort),
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.serverPortBusyAlertExplanation(failedPort),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.serverPortBusyAlertSolution(failedPort),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
            crossFadeState:
                _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.sleepIntegrationHelpTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white60, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sleepIntegrationHelpIntro,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionWhat,
                            text: l10n.sleepIntegrationHelpSectionWhatText,
                          ),
                          const SizedBox(height: 16),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionHow,
                            text: l10n.sleepIntegrationHelpSectionHowText,
                          ),
                          const SizedBox(height: 16),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionConfig,
                            text: l10n.sleepIntegrationHelpSectionConfigText,
                          ),
                          const SizedBox(height: 16),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionDeduplication,
                            text: l10n.sleepIntegrationHelpSectionDeduplicationText,
                          ),
                          const SizedBox(height: 16),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionSecurity,
                            text: l10n.sleepIntegrationHelpSectionSecurityText,
                          ),
                          const SizedBox(height: 16),
                          _buildHelpSection(
                            title: l10n.sleepIntegrationHelpSectionFormat,
                            text: l10n.sleepIntegrationHelpSectionFormatText,
                            isCode: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFA78BFA),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpSection({required String title, required String text, bool isCode = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA78BFA),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            height: 1.4,
            fontFamily: isCode ? 'monospace' : null,
          ),
        ),
      ],
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
                  color: Colors.white.withOpacity(0.4),
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
