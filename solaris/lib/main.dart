import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/dashboard.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';

import 'package:solaris/services/time_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TimeService.initialize();

  // Инициализируем локальное хранилище до запуска UI
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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
