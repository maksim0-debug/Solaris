import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/app_info_provider.dart';
import 'package:solaris/widgets/about_dialog.dart';

void main() {
  Widget createTestableWidget({
    Locale locale = const Locale('en'),
    String appVersion = '1.4.0',
  }) {
    return ProviderScope(
      overrides: [appVersionProvider.overrideWith((ref) => appVersion)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: SolarisAboutDialog())),
      ),
    );
  }

  group('SolarisAboutDialog layout and localization tests', () {
    testWidgets('renders correctly in English without layout overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Solaris'), findsWidgets);
      expect(find.text('Solaris v1.4.0'), findsOneWidget);
      expect(find.text('DISCLAIMER'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('View Licenses'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('renders correctly in Ukrainian without layout overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(locale: const Locale('uk')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Solaris'), findsWidgets);
      expect(find.text('Solaris v1.4.0'), findsOneWidget);
      expect(find.text('ВІДМОВА ВІД ВІДПОВІДАЛЬНОСТІ'), findsOneWidget);
      expect(find.text('Політика конфіденційності'), findsOneWidget);
      expect(find.text('Переглянути ліцензії'), findsOneWidget);
      expect(find.text('Закрити'), findsOneWidget);
    });

    testWidgets('renders correctly in Russian without layout overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(locale: const Locale('ru')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Solaris'), findsWidgets);
      expect(find.text('Solaris v1.4.0'), findsOneWidget);
      expect(find.text('ОТКАЗ ОТ ОТВЕТСТВЕННОСТИ'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Лицензии'), findsOneWidget);
      expect(find.text('Закрыть'), findsOneWidget);
    });

    testWidgets(
      'renders in narrow constraints with Close button at bottom right',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestableWidget(locale: const Locale('uk')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final privacyFinder = find.text('Політика конфіденційності');
        final closeFinder = find.text('Закрити');

        expect(privacyFinder, findsOneWidget);
        expect(closeFinder, findsOneWidget);

        final privacyTopLeft = tester.getTopLeft(privacyFinder);
        final closeTopLeft = tester.getTopLeft(closeFinder);

        // In constrained layout, Close button is placed below the legal links
        expect(privacyTopLeft.dy, lessThan(closeTopLeft.dy));
      },
    );
  });
}
