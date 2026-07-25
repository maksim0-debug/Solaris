import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';
import 'package:solaris/widgets/settings/api_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
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
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ApiSettingsCard(),
          ),
        ),
      ),
    );
  }

  void configureLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('ApiSettingsCard Granular Security Section Zero-Trust Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('1. Displays Read-Only red summary status badge when isReadOnly is true', (WidgetTester tester) async {
      configureLargeScreen(tester);
      final settings = SettingsState(
        isLocalIpcServerEnabled: true,
        apiPermissions: const ApiPermissionsConfig(isReadOnly: true),
      );

      await container.read(settingsProvider.future);
      container.read(settingsProvider.notifier).updateApiPermissions(settings.apiPermissions);

      await tester.pumpWidget(buildTestableWidget(container: container));
      await tester.pumpAndSettle();

      // Verify status text in red
      expect(find.text('Read-Only mode active'), findsOneWidget);
      expect(find.text('Configure Permissions...'), findsOneWidget);

      final statusText = tester.widget<Text>(find.text('Read-Only mode active'));
      expect(statusText.style?.color, equals(const Color(0xFFEF4444)));
    });

    testWidgets('2. Displays Custom Allowed Categories green summary status badge when isReadOnly is false', (WidgetTester tester) async {
      configureLargeScreen(tester);
      final settings = SettingsState(
        isLocalIpcServerEnabled: true,
        apiPermissions: const ApiPermissionsConfig(
          isReadOnly: false,
          allowedCategories: {
            ApiActionCategory.monitors,
            ApiActionCategory.presets,
            ApiActionCategory.circadian,
          },
        ),
      );

      await container.read(settingsProvider.future);
      container.read(settingsProvider.notifier).updateApiPermissions(settings.apiPermissions);

      await tester.pumpWidget(buildTestableWidget(container: container));
      await tester.pumpAndSettle();

      // Verify status text in green with pluralization 3
      expect(find.text('Allowed categories: 3'), findsOneWidget);
      expect(find.text('Configure Permissions...'), findsOneWidget);

      final statusText = tester.widget<Text>(find.text('Allowed categories: 3'));
      expect(statusText.style?.color, equals(const Color(0xFF4ADE80)));
    });

    testWidgets('3. Tapping Configure Permissions button opens ApiPermissionsDialog', (WidgetTester tester) async {
      configureLargeScreen(tester);
      await container.read(settingsProvider.future);

      await tester.pumpWidget(buildTestableWidget(container: container));
      await tester.pumpAndSettle();

      final configureBtn = find.widgetWithText(OutlinedButton, 'Configure Permissions...');
      expect(configureBtn, findsOneWidget);

      await tester.tap(configureBtn);
      await tester.pumpAndSettle();

      // Verify ApiPermissionsDialog is displayed
      expect(find.byType(ApiPermissionsDialog), findsOneWidget);
      expect(find.text('API Permissions & Access Control'), findsOneWidget);
    });

    testWidgets('4. Dynamic GUI reactivity: updating permissions in dialog immediately updates ApiSettingsCard status badge', (WidgetTester tester) async {
      configureLargeScreen(tester);
      await container.read(settingsProvider.future);

      await tester.pumpWidget(buildTestableWidget(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Allowed categories: 7'), findsOneWidget);

      // Open Dialog
      await tester.tap(find.widgetWithText(OutlinedButton, 'Configure Permissions...'));
      await tester.pumpAndSettle();

      // Enable Read-Only switch inside dialog
      final readOnlySwitch = find.byType(Switch).first;
      await tester.tap(readOnlySwitch);
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify ApiSettingsCard now displays Read-Only badge!
      expect(find.text('Read-Only mode active'), findsOneWidget);
      expect(find.text('Allowed categories: 7'), findsNothing);
    });
  });
}
