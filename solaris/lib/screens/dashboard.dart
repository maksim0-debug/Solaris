import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/window_title_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/screens/schedule_screen.dart';
import 'package:solaris/widgets/brightness_dial.dart';
import 'package:solaris/widgets/brightness_slider.dart';
import 'package:solaris/widgets/temperature_dial.dart';
import 'package:solaris/widgets/temperature_slider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/sun_path_painter.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/screens/location_screen.dart';
import 'package:solaris/screens/settings_screen.dart';
import 'package:solaris/screens/sleep_screen.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/utils/status_helper.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Show window once the first frame is rendered to avoid white flash
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the background brightness adjustment logic alive
    ref.watch(circadianAdjustmentProvider);

    // Watch visibility state to prune the widget tree when not visible
    final visibility = ref.watch(appLifecycleProvider);

    // If the window is minimized or hidden, we return an empty widget.
    // This stops all animations (Pulsing Radar, Dial, etc.) and all GPU-intensive
    // rendering (BackdropFilter in GlassCard, Gradients).
    if (visibility != AppVisibilityState.visible) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Column(
        children: [
          const WindowTitleBar(),
          const Expanded(
            child: Row(
              children: [
                // Sidebar
                _Sidebar(),

                // Main Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(),
                        SizedBox(height: 32),
                        Expanded(child: _MainView()),
                        SizedBox(height: 32),
                        _Footer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  static const IconData insights = IconData(
    0xe347,
    fontFamily: 'MaterialIcons',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 260,
      color: const Color(0xFF0F172A).withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDBA74).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.sun,
                  color: Color(0xFFFDBA74),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 20),
                  ),
                  Text(
                    l10n.celestialControl,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Nav Items
          _SidebarItem(
            icon: LucideIcons.layoutGrid,
            label: l10n.dashboard,
            isActive: ref.watch(activeScreenProvider) == AppScreen.dashboard,
            onTap: () => ref
                .read(activeScreenProvider.notifier)
                .setScreen(AppScreen.dashboard),
          ),
          _SidebarItem(
            icon: insights,
            label: l10n.schedule,
            isActive: ref.watch(activeScreenProvider) == AppScreen.schedule,
            onTap: () => ref
                .read(activeScreenProvider.notifier)
                .setScreen(AppScreen.schedule),
          ),
          _SidebarItem(
            icon: LucideIcons.settings,
            label: l10n.settings,
            isActive: ref.watch(activeScreenProvider) == AppScreen.settings,
            onTap: () => ref
                .read(activeScreenProvider.notifier)
                .setScreen(AppScreen.settings),
          ),
          _SidebarItem(
            icon: LucideIcons.mapPin,
            label: l10n.location,
            isActive: ref.watch(activeScreenProvider) == AppScreen.location,
            onTap: () => ref
                .read(activeScreenProvider.notifier)
                .setScreen(AppScreen.location),
          ),
          _SidebarItem(
            icon: LucideIcons.moon,
            label: l10n.sleep,
            isActive: ref.watch(activeScreenProvider) == AppScreen.sleep,
            onTap: () => ref
                .read(activeScreenProvider.notifier)
                .setScreen(AppScreen.sleep),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFDBA74).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFFFDBA74) : Colors.white24,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white24,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final timeAsync = ref.watch<AsyncValue<DateTime>>(currentTimeProvider);
    final solarAsync = ref.watch(solarStateStreamProvider);
    final timeService = ref.watch(timeServiceProvider);
    final monitorListNotifier = ref.read(monitorListProvider.notifier);
    final brightnessService = ref.read(brightnessServiceProvider);
    final temperatureService = ref.read(temperatureServiceProvider);
    final monitorService = ref.read(monitorServiceProvider);

    // Apply brightness to monitors whenever it changes significantly
    ref.listen<double>(currentBrightnessProvider, (previous, next) {
      if (ref.read(autoBrightnessAdjustmentProvider))
        return; // Already handled by background loop

      if (previous?.round() != next.round()) {
        final selection = ref.read(selectedMonitorsProvider);
        final monitors = ref.read(monitorListProvider).value ?? [];

        for (final id in selection) {
          brightnessService.applyBrightnessSmoothly(
            selection: id,
            targetValue: next,
            monitors: monitors,
            monitorService: monitorService,
            updateBrightnessCallback: (id, val) =>
                monitorListNotifier.updateBrightness(id, val),
          );
        }
      }
    });

    // Apply temperature to monitors whenever it changes significantly
    ref.listen<int>(currentTemperatureProvider, (previous, next) {
      if (ref.read(autoTemperatureAdjustmentProvider))
        return; // Already handled by background loop

      if (previous != next) {
        final selection = ref.read(selectedMonitorsProvider);
        final monitors = ref.read(monitorListProvider).value ?? [];

        for (final id in selection) {
          temperatureService.applyTemperatureSmoothly(
            selection: id,
            targetValue: next.toDouble(),
            monitors: monitors,
            monitorService: monitorService,
            updateTemperatureCallback: (id, val) =>
                monitorListNotifier.updateTemperature(id, val),
          );
        }
      }
    });

    // Initial sync when monitors are detected
    ref.listen(monitorListProvider, (previous, next) {
      if (ref.read(autoBrightnessAdjustmentProvider) &&
          ref.read(autoTemperatureAdjustmentProvider))
        return; // Already handled by background loop

      if (next.hasValue && !next.isLoading) {
        final selection = ref.read(selectedMonitorsProvider);
        final monitors = next.value ?? [];

        // Sync brightness
        final targetBright = ref.read(currentBrightnessProvider);
        debugPrint('Initial sync: applying brightness $targetBright');
        for (final id in selection) {
          brightnessService.applyBrightnessSmoothly(
            selection: id,
            targetValue: targetBright,
            monitors: monitors,
            monitorService: monitorService,
            updateBrightnessCallback: (id, val) =>
                monitorListNotifier.updateBrightness(id, val),
          );
        }

        // Sync temperature
        if (ref.read(isColorTemperatureEnabledProvider)) {
          final targetTemp = ref.read(currentTemperatureProvider);
          debugPrint('Initial sync: applying temperature $targetTemp');
          for (final id in selection) {
            temperatureService.applyTemperatureSmoothly(
              selection: id,
              targetValue: targetTemp.toDouble(),
              monitors: monitors,
              monitorService: monitorService,
              updateTemperatureCallback: (id, val) =>
                  monitorListNotifier.updateTemperature(id, val),
            );
          }
        }
      }
    });

    // Sync brightness and temperature when selection changes
    ref.listen<Set<String>>(selectedMonitorsProvider, (previous, next) {
      if (ref.read(autoBrightnessAdjustmentProvider) &&
          ref.read(autoTemperatureAdjustmentProvider))
        return; // Already handled by background loop

      final monitorValue = ref.read(monitorListProvider).value;
      if (monitorValue == null) return;

      if (next.contains('all')) {
        // Apply brightness
        final brightness = ref.read(currentBrightnessProvider);
        brightnessService.applyBrightnessSmoothly(
          selection: 'all',
          targetValue: brightness,
          monitors: monitorValue,
          monitorService: monitorService,
          updateBrightnessCallback: (id, val) =>
              monitorListNotifier.updateBrightness(id, val),
        );

        // Apply temperature
        if (ref.read(isColorTemperatureEnabledProvider)) {
          final targetTemp = ref.read(currentTemperatureProvider);
          temperatureService.applyTemperatureSmoothly(
            selection: 'all',
            targetValue: targetTemp.toDouble(),
            monitors: monitorValue,
            monitorService: monitorService,
            updateTemperatureCallback: (id, val) =>
                monitorListNotifier.updateTemperature(id, val),
          );
        }
      } else if (next.length == 1) {
        // If single monitor selected, sync UI to its current levels
        try {
          final id = next.first;
          final monitor = monitorValue.firstWhere((m) => m.deviceName == id);
          if (monitor.realBrightness != null) {
            ref
                .read(manualBrightnessProvider.notifier)
                .update(monitor.realBrightness!.toDouble());
          }
          if (monitor.realTemperature != null &&
              ref.read(isColorTemperatureEnabledProvider)) {
            ref
                .read(manualTemperatureProvider.notifier)
                .setTemperature(monitor.realTemperature!);
          }
        } catch (_) {}
      }
    });

    final timeStr = timeAsync.maybeWhen(
      data: (time) => timeService.formatTime(time),
      orElse: () => '--:-- --',
    );

    String goldenHourStatus = l10n.goldenHour;
    String goldenHourTime = l10n.calculating;

    solarAsync.whenData((state) {
      final now = DateTime.now();
      final timeStr = timeService.formatCountdown(state.timeUntilNextEvent);

      if (state.currentPhase == CurrentDayPhase.goldenHour) {
        goldenHourStatus = l10n.goldenHourActive;
        goldenHourTime = l10n.remaining(timeStr);
      } else if (now.isBefore(state.phases.sunrise)) {
        goldenHourStatus = l10n.goldenHour;
        goldenHourTime = l10n.comingIn(timeStr);
      } else if (now.isAfter(state.phases.sunset)) {
        goldenHourStatus = l10n.night;
        goldenHourTime = l10n.finished;
      } else {
        // broad daylight
        goldenHourStatus = l10n.goldenHour;
        goldenHourTime = l10n.comingIn(timeStr);
      }
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeStr,
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 18),
            ),
            Text(
              l10n.localTime,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 10),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              goldenHourStatus,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 18,
                color: const Color(0xFFFDBA74),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              goldenHourTime,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MainView extends ConsumerWidget {
  const _MainView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = ref.watch(activeScreenProvider);

    switch (screen) {
      case AppScreen.dashboard:
        return const _DashboardView();
      case AppScreen.schedule:
        return const ScheduleScreen();
      case AppScreen.sleep:
        return const SleepScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.location:
        return const LocationScreen();
    }
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final solarAsync = ref.watch(solarStateStreamProvider);
    final timeService = ref.watch(timeServiceProvider);
    final brightness = ref.watch(currentBrightnessProvider);
    final currentTemperature = ref.watch(currentTemperatureProvider);
    final bool isAutoBright = ref.watch<bool>(autoBrightnessAdjustmentProvider);
    final bool isAutoTemp = ref.watch<bool>(autoTemperatureAdjustmentProvider);
    final bool isColorTempEnabled = ref.watch(
      isColorTemperatureEnabledProvider,
    );

    return Row(
      children: [
        // Sun Path & Brightness center
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sun path Arcs
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: CustomPaint(
                            painter: SunPathPainter(
                              progress: solarAsync.maybeWhen(
                                data: (s) => s.sunProgress,
                                orElse: () {
                                  // Safe approximate progress for startup to avoid "sun flash"
                                  final hour = DateTime.now().hour;
                                  if (hour >= 21 || hour < 5)
                                    return -0.5; // Night
                                  if (hour >= 5 && hour < 7)
                                    return 0.0; // Sunrise
                                  if (hour >= 19 && hour < 21)
                                    return 1.0; // Sunset
                                  return 0.5; // Midday
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Temperature Indicator (Outer)
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CustomPaint(
                        painter: TemperatureDialPainter(
                          progress:
                              (6500.0 - currentTemperature.clamp(2000, 6500)) /
                              (6500.0 - 2000.0),
                        ),
                      ),
                    ),
                    // Brightness Indicator (Inner)
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CustomPaint(
                        painter: BrightnessDialPainter(
                          brightness: brightness / 100.0,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${brightness.round()}%',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -4,
                                color: Colors.white,
                              ),
                        ),
                        Text(
                          l10n.brightness.toUpperCase(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 10,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    BrightnessSlider(
                      value: brightness,
                      onChanged: (val) => ref
                          .read(currentBrightnessProvider.notifier)
                          .setManualBrightness(val),
                    ),
                    const SizedBox(height: 24),
                    TemperatureSlider(
                      value: currentTemperature.toDouble(),
                      onChanged: (val) => ref
                          .read(currentTemperatureProvider.notifier)
                          .setManualTemperature(val.round()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stats and Toggles
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              solarAsync.when(
                data: (state) {
                  final status = StatusHelper.getStatus(
                    state,
                    l10n,
                    isAutoBright,
                  );

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.title.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: status.color,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  status.subtitle,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white24,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Icon(status.icon, size: 24, color: status.color),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          solarAsync.maybeWhen(
                            data: (state) {
                              final now = DateTime.now();
                              final timeStr = timeService.formatCountdown(
                                state.timeUntilNextEvent,
                              );

                              if (now.isAfter(state.phases.civilTwilightEnd)) {
                                return l10n.finished;
                              }

                              // If we are in the middle of a phase, show "Time remaining"
                              // If we are before the sun cycle starts, show "Coming in"
                              if (now.isBefore(
                                state.phases.civilTwilightBegin,
                              )) {
                                return l10n.remainingLower(timeStr);
                              }

                              return l10n.remainingLower(timeStr);
                            },
                            orElse: () => l10n.calculatingLower,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            height: 1.4,
                          ),
                        ),
                        // Smart Circadian Indicators
                        Builder(
                          builder: (context) {
                            final currentSelection = ref.watch(selectedMonitorsProvider);
                            final monitorId = currentSelection.firstOrNull ?? 'all';
                            final smartData = ref.watch(smartCircadianDataProvider(monitorId));
                            
                            final activeAjustments = <Widget>[];
                            
                            if (smartData.isWindDownActive) {
                              activeAjustments.add(_SmartAdjustmentIndicator(
                                icon: LucideIcons.moon,
                                label: l10n.featureWindDown,
                                value: (smartData.brightnessMultiplier < 1.0) 
                                  ? "-${((1.0 - smartData.brightnessMultiplier) * 100).round()}%" 
                                  : null,
                              ));
                            }
                            
                            if (smartData.isTimeShiftActive) {
                              final offset = smartData.timeOffset.inMinutes;
                              activeAjustments.add(_SmartAdjustmentIndicator(
                                icon: LucideIcons.sunrise,
                                label: l10n.featureTimeShift,
                                value: "${offset > 0 ? '+' : ''}${offset}${l10n.minutesAbbreviation}",
                              ));
                            }
                            
                            if (smartData.isSleepPressureActive) {
                              activeAjustments.add(_SmartAdjustmentIndicator(
                                icon: LucideIcons.brain,
                                label: l10n.featureSleepPressure,
                                value: "-${((1.0 - smartData.sleepPressureFactor) * 100).round()}%",
                              ));
                            }
                            
                            if (smartData.isSleepDebtActive) {
                              activeAjustments.add(_SmartAdjustmentIndicator(
                                icon: LucideIcons.battery,
                                label: l10n.featureSleepDebt,
                                value: "-${((1.0 - smartData.sleepDebtFactor) * 100).round()}%",
                              ));
                            }
                            
                            if (activeAjustments.isEmpty) return const SizedBox.shrink();
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Column(
                                children: activeAjustments.map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: w,
                                )).toList(),
                              ),
                            );
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final weather = ref
                                .watch(currentWeatherProvider)
                                .value;
                            final settingsMap = ref
                                .watch(settingsProvider)
                                .value;
                            final currentSelection = ref.watch(
                              selectedMonitorsProvider,
                            );

                            if (weather == null ||
                                settingsMap == null ||
                                !isAutoBright) {
                              return const SizedBox.shrink();
                            }

                            final settings =
                                settingsMap[currentSelection.firstOrNull ??
                                    'all'] ??
                                settingsMap['all']!;
                            if (!settings.isWeatherAdjustmentEnabled) {
                              return const SizedBox.shrink();
                            }

                            final circadianService = ref.read(
                              circadianServiceProvider,
                            );
                            final now = DateTime.now();

                            final baseBrightness = circadianService
                                .calculateTargetBrightness(
                                  state.phases,
                                  state.sunElevation,
                                  now,
                                  curveSharpness: settings.curveSharpness,
                                  curvePoints: settings.curvePoints,
                                  weather: null,
                                  presetSensitivity:
                                      settings.activePreset.weatherSensitivity,
                                );

                            final adjustedBrightness = circadianService
                                .calculateTargetBrightness(
                                  state.phases,
                                  state.sunElevation,
                                  now,
                                  curveSharpness: settings.curveSharpness,
                                  curvePoints: settings.curvePoints,
                                  weather: weather,
                                  presetSensitivity:
                                      settings.activePreset.weatherSensitivity,
                                );

                            if (baseBrightness <= 0 ||
                                adjustedBrightness >= baseBrightness) {
                              return const SizedBox.shrink();
                            }

                            final reductionPercent =
                                (((baseBrightness - adjustedBrightness) /
                                            baseBrightness) *
                                        100)
                                    .round();

                            if (reductionPercent <= 0)
                              return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Row(
                                children: [
                                  const Text(
                                    '⛅',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.weatherBrightnessReduction(
                                        reductionPercent,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF93C5FD),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
                loading: () => GlassCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFFDBA74),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => GlassCard(
                  child: Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => ref
                            .read(autoBrightnessAdjustmentProvider.notifier)
                            .toggle(),
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.sunMedium,
                                size: 20,
                                color: isAutoBright
                                    ? const Color(0xFFFDBA74)
                                    : Colors.white30,
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.autoBrightness,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAutoBright
                                        ? Colors.white
                                        : Colors.white30,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              Text(
                                isAutoBright ? l10n.active : l10n.disabled,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAutoBright
                                      ? const Color(0xFFFDBA74)
                                      : Colors.white30,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => ref
                            .read(autoTemperatureAdjustmentProvider.notifier)
                            .toggle(),
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.thermometer,
                                size: 20,
                                color: !isColorTempEnabled
                                    ? Colors.white10
                                    : isAutoTemp
                                    ? const Color(0xFFFDBA74)
                                    : Colors.white30,
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.autoTemperature,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !isColorTempEnabled
                                        ? Colors.white10
                                        : isAutoTemp
                                        ? Colors.white
                                        : Colors.white30,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              if (isColorTempEnabled) ...[
                                Text(
                                  isAutoTemp ? l10n.active : l10n.disabled,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isAutoTemp
                                        ? const Color(0xFFFDBA74)
                                        : Colors.white30,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  l10n.disabledInSettings,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white24,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(
                                          isColorTemperatureEnabledProvider
                                              .notifier,
                                        )
                                        .set(true),
                                    child: Text(
                                      l10n.enable.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFFFDBA74),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _StatRow(
                      icon: LucideIcons.sunrise,
                      label: l10n.sunriseLabel,
                      value: solarAsync.maybeWhen(
                        data: (s) => timeService.formatTime(s.phases.sunrise),
                        orElse: () => '--:--',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: LucideIcons.sunset,
                      label: l10n.sunsetLabel,
                      value: solarAsync.maybeWhen(
                        data: (s) => timeService.formatTime(s.phases.sunset),
                        orElse: () => '--:--',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: LucideIcons.sun,
                      label: l10n.goldenHourMorning,
                      value: solarAsync.maybeWhen(
                        data: (s) =>
                            timeService.formatTime(s.phases.goldenHourMorning),
                        orElse: () => '--:--',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: LucideIcons.sun,
                      label: l10n.goldenHourEvening,
                      value: solarAsync.maybeWhen(
                        data: (s) =>
                            timeService.formatTime(s.phases.goldenHourEvening),
                        orElse: () => '--:--',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final monitorsAsync = ref.watch(monitorListProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          monitorsAsync.when(
            data: (monitors) {
              final selectedIds = ref.watch(selectedMonitorsProvider);
              final isAllEffectivelySelected =
                  selectedIds.contains('all') ||
                  (monitors.isNotEmpty &&
                      monitors.every(
                        (m) => selectedIds.contains(m.deviceName),
                      ));

              return Row(
                children: [
                  _DisplayInfo(
                    label: l10n.allMonitors.toUpperCase(),
                    icon: Icons.devices,
                    isSelected: isAllEffectivelySelected,
                    onTap: () => ref
                        .read(selectedMonitorsProvider.notifier)
                        .toggle('all'),
                  ),
                  const SizedBox(width: 24),
                  ...monitors.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final monitor = entry.value;
                    final brightnessStr = monitor.realBrightness != null
                        ? '${monitor.realBrightness}%'
                        : '--';
                    final isSelected =
                        selectedIds.contains('all') ||
                        selectedIds.contains(monitor.deviceName);

                    return Padding(
                      padding: EdgeInsets.only(
                        right: idx < monitors.length - 1 ? 24 : 0,
                      ),
                      child: _DisplayInfo(
                        label:
                            '${monitor.friendlyName.toUpperCase()}: $brightnessStr',
                        isSelected: isSelected,
                        onTap: () => ref
                            .read(selectedMonitorsProvider.notifier)
                            .toggle(monitor.deviceName),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => Text(
              l10n.calculating,
              style: const TextStyle(fontSize: 10, color: Colors.white30),
            ),
            error: (e, __) => Text(
              'Error: $e',
              style: const TextStyle(fontSize: 10, color: Colors.redAccent),
            ),
          ),
          Row(
            children: [
              Text(
                l10n.engineVersion('2.4'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisplayInfo extends StatelessWidget {
  const _DisplayInfo({
    required this.label,
    required this.isSelected,
    this.icon = Icons.monitor,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFFDBA74) : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartAdjustmentIndicator extends StatelessWidget {
  const _SmartAdjustmentIndicator({
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF818CF8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFC4B5FD),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (value != null)
          Text(
            '($value)',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFFC4B5FD).withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
