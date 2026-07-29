import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/screens/dashboard.dart';

void main() {
  group('MonitorInfo.isDdcSupported tests', () {
    test('isDdcSupported returns true when realBrightness is present', () {
      final monitor = MonitorInfo(
        id: 'DISPLAY1',
        name: 'ASUS VG259',
        friendlyName: 'ASUS VG259',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'abc123',
        isPrimary: true,
        realBrightness: 77,
      );
      expect(monitor.isDdcSupported, isTrue);
    });

    test('isDdcSupported returns false when realBrightness is null', () {
      final monitor = MonitorInfo(
        id: 'DISPLAY2',
        name: 'Generic Monitor',
        friendlyName: 'ASUS VG259QMR5A',
        deviceName: r'\\.\DISPLAY2',
        deviceIdHash: 'xyz456',
        isPrimary: false,
        realBrightness: null,
      );
      expect(monitor.isDdcSupported, isFalse);
    });
  });

  group('DisplayInfo UI tests', () {
    Widget buildTestableWidget(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets('renders brightness percentage when DDC/CI is supported', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const DisplayInfo(
            label: 'LG IPS224',
            brightness: 77,
            isDdcSupported: true,
            isSelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LG IPS224: 77%'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets(
      'renders red label and refresh action when DDC/CI is NOT supported',
      (WidgetTester tester) async {
        bool refreshCalled = false;

        await tester.pumpWidget(
          buildTestableWidget(
            DisplayInfo(
              label: 'ASUS VG259QMR5A',
              brightness: null,
              isDdcSupported: false,
              isSelected: true,
              onRefreshDdc: () {
                refreshCalled = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ASUS VG259QMR5A'), findsOneWidget);
        expect(find.byIcon(LucideIcons.x), findsNothing);
        expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.refreshCw));
        await tester.pump();

        expect(refreshCalled, isTrue);
      },
    );
  });
}
