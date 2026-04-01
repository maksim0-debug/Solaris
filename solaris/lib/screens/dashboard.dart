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
import 'package:solaris/widgets/circadian_breakdown_tooltip.dart';
import 'package:solaris/widgets/about_dialog.dart';
import 'package:solaris/providers/app_info_provider.dart';
import 'package:solaris/models/settings_state.dart';

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
          const Spacer(),
          _SidebarItem(
            icon: LucideIcons.shieldCheck,
            label: l10n.legal,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const SolarisAboutDialog(),
            ),
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

        final offsets = ref.read(brightnessOffsetsProvider);
        for (final id in selection) {
          brightnessService.applyBrightnessSmoothly(
            selection: id,
            targetValue: next,
            monitors: monitors,
            monitorService: monitorService,
            offsets: offsets,
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
          if (ref.read(autoTemperatureAdjustmentProvider)) {
            temperatureService.applyTemperatureSmoothly(
              selection: id,
              targetValue: next.toDouble(),
              monitors: monitors,
              monitorService: monitorService,
              updateTemperatureCallback: (id, val) =>
                  monitorListNotifier.updateTemperature(id, val),
            );
          } else {
            temperatureService.setTemperatureInstant(
              selection: id,
              targetValue: next.toDouble(),
              monitors: monitors,
              monitorService: monitorService,
              updateTemperatureCallback: (id, val) =>
                  monitorListNotifier.updateTemperature(id, val),
            );
          }
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
        final offsets = ref.read(brightnessOffsetsProvider);
        for (final id in selection) {
          brightnessService.applyBrightnessSmoothly(
            selection: id,
            targetValue: targetBright,
            monitors: monitors,
            monitorService: monitorService,
            offsets: offsets,
            updateBrightnessCallback: (id, val) =>
                monitorListNotifier.updateBrightness(id, val),
          );
        }

        // Sync temperature
        if (ref.read(isColorTemperatureEnabledProvider)) {
          final targetTemp = ref.read(currentTemperatureProvider);
          debugPrint('Initial sync: applying temperature $targetTemp');
          for (final id in selection) {
            if (ref.read(autoTemperatureAdjustmentProvider)) {
              temperatureService.applyTemperatureSmoothly(
                selection: id,
                targetValue: targetTemp.toDouble(),
                monitors: monitors,
                monitorService: monitorService,
                updateTemperatureCallback: (id, val) =>
                    monitorListNotifier.updateTemperature(id, val),
              );
            } else {
              temperatureService.setTemperatureInstant(
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
        final offsets = ref.read(brightnessOffsetsProvider);
        brightnessService.applyBrightnessSmoothly(
          selection: 'all',
          targetValue: brightness,
          monitors: monitorValue,
          monitorService: monitorService,
          offsets: offsets,
          updateBrightnessCallback: (id, val) =>
              monitorListNotifier.updateBrightness(id, val),
        );

        // Apply temperature
        if (ref.read(isColorTemperatureEnabledProvider)) {
          final targetTemp = ref.read(currentTemperatureProvider);
          if (ref.read(autoTemperatureAdjustmentProvider)) {
            temperatureService.applyTemperatureSmoothly(
              selection: 'all',
              targetValue: targetTemp.toDouble(),
              monitors: monitorValue,
              monitorService: monitorService,
              updateTemperatureCallback: (id, val) =>
                  monitorListNotifier.updateTemperature(id, val),
            );
          } else {
            temperatureService.setTemperatureInstant(
              selection: 'all',
              targetValue: targetTemp.toDouble(),
              monitors: monitorValue,
              monitorService: monitorService,
              updateTemperatureCallback: (id, val) =>
                  monitorListNotifier.updateTemperature(id, val),
            );
          }
        }
      } else if (next.length == 1) {
        // If single monitor selected, sync UI to its current levels
        try {
          final id = next.first;
          final monitor = monitorValue.firstWhere((m) => m.deviceName == id);
          if (monitor.realBrightness != null) {
            final offsets = ref.read(brightnessOffsetsProvider);
            final offset = offsets[id] ?? 0.0;
            ref
                .read(manualBrightnessProvider.notifier)
                .update(
                  (monitor.realBrightness!.toDouble() - offset).clamp(
                    0.0,
                    100.0,
                  ),
                );
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

    String nextEventStatus = l10n.calculating;
    String nextEventTime = l10n.calculating;

    solarAsync.whenData((state) {
      final now = DateTime.now();
      final timeStr = timeService.formatCountdown(state.timeUntilNextEvent);

      // Helper to get localized event name
      String getEventName(SolarEventType type) {
        switch (type) {
          case SolarEventType.civilTwilightBegin:
            return l10n.civilTwilight;
          case SolarEventType.sunrise:
            return l10n.sunriseLabel;
          case SolarEventType.goldenHourMorning:
            return l10n.goldenHourMorning;
          case SolarEventType.goldenHourMorningEnd:
            return l10n.eventGoldenHourEnd;
          case SolarEventType.zenithStart:
            return l10n.eventZenithStart;
          case SolarEventType.solarNoon:
            return l10n.eventSolarNoon;
          case SolarEventType.zenithEnd:
            return l10n.eventZenithEnd;
          case SolarEventType.goldenHourEvening:
            return l10n.goldenHourEvening;
          case SolarEventType.goldenHourEveningEnd:
            return l10n.eventGoldenHourEnd;
          case SolarEventType.sunset:
            return l10n.sunsetLabel;
          case SolarEventType.civilTwilightEnd:
            return l10n.civilTwilight;
        }
      }

      if (state.currentPhase == CurrentDayPhase.goldenHour) {
        nextEventStatus = l10n.goldenHourActive;
        nextEventTime = l10n.remaining(timeStr);
      } else if (now.isAfter(state.phases.civilTwilightEnd)) {
        nextEventStatus = l10n.night;
        nextEventTime = l10n.finished;
      } else {
        nextEventStatus = getEventName(state.nextEventType);
        nextEventTime = l10n.comingIn(timeStr);
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
              nextEventStatus.toUpperCase(),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 18,
                color: const Color(0xFFFDBA74),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              nextEventTime,
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
    final baseBrightness = ref.watch(currentBrightnessProvider);
    final currentTemperature = ref.watch(currentTemperatureProvider);
    final selection = ref.watch(selectedMonitorsProvider);
    final bool isAutoBright = ref.watch<bool>(autoBrightnessAdjustmentProvider);
    final bool isAutoTemp = ref.watch<bool>(autoTemperatureAdjustmentProvider);
    final bool isColorTempEnabled = ref.watch(
      isColorTemperatureEnabledProvider,
    );

    double brightness = baseBrightness;
    if (selection.length == 1 && !selection.contains('all')) {
      final id = selection.first;
      final offsets = ref.watch(brightnessOffsetsProvider);
      final offset = offsets[id] ?? 0.0;
      brightness = (baseBrightness + offset).clamp(0.0, 100.0);
    }

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
                              (6500.0 - currentTemperature.clamp(3300, 6500)) /
                              (6500.0 - 3300.0),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              right: 8,
            ), // Small right padding for scrollbar
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

                                if (now.isAfter(
                                  state.phases.civilTwilightEnd,
                                )) {
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
                              final currentSelection = ref.watch(
                                selectedMonitorsProvider,
                              );
                               final monitorId =
                                  currentSelection.firstOrNull ?? 'all';
                              final smartData = ref.watch(
                                smartCircadianDataProvider(monitorId),
                              );

                              final settingsAsync = ref.watch(settingsProvider);
                              final settings = settingsAsync.maybeWhen(
                                data: (map) =>
                                    map[monitorId] ?? map['all'] ?? SettingsState(),
                                orElse: () => SettingsState(),
                              );
                              final isSmartEnabled = settings.isSmartCircadianEnabled;

                              final activeAjustments = <Widget>[];

                              if (smartData.weatherAbsoluteImpact > 0.5) {
                                final impactPercent = smartData
                                    .weatherAbsoluteImpact
                                    .round();
                                activeAjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: _getWeatherIcon(
                                      smartData.weatherCode,
                                    ),
                                    label: l10n.weatherBrightnessReduction(
                                      impactPercent,
                                    ),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartData.isWindDownActive) {
                                final impactPercent = smartData
                                    .windDownAbsoluteImpact
                                    .round();
                                final remaining =
                                    smartData.windDownMinutesRemaining;
                                final untilWakeUp =
                                    smartData.minutesUntilWakeUp;

                                activeAjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.moon,
                                    label: remaining != null
                                        ? l10n.circadianImpactWithTime(
                                            l10n.featureWindDownShort,
                                            -impactPercent,
                                            remaining,
                                            l10n.minutesAbbreviation,
                                          )
                                        : (untilWakeUp != null)
                                        ? l10n.circadianImpactWithStatus(
                                            l10n.featureWindDownShort,
                                            -impactPercent,
                                            l10n.remainingUntilWakeUp,
                                          )
                                        : l10n.circadianImpact(
                                            l10n.featureWindDownShort,
                                            -impactPercent,
                                          ),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartData.isTimeShiftActive) {
                                final impactPercent = smartData
                                    .timeShiftBrightnessImpact
                                    .round();
                                final remaining =
                                    smartData.timeShiftMinutesRemaining;
                                activeAjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.sunrise,
                                    label: remaining != null
                                        ? l10n.circadianImpactWithTime(
                                            l10n.featureTimeShiftShort,
                                            impactPercent,
                                            remaining,
                                            l10n.minutesAbbreviation,
                                          )
                                        : l10n.circadianImpact(
                                            l10n.featureTimeShiftShort,
                                            impactPercent,
                                          ),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartData.isSleepPressureActive) {
                                final impactPercent = smartData
                                    .sleepPressureAbsoluteImpact
                                    .round();
                                activeAjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.brain,
                                    label: l10n.circadianImpact(
                                      l10n.featureSleepPressureShort,
                                      -impactPercent,
                                    ),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartData.isSleepDebtActive) {
                                final impactPercent = smartData
                                    .sleepDebtAbsoluteImpact
                                    .round();
                                activeAjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.battery,
                                    label: l10n.circadianImpact(
                                      l10n.featureSleepDebtShort,
                                      -impactPercent,
                                    ),
                                  ),
                                );
                              }

                              if (!isAutoBright || activeAjustments.isEmpty)
                                return const SizedBox.shrink();

                              return Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          l10n.circadianRegulation
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white24,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        CircadianBreakdownTooltip(
                                          smartData: smartData,
                                          currentBrightness: brightness,
                                          isSmartCircadianEnabled: isSmartEnabled,
                                          child: const Icon(
                                            LucideIcons.info,
                                            size: 14,
                                            color: Colors.white24,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...activeAjustments.map(
                                      (w) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6.0,
                                        ),
                                        child: w,
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
                          data: (s) => timeService.formatTime(
                            s.phases.goldenHourMorning,
                          ),
                          orElse: () => '--:--',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        icon: LucideIcons.sun,
                        label: l10n.goldenHourEvening,
                        value: solarAsync.maybeWhen(
                          data: (s) => timeService.formatTime(
                            s.phases.goldenHourEvening,
                          ),
                          orElse: () => '--:--',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(int? code) {
    if (code == null) return LucideIcons.cloud;

    // WMO Weather interpretation codes (WW)
    // https://open-meteo.com/en/docs
    if (code == 0) return LucideIcons.sun; // Clear sky
    if (code >= 1 && code <= 2)
      return LucideIcons.cloudSun; // Mainly clear, partly cloudy
    if (code == 3) return LucideIcons.cloud; // Overcast
    if (code == 45 || code == 48) return LucideIcons.cloudFog; // Fog
    if (code >= 51 && code <= 55) return LucideIcons.cloudDrizzle; // Drizzle
    if (code >= 56 && code <= 57)
      return LucideIcons.snowflake; // Freezing Drizzle
    if (code >= 61 && code <= 63)
      return LucideIcons.cloudRain; // Rain: Slight, moderate
    if (code == 65) return LucideIcons.cloudRainWind; // Rain: Heavy
    if (code >= 66 && code <= 67) return LucideIcons.cloudRain; // Freezing Rain
    if (code >= 71 && code <= 77)
      return LucideIcons.snowflake; // Snow fall, grains
    if (code >= 80 && code <= 81)
      return LucideIcons.cloudRain; // Rain showers: Slight, moderate
    if (code == 82) return LucideIcons.cloudRainWind; // Rain showers: Heavy
    if (code >= 85 && code <= 86) return LucideIcons.snowflake; // Snow showers
    if (code >= 95 && code <= 99)
      return LucideIcons.cloudLightning; // Thunderstorm

    return LucideIcons.cloud;
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
                  const SizedBox(width: 24),
                  _OffsetSettingsButton(),
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
              Consumer(
                builder: (context, ref, child) {
                  final versionAsync = ref.watch(appVersionProvider);
                  return Text(
                    l10n.appVersion(versionAsync.value ?? '--'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                  );
                },
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

class _OffsetSettingsButton extends ConsumerWidget {
  const _OffsetSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        LucideIcons.settings,
        size: 14,
        color: ref.watch(settingsProvider).maybeWhen(
              data: (map) => map['all']?.isMultiMonitorOffsetEnabled ?? false
                  ? const Color(0xFF818CF8)
                  : Colors.white24,
              orElse: () => Colors.white24,
            ),
      ),
      onPressed: () {
        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        );

        showDialog<void>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => _MultiMonitorOffsetPopover(position: position),
        );
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 16,
      tooltip: AppLocalizations.of(context)!.multiMonitorOffsets,
    );
  }
}

class _MultiMonitorOffsetPopover extends ConsumerWidget {
  const _MultiMonitorOffsetPopover({required this.position});
  final RelativeRect position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final monitorsAsync = ref.watch(monitorListProvider);
    final globalBrightness = ref.watch(currentBrightnessProvider);
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          left: (position.left + (size.width - position.left - position.right) / 2 - 160)
              .clamp(16.0, size.width - 320 - 16.0),
          bottom: (size.height - position.top) + 16,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 320,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: settingsAsync.when(
                  data: (settingsMap) {
                    final allSettings = settingsMap['all'] ?? SettingsState();
                    final isEnabled = allSettings.isMultiMonitorOffsetEnabled;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.linkAndOffset,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  l10n.offsetFormula,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: isEnabled,
                                onChanged: (val) => ref
                                    .read(settingsProvider.notifier)
                                    .updateMultiMonitorOffsetEnabled(val),
                                activeColor: const Color(0xFF818CF8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isEnabled ? 1.0 : 0.4,
                          child: AbsorbPointer(
                            absorbing: !isEnabled,
                            child: monitorsAsync.when(
                              data: (monitors) => Column(
                                children: monitors.map((monitor) {
                                  final offset = settingsMap[monitor.deviceName]
                                          ?.brightnessOffset ??
                                      0.0;
                                  final finalVal =
                                      (globalBrightness + offset).clamp(0, 100).round();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                monitor.friendlyName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${globalBrightness.round()}% ${offset >= 0 ? '+' : ''}${offset.round()}% = $finalVal%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: offset == 0
                                                    ? Colors.white30
                                                    : const Color(0xFFFDBA74),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                              enabledThumbRadius: 6,
                                            ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                              overlayRadius: 14,
                                            ),
                                            activeTrackColor:
                                                const Color(0xFFFDBA74)
                                                    .withOpacity(0.5),
                                            inactiveTrackColor: Colors.white10,
                                            thumbColor: const Color(0xFFFDBA74),
                                            overlayColor: const Color(0xFFFDBA74)
                                                .withOpacity(0.2),
                                          ),
                                          child: Slider(
                                            value: offset,
                                            min: -100,
                                            max: 100,
                                            divisions: 200,
                                            onChanged: (val) => ref
                                                .read(settingsProvider.notifier)
                                                .updateMonitorOffset(
                                                  monitor.deviceName,
                                                  val,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              loading: () => const SizedBox(
                                height: 100,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (e, _) => Text('Error: $e'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmartAdjustmentIndicator extends StatelessWidget {
  const _SmartAdjustmentIndicator({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
      ],
    );
  }
}
