import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/screens/settings_screen.dart';
import 'package:solaris/services/settings_search_service.dart';

void main() {
  testWidgets('SettingsSearchService indexes Solaris Control API, API Keys, and Webhooks for deep linking', (WidgetTester tester) async {
    late SettingsSearchService service;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) {
              service = SettingsSearchService(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    // 1. Search for "solaris control api"
    final apiResults = service.search('solaris control api');
    expect(apiResults.any((item) => item.anchorId == 'solaris_api'), isTrue);
    final apiItem = apiResults.firstWhere((item) => item.anchorId == 'solaris_api');
    expect(apiItem.screen, equals(AppScreen.settings));

    // 2. Search for "ключи" / "api keys"
    final keyResults = service.search('ключи api');
    expect(keyResults.any((item) => item.anchorId == 'api_keys'), isTrue);
    final keyItem = keyResults.firstWhere((item) => item.anchorId == 'api_keys');
    expect(keyItem.screen, equals(AppScreen.settings));

    // 3. Search for "вебхуки" / "webhooks"
    final webhookResults = service.search('вебхуки');
    expect(webhookResults.any((item) => item.anchorId == 'webhooks'), isTrue);
    final webhookItem = webhookResults.firstWhere((item) => item.anchorId == 'webhooks');
    expect(webhookItem.screen, equals(AppScreen.settings));

    // 4. English search test
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              service = SettingsSearchService(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final enResults = service.search('swagger');
    expect(enResults.any((item) => item.anchorId == 'solaris_api'), isTrue);
  });

  testWidgets('SettingsScreen builds cleanly without GlobalKey duplication', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
