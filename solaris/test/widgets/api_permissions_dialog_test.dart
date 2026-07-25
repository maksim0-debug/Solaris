import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
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
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  void configureLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('ApiPermissionsDialog Widget Exhaustive Zero-Trust Test Suite', () {
    testWidgets('1. Renders all section titles, switches, and action category checkboxes', (WidgetTester tester) async {
      configureLargeScreen(tester);
      const config = ApiPermissionsConfig();

      await tester.pumpWidget(
        buildTestableWidget(
          const ApiPermissionsDialog(initialConfig: config),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dialog header title & close button
      expect(find.text('API Permissions & Access Control'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing); // Uses Lucide x icon

      // Verify Read-Only switch and section titles
      expect(find.text('Read-Only Mode'), findsOneWidget);
      expect(find.text('Data Sharing Permissions (Read Operations)'), findsOneWidget);
      expect(find.text('Action Control Categories (Mutations)'), findsOneWidget);

      // Verify data sharing switches
      expect(find.text('Monitors & Brightness State'), findsOneWidget);
      expect(find.text('Solar & Astronomical Data'), findsOneWidget);
      expect(find.text('Weather Adjustments & Provider Info'), findsOneWidget);
      expect(find.text('Sleep & Circadian Rhythm Metrics'), findsOneWidget);
      expect(find.text('Smart Circadian System State'), findsOneWidget);

      // Verify action category checkboxes
      expect(find.text('Monitors (Brightness, Temp, Offsets)'), findsOneWidget);
      expect(find.text('Presets & Brightness Profiles'), findsOneWidget);
      expect(find.text('Circadian Rhythm & Auto-Adjustments'), findsOneWidget);
      expect(find.text('Game Mode & App Whitelists'), findsOneWidget);
      expect(find.text('Environment & Weather Adjustments'), findsOneWidget);
      expect(find.text('Sleep Actions & Status Pushes'), findsOneWidget);
      expect(find.text('System Actions (Webhooks, Animations)'), findsOneWidget);
    });

    testWidgets('2. Toggling Read-Only mode disables and re-enables category checkboxes dynamically', (WidgetTester tester) async {
      configureLargeScreen(tester);
      const config = ApiPermissionsConfig(isReadOnly: false);

      await tester.pumpWidget(
        buildTestableWidget(
          const ApiPermissionsDialog(initialConfig: config),
        ),
      );
      await tester.pumpAndSettle();

      final readOnlySwitch = find.byType(Switch).first;
      expect(tester.widget<Switch>(readOnlySwitch).value, isFalse);

      // Category checkbox should initially be enabled
      var checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Monitors (Brightness, Temp, Offsets)'),
      );
      expect(checkbox.enabled, isTrue);

      // Toggle Read-Only to true
      await tester.tap(readOnlySwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(readOnlySwitch).value, isTrue);

      // Checkbox is now disabled
      checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Monitors (Brightness, Temp, Offsets)'),
      );
      expect(checkbox.enabled, isFalse);

      // Toggle Read-Only back to false
      await tester.tap(readOnlySwitch);
      await tester.pumpAndSettle();

      checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Monitors (Brightness, Temp, Offsets)'),
      );
      expect(checkbox.enabled, isTrue);
    });

    testWidgets('3. Toggling data sharing switches updates corresponding flags in ApiPermissionsConfig on Save', (WidgetTester tester) async {
      configureLargeScreen(tester);
      const config = ApiPermissionsConfig(
        allowReadMonitors: true,
        allowReadSolar: true,
        allowReadWeather: true,
        allowReadSleep: true,
        allowReadCircadian: true,
      );
      ApiPermissionsConfig? result;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showApiPermissionsDialog(
                    context,
                    initialConfig: config,
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

      // Toggle off Weather & Sleep switches
      final weatherSwitch = find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Weather Adjustments & Provider Info'),
        matching: find.byType(Switch),
      );
      final sleepSwitch = find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Sleep & Circadian Rhythm Metrics'),
        matching: find.byType(Switch),
      );

      await tester.tap(weatherSwitch);
      await tester.tap(sleepSwitch);
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.allowReadMonitors, isTrue);
      expect(result!.allowReadSolar, isTrue);
      expect(result!.allowReadWeather, isFalse);
      expect(result!.allowReadSleep, isFalse);
      expect(result!.allowReadCircadian, isTrue);
    });

    testWidgets('4. Toggling individual action categories updates allowedCategories set correctly on Save', (WidgetTester tester) async {
      configureLargeScreen(tester);
      const config = ApiPermissionsConfig(
        allowedCategories: {
          ApiActionCategory.monitors,
          ApiActionCategory.presets,
          ApiActionCategory.circadian,
          ApiActionCategory.gaming,
          ApiActionCategory.environment,
          ApiActionCategory.sleep,
          ApiActionCategory.system,
        },
      );
      ApiPermissionsConfig? result;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showApiPermissionsDialog(
                    context,
                    initialConfig: config,
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

      // Uncheck Gaming & System checkboxes
      final gamingTile = find.widgetWithText(CheckboxListTile, 'Game Mode & App Whitelists');
      final systemTile = find.widgetWithText(CheckboxListTile, 'System Actions (Webhooks, Animations)');

      await tester.tap(gamingTile);
      await tester.tap(systemTile);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.allowedCategories.contains(ApiActionCategory.monitors), isTrue);
      expect(result!.allowedCategories.contains(ApiActionCategory.presets), isTrue);
      expect(result!.allowedCategories.contains(ApiActionCategory.gaming), isFalse);
      expect(result!.allowedCategories.contains(ApiActionCategory.system), isFalse);
      expect(result!.allowedCategories.length, equals(5));
    });

    testWidgets('5. Tapping Cancel or Close button pops dialog without returning updated config (returns null)', (WidgetTester tester) async {
      configureLargeScreen(tester);
      const config = ApiPermissionsConfig();
      ApiPermissionsConfig? result = const ApiPermissionsConfig(isReadOnly: true); // Sentinel non-null

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showApiPermissionsDialog(
                    context,
                    initialConfig: config,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test Cancel button
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Toggle something
      final readOnlySwitch = find.byType(Switch).first;
      await tester.tap(readOnlySwitch);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
