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
          debugPrint('Attempting to recover from corrupted SharedPreferences...');
          try {
            final supportDir = await getApplicationSupportDirectory();
            final prefsFile = File('${supportDir.path}/shared_preferences.json');
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

      // Initialize Hotkey Service
      await container.read(hotkeyServiceProvider).init();

      // Start Local IPC (HTTP) Server for sleep integration
      container.read(localIpcServiceProvider);

      // Initial localized Tray Labels
      final initialLocale = container.read(localeProvider);
      final initialL10n = await AppLocalizations.delegate.load(initialLocale);
      await trayService.updateLabels(initialL10n);

      runApp(
        UncontrolledProviderScope(container: container, child: const SolarisApp()),
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
  void onWindowBlur() {
    if (kDebugMode) {
      debugPrint('🪟 [Window Debug] Event: Blur (Focus Lost)');
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
