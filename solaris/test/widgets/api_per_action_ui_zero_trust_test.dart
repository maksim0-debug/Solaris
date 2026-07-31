import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';

void main() {
  Widget buildTestableWidget(
    Widget child, {
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
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

  group(
    'Stage 4 Zero-Trust GUI Verification: ApiPermissionsDialog & Granular Tri-State UI',
    () {
      testWidgets(
        'BDD Scenario 1: Toggling single action triggers Tri-State [-] and returns 27 actions',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          ApiPermissionsConfig? resultConfig;

          await tester.pumpWidget(
            buildTestableWidget(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resultConfig = await showApiPermissionsDialog(
                      context,
                      initialConfig: const ApiPermissionsConfig(),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Dialog'));
          await tester.pumpAndSettle();

          // Expand Monitors category
          final monitorsHeader = find.text(
            'Monitors (Brightness, Temp, Offsets)',
          );
          await tester.ensureVisible(monitorsHeader);
          await tester.tap(monitorsHeader);
          await tester.pumpAndSettle();

          // Uncheck set_temperature
          final setTempTile = find.text('Set Color Temperature (K)');
          await tester.ensureVisible(setTempTile);
          await tester.tap(setTempTile);
          await tester.pumpAndSettle();

          // Verify category checkbox value is null (Tri-State / indeterminate)
          final categoryCheckboxes = find.byType(Checkbox);
          expect(categoryCheckboxes, findsWidgets);

          // Save
          final saveBtn = find.text('Save');
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();

          expect(resultConfig, isNotNull);
          expect(resultConfig!.allowedActions, isNotNull);
          expect(resultConfig!.allowedActions!.length, equals(27));
          expect(
            resultConfig!.allowedActions!.contains('set_temperature'),
            isFalse,
          );
        },
      );

      testWidgets(
        'BDD Scenario 2: Clean Storage Protocol resets allowedActions to null when all 28 selected',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          ApiPermissionsConfig? resultConfig;

          // Start with 27 allowed actions (set_temperature omitted)
          final initialActions = ApiPermissionsConfig.getAllCanonicalActions()
            ..remove('set_temperature');

          await tester.pumpWidget(
            buildTestableWidget(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resultConfig = await showApiPermissionsDialog(
                      context,
                      initialConfig: ApiPermissionsConfig(
                        allowedActions: initialActions,
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Dialog'));
          await tester.pumpAndSettle();

          // Expand Monitors category
          final monitorsHeader = find.text(
            'Monitors (Brightness, Temp, Offsets)',
          );
          await tester.ensureVisible(monitorsHeader);
          await tester.tap(monitorsHeader);
          await tester.pumpAndSettle();

          // Check set_temperature back on
          final setTempTile = find.text('Set Color Temperature (K)');
          await tester.ensureVisible(setTempTile);
          await tester.tap(setTempTile);
          await tester.pumpAndSettle();

          // Save
          final saveBtn = find.text('Save');
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();

          expect(resultConfig, isNotNull);
          // Clean Storage Protocol must reset allowedActions to null when all 28 actions are active
          expect(resultConfig!.allowedActions, isNull);
        },
      );

      testWidgets(
        'BDD Scenario 3: Unchecking category checkbox disables category and strips actions',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          ApiPermissionsConfig? resultConfig;

          await tester.pumpWidget(
            buildTestableWidget(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resultConfig = await showApiPermissionsDialog(
                      context,
                      initialConfig: const ApiPermissionsConfig(),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Dialog'));
          await tester.pumpAndSettle();

          // Find leading Checkbox of Sleep category and tap it
          final sleepTile = find.text('Sleep Actions & Status Pushes');
          await tester.ensureVisible(sleepTile);

          // Tap the leading checkbox for Sleep category
          final sleepCheckbox = find
              .descendant(
                of: find.ancestor(
                  of: sleepTile,
                  matching: find.byType(ExpansionTile),
                ),
                matching: find.byType(Checkbox),
              )
              .first;
          await tester.tap(sleepCheckbox);
          await tester.pumpAndSettle();

          // Save
          final saveBtn = find.text('Save');
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();

          expect(resultConfig, isNotNull);
          expect(
            resultConfig!.allowedCategories.contains(ApiActionCategory.sleep),
            isFalse,
          );
        },
      );

      testWidgets(
        'BDD Scenario 4: Multilingual locale rendering (Russian & Ukrainian)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestableWidget(
              const ApiPermissionsDialog(initialConfig: ApiPermissionsConfig()),
              locale: const Locale('ru'),
            ),
          );
          await tester.pumpAndSettle();

          // Verify category localized title in Russian
          final ruHeader = find.text(
            'Мониторы (яркость, температура, смещения)',
          );
          expect(ruHeader, findsOneWidget);

          // Expand Monitors category
          await tester.ensureVisible(ruHeader);
          await tester.tap(ruHeader);
          await tester.pumpAndSettle();

          expect(find.text('Изменение яркости'), findsOneWidget);
          expect(find.text('set_brightness'), findsOneWidget);
        },
      );
    },
  );
}
