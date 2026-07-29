import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen builds cleanly without duplicate key errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    // Initial pump to build tree and verify no Duplicate key FlutterError is thrown
    await tester.pump();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
