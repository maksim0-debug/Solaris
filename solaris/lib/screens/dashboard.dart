import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:solaris/widgets/temperature_breakdown_tooltip.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';
import 'package:solaris/widgets/about_dialog.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:flutter/services.dart';
import 'package:solaris/widgets/settings_search_overlay.dart';
import 'package:solaris/widgets/deep_link_target.dart';
import 'package:solaris/widgets/update_status_widget.dart';
import 'package:solaris/utils/memory_utils.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final FocusNode _focusNode = FocusNode();
  final Map<String, GlobalKey<DeepLinkTargetState>> _anchorKeys = {
    'legal_info': GlobalKey<DeepLinkTargetState>(),
    'multi_monitor_offsets': GlobalKey<DeepLinkTargetState>(),
  };

  void _handleGlobalDeepLink(String anchorId) {
    final key = _anchorKeys[anchorId];
    if (key != null && key.currentState != null) {
      key.currentState?.highlight();
      ref.read(searchAnchorProvider.notifier).clear();
    }
  }

  @override
  void initState() {
    super.initState();
    // Show window once the first frame is rendered to avoid white flash
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ref.read(startupArgsProvider);
      bool startMinimized = args.contains('--minimized');
      bool startTray = args.contains('--tray');

      if (!startMinimized && !startTray) {
        await windowManager.show();
        await windowManager.focus();
      } else if (startMinimized) {
        await windowManager.show();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await windowManager.minimize();
      } else if (startTray) {
        await windowManager.hide();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the background brightness adjustment logic alive
    ref.watch(circadianAdjustmentProvider);

    ref.listen<SettingsEncryptionError?>(settingsErrorProvider, (previous, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showDpapiErrorDialog(context, next, ref);
        });
      }
    });

    ref.listen<PostUpdateResult?>(postUpdateResultProvider, (previous, next) {
      if (next != null && next.status != PostUpdateStatus.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPostUpdateNotification(context, next, ref);
        });
      }
    });

    // Check initial post update result on startup
    final initialPostUpdateResult = ref.read<PostUpdateResult?>(postUpdateResultProvider);
    if (initialPostUpdateResult != null && initialPostUpdateResult.status != PostUpdateStatus.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPostUpdateNotification(context, initialPostUpdateResult, ref);
      });
    }

    ref.listen<bool>(isSearchVisibleProvider, (previous, next) {
      if (previous == true && next == false) {
        _focusNode.requestFocus();
      }
    });

    ref.listen(searchAnchorProvider, (previous, next) {
      if (next != null && _anchorKeys.containsKey(next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleGlobalDeepLink(next);
        });
      }
    });

    // Handle initial global anchor
    final initialAnchor = ref.read(searchAnchorProvider);
    if (initialAnchor != null && _anchorKeys.containsKey(initialAnchor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleGlobalDeepLink(initialAnchor);
      });
    }

    ref.listen<AppVisibilityState>(appLifecycleProvider, (previous, next) {
      if (next != AppVisibilityState.visible) {
        MemoryUtils.trimMemory();
      }
    });

    // Detach UI subtree whenever the window is not visible (hidden to tray OR minimized to taskbar).
    // This drops CPU and GPU usage to 0.0% when minimized and releases ~50-80 MB of RenderObjects,
    // BackdropFilter surfaces, fl_chart data, and decoded image/map tiles.
    // Background logic (circadian adjustment, temperature, API server) continues running via ProviderContainer.
    final visibility = ref.watch(appLifecycleProvider);
    final isVisible = visibility == AppVisibilityState.visible;

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return TickerMode(
      enabled: isVisible,
      child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          ref.read(isSearchVisibleProvider.notifier).setVisible(true);
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  const WindowTitleBar(),
                  Expanded(
                    child: Row(
                      children: [
                        // Sidebar
                        _Sidebar(anchorKeys: _anchorKeys),
        
                        // Main Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Header(),
                                const SizedBox(height: 32),
                                const Expanded(child: _MainView()),
                                const SizedBox(height: 32),
                                _Footer(anchorKeys: _anchorKeys),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ref.watch(isSearchVisibleProvider))
                const SettingsSearchOverlay(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showDpapiErrorDialog(
    BuildContext context,
    SettingsEncryptionError errorType,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String message = "";
    switch (errorType) {
      case SettingsEncryptionError.passwordChanged:
        message = l10n.dpapiErrorPasswordChanged;
        break;
      case SettingsEncryptionError.invalidData:
        message = l10n.dpapiErrorInvalidData;
        break;
      case SettingsEncryptionError.generic:
        message = l10n.dpapiErrorGeneric;
        break;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.security, color: Colors.orange),
              const SizedBox(width: 8),
              Text(l10n.dpapiErrorTitle),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.dpapiErrorActionOk),
              onPressed: () {
                ref.read(settingsErrorProvider.notifier).state = null;
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(l10n.dpapiErrorActionSettings),
              onPressed: () {
                ref.read(settingsErrorProvider.notifier).state = null;
                Navigator.of(dialogContext).pop();
                ref.read(activeScreenProvider.notifier).setScreen(AppScreen.settings);
              },
            ),
          ],
        );
      },
    );
  }

  void _showPostUpdateNotification(
    BuildContext context,
    PostUpdateResult result,
    WidgetRef ref,
  ) {
    if (result.status == PostUpdateStatus.none) return;

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    // Reset postUpdateResultProvider state so dialog/snackbar is shown only once
    ref.read(postUpdateResultProvider.notifier).setResult(null);

    if (result.status == PostUpdateStatus.success) {
      final versionText = result.newVersion ?? 'latest';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1E28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.greenAccent, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.updateSuccessBody(versionText),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (result.status == PostUpdateStatus.rollback ||
        result.status == PostUpdateStatus.error) {
      final isRollback = result.status == PostUpdateStatus.rollback;
      final titleText = isRollback
          ? l10n.updateRolledBackTitle
          : l10n.updateFailedTitle;
      final reasonText = result.reason ?? 'Unknown reason';
      final bodyText = isRollback
          ? l10n.updateRolledBackBody(reasonText)
          : l10n.updateFailedBody(reasonText);

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isRollback ? Colors.orangeAccent : Colors.redAccent,
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  isRollback ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
                  color: isRollback ? Colors.orangeAccent : Colors.redAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  titleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              bodyText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}

class _Sidebar extends ConsumerWidget {
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _Sidebar({required this.anchorKeys});

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
          _SidebarItem(
            icon: LucideIcons.search,
            label: l10n.searchPlaceholder.split(' (').first,
            onTap: () => ref.read(isSearchVisibleProvider.notifier).setVisible(true),
          ),
          const Spacer(),
          DeepLinkTarget(
            key: anchorKeys['legal_info'],
            id: 'legal_info',
            onDeepLink: () => showDialog<void>(
              context: context,
              builder: (context) => const SolarisAboutDialog(),
            ),
            child: _SidebarItem(
              icon: LucideIcons.shieldCheck,
              label: l10n.legal,
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => const SolarisAboutDialog(),
              ),
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
    final now = timeAsync.value ?? DateTime.now();
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
            isManual: true,
            updateBrightnessCallback: (id, val) =>
                monitorListNotifier.updateBrightness(id, val),
          );
        }
      }
    });

    // Apply temperature to monitors whenever it changes significantly
    ref.listen<int>(currentTemperatureProvider, (previous, next) {
      if (ref.read(autoTemperatureAdjustmentProvider) ||
          temperatureService.isResetLocked)
        return; // Already handled by background loop or reset lock active

      if (previous != next) {
        final selection = ref.read(selectedMonitorsProvider);
        final monitors = ref.read(monitorListProvider).value ?? [];

        final targetMonitors = selection.contains('all')
            ? monitors.map((m) => m.deviceName).toList()
            : selection.toList();

        for (final id in targetMonitors) {
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
      final wasLoading = previous == null || previous.isLoading || !previous.hasValue;
      final isReady = next.hasValue && !next.isLoading;

      // Sync if it is the first load, or if the list of monitors actually changed (e.g. plugged/unplugged device)
      bool monitorsChanged = false;
      if (previous?.hasValue == true && next.hasValue) {
        final prevIds = previous!.value!.map((m) => m.deviceName).toSet();
        final nextIds = next.value!.map((m) => m.deviceName).toSet();
        if (prevIds.length != nextIds.length || !prevIds.containsAll(nextIds)) {
          monitorsChanged = true;
        }
      }

      if ((wasLoading && isReady) || monitorsChanged) {
        debugPrint('[Dashboard ref.listen] monitorListProvider updated (Initial Sync). '
            'HasValue: ${next.hasValue}, IsLoading: ${next.isLoading}. '
            'Previous identity matches next: ${identical(previous?.value, next.value)}');
        final selection = ref.read(selectedMonitorsProvider);
        final monitors = next.value ?? [];

        // Sync brightness only if auto brightness is disabled
        if (!ref.read(autoBrightnessAdjustmentProvider)) {
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
              isManual: true,
              updateBrightnessCallback: (id, val) =>
                  monitorListNotifier.updateBrightness(id, val),
            );
          }
        }

        // Sync temperature only if color temperature is enabled and auto temperature is disabled and reset lock is inactive
        if (ref.read(isColorTemperatureEnabledProvider) &&
            !ref.read(autoTemperatureAdjustmentProvider) &&
            !temperatureService.isResetLocked) {
          final targetTemp = ref.read(currentTemperatureProvider);
          debugPrint('Initial sync: applying temperature $targetTemp');
          for (final id in selection) {
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
    });

    // Sync brightness and temperature when selection changes
    ref.listen<Set<String>>(selectedMonitorsProvider, (previous, next) {
      final monitorValue = ref.read(monitorListProvider).value;
      if (monitorValue == null) return;

      if (next.contains('all')) {
        // Apply brightness only if auto brightness is disabled
        if (!ref.read(autoBrightnessAdjustmentProvider)) {
          final brightness = ref.read(currentBrightnessProvider);
          final offsets = ref.read(brightnessOffsetsProvider);
          brightnessService.applyBrightnessSmoothly(
            selection: 'all',
            targetValue: brightness,
            monitors: monitorValue,
            monitorService: monitorService,
            offsets: offsets,
            isManual: true,
            updateBrightnessCallback: (id, val) =>
                monitorListNotifier.updateBrightness(id, val),
          );
        }

        // Apply temperature only if color temperature is enabled and auto temperature is disabled and reset lock is inactive
        if (ref.read(isColorTemperatureEnabledProvider) &&
            !ref.read(autoTemperatureAdjustmentProvider) &&
            !temperatureService.isResetLocked) {
          final targetTemp = ref.read(currentTemperatureProvider);
          temperatureService.setTemperatureInstant(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.localTime,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                nextEventStatus.toUpperCase(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 18,
                  color: const Color(0xFFFDBA74),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                nextEventTime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: Colors.white54,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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

class _DashboardView extends ConsumerStatefulWidget {
  const _DashboardView();

  @override
  ConsumerState<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<_DashboardView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<DeepLinkTargetState>> _anchorKeys = {
    'brightness_control': GlobalKey<DeepLinkTargetState>(),
    'auto_brightness': GlobalKey<DeepLinkTargetState>(),
    'auto_temperature': GlobalKey<DeepLinkTargetState>(),
    'color_temperature': GlobalKey<DeepLinkTargetState>(),
  };

  void _scrollToAnchor(String anchorId) {
    final key = _anchorKeys[anchorId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
      key.currentState?.highlight();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final solarAsync = ref.watch(solarStateStreamProvider);
    final timeService = ref.watch(timeServiceProvider);
    final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
    final baseBrightness = ref.watch(currentBrightnessProvider);
    final currentTemperature = ref.watch(currentTemperatureProvider);
    final selection = ref.watch(selectedMonitorsProvider);
    final bool isAutoBright = ref.watch<bool>(autoBrightnessAdjustmentProvider);
    final bool isAutoTemp = ref.watch<bool>(autoTemperatureAdjustmentProvider);
    final bool isColorTempEnabled = ref.watch(
      isColorTemperatureEnabledProvider,
    );

    ref.listen(searchAnchorProvider, (previous, next) {
      if (next != null && _anchorKeys.containsKey(next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToAnchor(next);
          ref.read(searchAnchorProvider.notifier).clear();
        });
      }
    });

    // Handle initial anchor on first build/mount
    final initialAnchor = ref.read(searchAnchorProvider);
    if (initialAnchor != null && _anchorKeys.containsKey(initialAnchor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAnchor(initialAnchor);
        ref.read(searchAnchorProvider.notifier).clear();
      });
    }

    final monitors = ref.watch(monitorListProvider).value ?? [];

    double targetBrightness = baseBrightness;
    if (selection.length == 1 && !selection.contains('all')) {
      final id = selection.first;
      final offsets = ref.watch(brightnessOffsetsProvider);
      final offset = offsets[id] ?? 0.0;
      targetBrightness = (baseBrightness + offset).clamp(0.0, 100.0);
    }

    double brightness = targetBrightness;
    if (isAutoBright) {
      if (selection.length == 1 && !selection.contains('all')) {
        final id = selection.first;
        final monitor = monitors.where((m) => m.deviceName == id).firstOrNull;
        if (monitor != null && monitor.realBrightness != null) {
          brightness = monitor.realBrightness!.toDouble();
        }
      } else {
        final primaryMonitor = monitors.where((m) => m.isPrimary).firstOrNull;
        if (primaryMonitor != null && primaryMonitor.realBrightness != null) {
          brightness = primaryMonitor.realBrightness!.toDouble();
        } else {
          final firstWithBrightness = monitors.where((m) => m.realBrightness != null).firstOrNull;
          if (firstWithBrightness != null) {
            brightness = firstWithBrightness.realBrightness!.toDouble();
          }
        }
      }
    }

    double tempVal = currentTemperature.toDouble();
    if (isAutoTemp && isColorTempEnabled) {
      if (selection.length == 1 && !selection.contains('all')) {
        final id = selection.first;
        final monitor = monitors.where((m) => m.deviceName == id).firstOrNull;
        if (monitor != null && monitor.realTemperature != null) {
          tempVal = monitor.realTemperature!.toDouble();
        }
      } else {
        final primaryMonitor = monitors.where((m) => m.isPrimary).firstOrNull;
        if (primaryMonitor != null && primaryMonitor.realTemperature != null) {
          tempVal = primaryMonitor.realTemperature!.toDouble();
        } else {
          final firstWithTemp = monitors.where((m) => m.realTemperature != null).firstOrNull;
          if (firstWithTemp != null) {
            tempVal = firstWithTemp.realTemperature!.toDouble();
          }
        }
      }
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
                                  final hour = now.hour;
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
                              (6500.0 - tempVal.clamp(3300.0, 6500.0)) /
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
                      DeepLinkTarget(
                        key: _anchorKeys['brightness_control'],
                        id: 'brightness_control',
                        child: BrightnessSlider(
                          value: brightness,
                          onChanged: (val) => ref
                              .read(currentBrightnessProvider.notifier)
                              .setManualBrightness(val),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DeepLinkTarget(
                        key: _anchorKeys['color_temperature'],
                        id: 'color_temperature',
                        child: TemperatureSlider(
                          value: tempVal,
                          onChanged: (val) => ref
                              .read(currentTemperatureProvider.notifier)
                              .setManualTemperature(val.round()),
                        ),
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
            controller: _scrollController,
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
                      isAutoTemp,
                      now,
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
                              final smartDataTemp = ref.watch(
                                smartCircadianTemperatureDataProvider(monitorId),
                              );

                              final settingsAsync = ref.watch(settingsProvider);
                              final settings = settingsAsync.maybeWhen(
                                data: (map) =>
                                    map[monitorId] ?? map['all'] ?? SettingsState(),
                                orElse: () => SettingsState(),
                              );
                              final isSmartEnabled = settings.isSmartCircadianEnabled;

                              // 1. Brightness adjustments
                              final activeAdjustments = <Widget>[];

                              if (smartData.weatherAbsoluteImpact > 0.5) {
                                final impactPercent = smartData
                                    .weatherAbsoluteImpact
                                    .round();
                                activeAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: getWeatherIcon(smartData.weatherCode),
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

                                activeAdjustments.add(
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
                                activeAdjustments.add(
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
                                activeAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.hourglass,
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
                                activeAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.battery,
                                    label: l10n.circadianImpact(
                                      l10n.featureSleepDebtShort,
                                      -impactPercent,
                                    ),
                                  ),
                                );
                              }

                              // 2. Temperature adjustments
                              final activeTempAdjustments = <Widget>[];

                              if (smartDataTemp.weatherTemperatureImpact.abs() > 0.5) {
                                final impactK = smartDataTemp.weatherTemperatureImpact.round();
                                activeTempAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: getWeatherIcon(smartDataTemp.weatherCode),
                                    label: '${l10n.weatherTemperatureAdjustmentTitle}: ${impactK} K',
                                    iconColor: const Color(0xFF818CF8),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartDataTemp.sleepPressureTemperatureImpact.abs() > 0.5) {
                                final impactK = smartDataTemp.sleepPressureTemperatureImpact.round();
                                activeTempAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.hourglass,
                                    label: '${l10n.featureSleepPressureShort}: ${impactK} K',
                                    iconColor: const Color(0xFFA78BFA),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartDataTemp.windDownTemperatureImpact.abs() > 0.5) {
                                final impactK = smartDataTemp.windDownTemperatureImpact.round();
                                activeTempAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.moon,
                                    label: '${l10n.featureWindDownShort}: ${impactK} K',
                                    iconColor: const Color(0xFF818CF8),
                                  ),
                                );
                              }

                              if (isSmartEnabled && smartDataTemp.sleepDebtTemperatureImpact.abs() > 0.5) {
                                final impactK = smartDataTemp.sleepDebtTemperatureImpact.round();
                                activeTempAdjustments.add(
                                  _SmartAdjustmentIndicator(
                                    icon: LucideIcons.battery,
                                    label: '${l10n.featureSleepDebtShort}: ${impactK} K',
                                    iconColor: const Color(0xFFF43F5E),
                                  ),
                                );
                              }

                              final bool showBright = isAutoBright;
                              final bool showTemp = isAutoTemp && isColorTempEnabled;

                              if (!showBright && !showTemp) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showBright) ...[
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
                                            currentBrightness: targetBrightness,
                                            isSmartCircadianEnabled: isSmartEnabled,
                                            child: const Icon(
                                              LucideIcons.info,
                                              size: 14,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (activeAdjustments.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ...activeAdjustments.map(
                                          (w) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: w,
                                          ),
                                        ),
                                      ],
                                    ],
                                    if (showBright && showTemp)
                                      const SizedBox(height: 16),
                                    if (showTemp) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            l10n.temperatureRegulationTitle
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white24,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          TemperatureBreakdownTooltip(
                                            smartData: smartDataTemp,
                                            currentTemperature: tempVal.round(),
                                            isSmartCircadianEnabled: isSmartEnabled,
                                            child: const Icon(
                                              LucideIcons.info,
                                              size: 14,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (activeTempAdjustments.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ...activeTempAdjustments.map(
                                          (w) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: w,
                                          ),
                                        ),
                                      ],
                                    ],
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
                          child: DeepLinkTarget(
                            key: _anchorKeys['auto_brightness'],
                            id: 'auto_brightness',
                            child: GlassCard(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
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
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DeepLinkTarget(
                          key: _anchorKeys['auto_temperature'],
                          id: 'auto_temperature',
                          child: InkWell(
                            onTap: () => ref
                                .read(autoTemperatureAdjustmentProvider.notifier)
                                .toggle(),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassCard(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
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
  final Map<String, GlobalKey<DeepLinkTargetState>> anchorKeys;
  const _Footer({required this.anchorKeys});

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
                        .selectOnly('all'),
                  ),
                  const SizedBox(width: 24),
                  ...monitors.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final monitor = entry.value;
                    final brightnessStr = monitor.realBrightness != null
                        ? '${monitor.realBrightness}%'
                        : '--';
                    final isSelected =
                        !selectedIds.contains('all') &&
                        selectedIds.contains(monitor.deviceName);

                    return Padding(
                      padding: EdgeInsets.only(
                        right: idx < monitors.length - 1 ? 24 : 0,
                      ),
                      child: _DisplayInfo(
                        label:
                            '${monitor.friendlyName.toUpperCase()}: $brightnessStr',
                        isSelected: isSelected,
                        onTap: () {
                          final notifier =
                              ref.read(selectedMonitorsProvider.notifier);
                          if (isSelected) {
                            notifier.selectOnly('all');
                          } else {
                            notifier.selectOnly(monitor.deviceName);
                          }
                        },
                      ),
                    );
                  }),
                  const SizedBox(width: 24),
                  DeepLinkTarget(
                    key: anchorKeys['multi_monitor_offsets'],
                    id: 'multi_monitor_offsets',
                    onDeepLink: () {
                      anchorKeys['multi_monitor_offsets']
                          ?.currentContext
                          ?.findAncestorWidgetOfExactType<IconButton>()
                          ?.onPressed
                          ?.call();
                    },
                    child: const _OffsetSettingsButton(),
                  ),
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
          const UpdateStatusWidget(),

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
  const _SmartAdjustmentIndicator({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF818CF8),
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
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
