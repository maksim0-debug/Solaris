import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/dashboard.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';

import 'package:solaris/services/time_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/services/tray_service.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solaris/services/hotkey_service.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/utils/memory_utils.dart';

void main(List<String> args) {
  final format = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final timestampRegex = RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}');

  // Global override for debugPrint
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final timeStr = format.format(DateTime.now());
      if (!timestampRegex.hasMatch(message)) {
        originalDebugPrint('[$timeStr] $message', wrapWidth: wrapWidth);
        return;
      }
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Strict ImageCache limits to prevent map tiles from bloating RAM to 150+ MB
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          12 * 1024 * 1024; // 12 MB max
      PaintingBinding.instance.imageCache.maximumSize = 30; // 30 items max

      await windowManager.ensureInitialized();
      await TimeService.initialize();

      // Must unregister all hotkeys at startup to avoid conflicts
      await hotKeyManager.unregisterAll();

      bool startMinimized = args.contains('--minimized');
      bool startTray = args.contains('--tray');

      WindowOptions windowOptions = WindowOptions(
        size: const Size(1300, 890),
        center: true,
        backgroundColor: AppTheme.background,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (startTray) {
          await windowManager.hide();
        } else if (startMinimized) {
          await windowManager.hide();
        }
        // We will show/minimize the window once the UI is ready in dashboard.dart
      });

      // Tray initialization
      final trayService = TrayService();

      // Initialize storage
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('Error initializing SharedPreferences: $e');
        if (e is FormatException) {
          debugPrint(
            'Attempting to recover from corrupted SharedPreferences...',
          );
          try {
            final supportDir = await getApplicationSupportDirectory();
            final prefsFile = File(
              '${supportDir.path}/shared_preferences.json',
            );
            if (await prefsFile.exists()) {
              await prefsFile.delete();
              debugPrint('Corrupted SharedPreferences deleted. Retrying...');
              prefs = await SharedPreferences.getInstance();
            }
          } catch (recoveryError) {
            debugPrint('Failed to recover SharedPreferences: $recoveryError');
          }
        }
      }

      // Provider container initialization for usage in main and window events
      final container = ProviderContainer(
        overrides: [
          if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
          startupArgsProvider.overrideWithValue(args),
        ],
      );

      // Initialize Tray Service
      await trayService.init(container);

      // Keep monitor gamma neutral across restarts when the feature is disabled.
      if (!container.read(isColorTemperatureEnabledProvider)) {
        unawaited(
          container
              .read(isColorTemperatureEnabledProvider.notifier)
              .resetToNeutralNow(),
        );
      }

      container.listen<bool>(isColorTemperatureEnabledProvider, (prev, next) {
        if (prev == true && next == false) {
          unawaited(
            container
                .read(isColorTemperatureEnabledProvider.notifier)
                .resetToNeutralNow(),
          );
        }
      });

      // Prevent app from closing when clicking 'X'
      await windowManager.setPreventClose(true);
      windowManager.addListener(WindowEventHandler(container));
      WidgetsBinding.instance.addObserver(_SystemLifecycleObserver(container));

      // Initialize Hotkey Service
      await container.read(hotkeyServiceProvider).init();

      // Keep background hardware adjustment provider active
      container.read(circadianAdjustmentProvider);

      // Start Local IPC (HTTP) Server for sleep integration
      container.read(localIpcServiceProvider);

      // Initial localized Tray Labels
      final initialLocale = container.read(localeProvider);
      final initialL10n = await AppLocalizations.delegate.load(initialLocale);
      await trayService.updateLabels(initialL10n);

      // Execute Post-Update Processing (log parsing, retention rotation, backup cleanup, autorun & temp GC)
      final postUpdateService = container.read(postUpdateServiceProvider);
      final settingsMap = container.read(settingsProvider).value;
      final currentStartupMode =
          settingsMap?['all']?.startupMode ?? StartupMode.minimized;
      final postUpdateResult = await postUpdateService.processPostUpdate(
        startupMode: currentStartupMode,
      );
      container
          .read(postUpdateResultProvider.notifier)
          .setResult(postUpdateResult);

      // Automatic update check on cold startup & 24-hour periodic timer
      unawaited(container.read(updateProvider.notifier).checkForUpdate());
      Timer.periodic(const Duration(hours: 24), (_) {
        container.read(updateProvider.notifier).checkForUpdate();
      });

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const SolarisApp(),
        ),
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        final timeStr = format.format(DateTime.now());
        if (!timestampRegex.hasMatch(line)) {
          parent.print(zone, '[$timeStr] $line');
        } else {
          parent.print(zone, line);
        }
      },
    ),
  );
}

class SolarisApp extends ConsumerWidget {
  const SolarisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Locale>(localeProvider, (prev, next) async {
      final l10n = await AppLocalizations.delegate.load(next);
      TrayService().updateLabels(l10n);
    });

    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Solaris',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
      locale: locale,
      home: const DashboardScreen(),
    );
  }
}

class WindowEventHandler extends WindowListener {
  final ProviderContainer container;
  WindowEventHandler(this.container);

  @override
  void onWindowClose() async {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Close (Prevented & Hidden)');
    }
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      container.read(appLifecycleProvider.notifier).setHidden();
      await windowManager.hide();
    }
  }

  @override
  void onWindowMinimize() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Minimize');
    }
    container.read(appLifecycleProvider.notifier).setMinimized();
  }

  @override
  void onWindowRestore() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Restore');
    }
    container.read(appLifecycleProvider.notifier).setVisible();
  }

  @override
  void onWindowFocus() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Focus');
    }
    container.read(appLifecycleProvider.notifier).setVisible();
  }

  @override
  void onWindowBlur() async {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Blur (Focus Lost)');
    }

    // If window was minimized (e.g. via Taskbar click, Win+D, or Alt+Tab toggle),
    // trim memory and set minimized lifecycle state to stop GPU rendering and drop CPU/GPU to 0.0%
    try {
      bool isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        MemoryUtils.trimMemory();
        container.read(appLifecycleProvider.notifier).setMinimized();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🪟 [Window Debug] Blur: isMinimized check failed: $e');
      }
    }
  }

  @override
  void onWindowMaximize() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Maximize');
    }
  }

  @override
  void onWindowUnmaximize() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Unmaximize');
    }
  }

  @override
  void onWindowEvent(String eventName) {
    if (kDebugMode && eventName != 'resize') {
      debugPrint('🪟 [Window Debug] Raw Event: $eventName');
    }
  }
}

/// Listens to Flutter Engine system lifecycle state changes (inactive, hidden, paused, resumed)
/// to automatically trim memory and update appLifecycleProvider state on OS events.
class _SystemLifecycleObserver extends WidgetsBindingObserver {
  final ProviderContainer container;
  _SystemLifecycleObserver(this.container);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('🪟 [Engine Lifecycle Debug] State: $state');
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      MemoryUtils.trimMemory();
      container.read(appLifecycleProvider.notifier).setMinimized();
    } else if (state == AppLifecycleState.inactive) {
      MemoryUtils.trimMemory();
      windowManager
          .isMinimized()
          .then((isMinimized) {
            if (isMinimized) {
              container.read(appLifecycleProvider.notifier).setMinimized();
            }
          })
          .catchError((Object e) {
            if (kDebugMode) {
              debugPrint(
                '🪟 [Engine Lifecycle Debug] isMinimized check failed: $e',
              );
            }
          });
    } else if (state == AppLifecycleState.resumed) {
      container.read(appLifecycleProvider.notifier).setVisible();
    }
  }
}
