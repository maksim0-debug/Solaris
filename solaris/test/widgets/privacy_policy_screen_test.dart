import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/privacy_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('uk'),
      ],
      home: const PrivacyPolicyScreen(),
    );
  }

  testWidgets('PrivacyPolicyScreen initializes and renders without exception', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

    // Pump to process future completion
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  testWidgets('PrivacyPolicyScreen handles Ukrainian locale without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('uk')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  testWidgets('PrivacyPolicyScreen handles Russian locale without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('ru')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });
}
