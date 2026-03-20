import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/window_title_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/screens/schedule_screen.dart';
import 'package:solaris/widgets/brightness_dial.dart';
import 'package:solaris/widgets/brightness_slider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/sun_path_painter.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/screens/location_screen.dart';
import 'package:solaris/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  static const IconData insights =
      IconData(0xe347, fontFamily: 'MaterialIcons');

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
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white24,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.5,
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

    // Apply brightness to monitors whenever it changes significantly
    ref.listen<double>(currentBrightnessProvider, (previous, next) {
      if (previous?.round() != next.round()) {
        final selection = ref.read(selectedMonitorIdProvider);
        final monitors = ref.read(monitorListProvider).value ?? [];
        ref.read(brightnessServiceProvider).applyBrightnessSmoothly(
          selection: selection,
          targetValue: next,
          monitors: monitors,
          monitorService: ref.read(monitorServiceProvider),
          updateBrightnessCallback: (id, val) => 
              ref.read(monitorListProvider.notifier).updateBrightness(id, val),
        );
      }
    });

    // Initial sync when monitors are detected
    ref.listen(monitorListProvider, (previous, next) {
      if (next.hasValue && !next.isLoading) {
        final target = ref.read(currentBrightnessProvider);
        final selection = ref.read(selectedMonitorIdProvider);
        final monitors = next.value ?? [];
        ref.read(brightnessServiceProvider).applyBrightnessSmoothly(
          selection: selection,
          targetValue: target,
          monitors: monitors,
          monitorService: ref.read(monitorServiceProvider),
          updateBrightnessCallback: (id, val) => 
              ref.read(monitorListProvider.notifier).updateBrightness(id, val),
        );
      }
    });
    // Sync brightness when selection changes
    ref.listen<String>(selectedMonitorIdProvider, (previous, next) {
      final monitorValue = ref.read(monitorListProvider).value;
      if (monitorValue == null) return;

      if (next == 'all') {
        final brightness = ref.read(currentBrightnessProvider);
        ref.read(brightnessServiceProvider).applyBrightnessSmoothly(
          selection: 'all',
          targetValue: brightness,
          monitors: monitorValue,
          monitorService: ref.read(monitorServiceProvider),
          updateBrightnessCallback: (id, val) => 
              ref.read(monitorListProvider.notifier).updateBrightness(id, val),
        );
      } else {
        try {
          final monitor = monitorValue.firstWhere((m) => m.deviceName == next);
          if (monitor.realBrightness != null) {
            ref
                .read(manualBrightnessProvider.notifier)
                .update(monitor.realBrightness!.toDouble());
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
      if (now.isBefore(state.phases.sunrise)) {
        final diff = state.phases.sunrise.difference(now);
        goldenHourTime = l10n.comingIn(timeService.formatCountdown(diff));
      } else if (now.isBefore(state.phases.sunset)) {
        final diff = state.phases.sunset.difference(now);
        goldenHourStatus = state.currentPhase == CurrentDayPhase.goldenHour
            ? l10n.goldenHourActive
            : l10n.goldenHour;
        goldenHourTime = l10n.remaining(timeService.formatCountdown(diff));
      } else {
        goldenHourStatus = l10n.night;
        goldenHourTime = l10n.finished;
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
    final bool isAutoAdapt = ref.watch<bool>(autoAdjustmentProvider);

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
                                orElse: () => 0.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Brightness Indicator
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
                child: BrightnessSlider(
                  value: brightness,
                  onChanged: (val) => ref
                      .read(currentBrightnessProvider.notifier)
                      .setManualBrightness(val),
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
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          solarAsync
                              .maybeWhen(
                                data: (state) {
                                  final now = DateTime.now();
                                  if (now.isBefore(state.phases.sunrise))
                                    return l10n.night;
                                  if (now.isBefore(state.phases.sunset))
                                    return l10n.goldenHour;
                                  return l10n.night;
                                },
                                orElse: () => l10n.calculating,
                              )
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFDBA74),
                          ),
                        ),
                        const Icon(
                          LucideIcons.sun,
                          size: 20,
                          color: Color(0xFFFDBA74),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      solarAsync.maybeWhen(
                        data: (state) {
                          final now = DateTime.now();
                          if (now.isBefore(state.phases.sunrise)) {
                            return l10n.remainingLower(
                              timeService.formatCountdown(
                                state.phases.sunrise.difference(now),
                              ),
                            );
                          } else if (now.isBefore(state.phases.sunset)) {
                            return l10n.activeLower(
                              timeService.formatCountdown(
                                state.phases.sunset.difference(now),
                              ),
                            );
                          } else {
                            return l10n.finished;
                          }
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
                      solarAsync.maybeWhen(
                        data: (state) {
                          final now = DateTime.now();
                          if (now.isBefore(state.phases.sunrise)) {
                            final hours = state.phases.sunrise
                                .difference(now)
                                .inHours;
                            return l10n.transitionNotice(hours);
                          } else if (now.isBefore(state.phases.sunset)) {
                            return l10n.goldenHourNotice;
                          } else {
                            return l10n.solarCycleEnded;
                          }
                        },
                        orElse: () => l10n.updatingSolarData,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          ref.read(autoAdjustmentProvider.notifier).toggle(),
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.refreshCcw,
                              size: 20,
                              color: isAutoAdapt
                                  ? const Color(0xFFFDBA74)
                                  : Colors.white30,
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.autoAdapt,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAutoAdapt
                                      ? Colors.white
                                      : Colors.white30,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              isAutoAdapt ? l10n.active : l10n.disabled,
                              style: TextStyle(
                                fontSize: 10,
                                color: isAutoAdapt
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
                      onTap: () => ref.read(nightModeProvider.notifier).toggle(),
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.moon,
                              size: 20,
                              color: ref.watch(nightModeProvider)
                                  ? const Color(0xFFFDBA74) // Or some night color
                                  : Colors.white30,
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.nightShift,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ref.watch(nightModeProvider)
                                      ? Colors.white
                                      : Colors.white30,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              ref.watch(nightModeProvider)
                                  ? l10n.active
                                  : l10n.disabled,
                              style: TextStyle(
                                fontSize: 10,
                                color: ref.watch(nightModeProvider)
                                    ? const Color(0xFFFDBA74)
                                    : Colors.white30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
              final selectedId = ref.watch(selectedMonitorIdProvider);
              return Row(
                children: [
                  // Multi-monitor select button
                  _DisplayInfo(
                    label: l10n.allMonitors.toUpperCase(),
                    icon: Icons.devices,
                    isSelected: selectedId == 'all',
                    onTap: () => ref
                        .read(selectedMonitorIdProvider.notifier)
                        .select('all'),
                  ),
                  const SizedBox(width: 24),
                  ...monitors.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final monitor = entry.value;
                    final brightnessStr = monitor.realBrightness != null
                        ? '${monitor.realBrightness}%'
                        : '--';
                    final isSelected =
                        selectedId == 'all' || selectedId == monitor.deviceName;

                    return Padding(
                      padding: EdgeInsets.only(
                        right: idx < monitors.length - 1 ? 24 : 0,
                      ),
                      child: _DisplayInfo(
                        label:
                            '${monitor.friendlyName.toUpperCase()}: $brightnessStr',
                        isSelected: isSelected,
                        onTap: () => ref
                            .read(selectedMonitorIdProvider.notifier)
                            .select(monitor.deviceName),
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
      onHover: (_) {},
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
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
      ),
    );
  }
}
