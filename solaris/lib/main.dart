import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/dashboard.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';

import 'package:solaris/services/time_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/services/tray_service.dart';
import 'package:solaris/providers/lifecycle_provider.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await TimeService.initialize();

  bool startMinimized = args.contains('--minimized');

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
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
  }

  // Provider container initialization for usage in main and window events
  final container = ProviderContainer(
    overrides: [
      if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Prevent app from closing when clicking 'X'
  await windowManager.setPreventClose(true);
  windowManager.addListener(WindowEventHandler(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SolarisApp(),
    ),
  );
}

class SolarisApp extends StatelessWidget {
  const SolarisApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      locale: const Locale('ru'),
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
