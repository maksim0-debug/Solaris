import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
      home: Scaffold(body: child),
    );
  }

  group('Stage 4 GUI: ApiPermissionsDialog & ExpansionTile Accordion Tests', () {
    testWidgets(
      'Renders all 7 category ExpansionTiles with Tri-State checkboxes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const ApiPermissionsDialog(initialConfig: ApiPermissionsConfig()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsNWidgets(7));
        expect(
          find.text('Monitors (Brightness, Temp, Offsets)'),
          findsOneWidget,
        );
        expect(find.text('Presets & Brightness Profiles'), findsOneWidget);
        expect(
          find.text('Circadian Rhythm & Auto-Adjustments'),
          findsOneWidget,
        );
        expect(find.text('Game Mode & App Whitelists'), findsOneWidget);
        expect(find.text('Environment & Weather Adjustments'), findsOneWidget);
        expect(find.text('Sleep Actions & Status Pushes'), findsOneWidget);
        expect(
          find.text('System Actions (Webhooks, Animations)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Expanding category tile shows granular action checkboxes and mono action keys',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const ApiPermissionsDialog(initialConfig: ApiPermissionsConfig()),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure visible and tap on Monitors category ExpansionTile to expand children
        await tester.ensureVisible(
          find.text('Monitors (Brightness, Temp, Offsets)'),
        );
        await tester.tap(find.text('Monitors (Brightness, Temp, Offsets)'));
        await tester.pumpAndSettle();

        expect(find.text('Set Brightness'), findsOneWidget);
        expect(find.text('set_brightness'), findsOneWidget);
        expect(find.text('Set Color Temperature (K)'), findsOneWidget);
        expect(find.text('set_temperature'), findsOneWidget);
        expect(find.text('Monitor Offset Adjustment'), findsOneWidget);
        expect(find.text('set_monitor_offset'), findsOneWidget);
      },
    );

    testWidgets(
      'Toggling individual action updates state and returns updated ApiPermissionsConfig on Save',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        ApiPermissionsConfig? resultConfig;

        await tester.pumpWidget(
          buildTestableWidget(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    resultConfig = await showApiPermissionsDialog(
                      context,
                      initialConfig: const ApiPermissionsConfig(),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Expand Monitors category
        await tester.ensureVisible(
          find.text('Monitors (Brightness, Temp, Offsets)'),
        );
        await tester.tap(find.text('Monitors (Brightness, Temp, Offsets)'));
        await tester.pumpAndSettle();

        // Uncheck set_brightness
        await tester.tap(find.text('Set Brightness'));
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(resultConfig, isNotNull);
        expect(resultConfig!.allowedActions, isNotNull);
        expect(
          resultConfig!.allowedActions!.contains('set_brightness'),
          isFalse,
        );
        expect(
          resultConfig!.allowedActions!.contains('set_temperature'),
          isTrue,
        );
        expect(resultConfig!.allowedActions!.length, equals(24));
      },
    );
  });
}
