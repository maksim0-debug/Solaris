import 'package:flutter/material.dart';
import 'dart:async';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solaris/services/hotkey_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await TimeService.initialize();

  // Must unregister all hotkeys at startup to avoid conflicts
  await hotKeyManager.unregisterAll();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  bool startMinimized = args.contains('--minimized');

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1300, 890),
    center: true,
    backgroundColor: AppTheme.background,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (startMinimized) {
      await windowManager.hide();
    }
    // We will show the window once the UI is ready in dashboard.dart
  });

  // Tray initialization
  final trayService = TrayService();
  await trayService.init();

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
    ],
  );

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

  runApp(
    UncontrolledProviderScope(container: container, child: const SolarisApp()),
  );
}

class SolarisApp extends ConsumerWidget {
  const SolarisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      supportedLocales: const [Locale('en'), Locale('ru')],
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
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      container.read(appLifecycleProvider.notifier).setHidden();
      await windowManager.hide();
    }
  }

  @override
  void onWindowMinimize() {
    container.read(appLifecycleProvider.notifier).setMinimized();
  }

  @override
  void onWindowRestore() {
    container.read(appLifecycleProvider.notifier).setVisible();
  }

  @override
  void onWindowFocus() {
    container.read(appLifecycleProvider.notifier).setVisible();
  }
}
