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
    required SettingsState initialSettings,
  }) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => TestSettingsNotifier(initialSettings)),
      ],
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
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('ApiSettingsCard Granular Security Section Zero-Trust Widget Tests', () {
    testWidgets('1. Displays Read-Only red summary status badge when isReadOnly is true', (WidgetTester tester) async {
      configureLargeScreen(tester);
      final settings = SettingsState(
        isLocalIpcServerEnabled: true,
        apiPermissions: const ApiPermissionsConfig(isReadOnly: true),
      );

      await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
      await tester.pumpAndSettle();

      // Verify status text in red
      expect(find.text('Read-Only Mode Active'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Configure API Permissions...'), findsOneWidget);

      final statusText = tester.widget<Text>(find.text('Read-Only Mode Active'));
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

      await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
      await tester.pumpAndSettle();

      // Verify status text in green with pluralization 3
      expect(find.text('3 categories allowed'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Configure API Permissions...'), findsOneWidget);

      final statusText = tester.widget<Text>(find.text('3 categories allowed'));
      expect(statusText.style?.color, equals(const Color(0xFF4ADE80)));
    });

    testWidgets('3. Tapping Configure Permissions button opens ApiPermissionsDialog', (WidgetTester tester) async {
      configureLargeScreen(tester);
      final settings = SettingsState(isLocalIpcServerEnabled: true);

      await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
      await tester.pumpAndSettle();

      final configureBtn = find.widgetWithText(OutlinedButton, 'Configure API Permissions...');
      expect(configureBtn, findsOneWidget);

      await tester.tap(configureBtn);
      await tester.pumpAndSettle();

      // Verify ApiPermissionsDialog is displayed
      expect(find.byType(ApiPermissionsDialog), findsOneWidget);
      expect(find.text('API Permissions & Access Control'), findsAtLeastNWidgets(1));
    });

    testWidgets('4. Dynamic GUI reactivity: updating permissions in dialog immediately updates ApiSettingsCard status badge', (WidgetTester tester) async {
      configureLargeScreen(tester);
      final settings = SettingsState(isLocalIpcServerEnabled: true);

      await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
      await tester.pumpAndSettle();

      expect(find.text('7 categories allowed'), findsOneWidget);

      // Open Dialog
      final configureBtn = find.widgetWithText(OutlinedButton, 'Configure API Permissions...');
      await tester.tap(configureBtn);
      await tester.pumpAndSettle();

      // Enable Read-Only switch inside dialog
      final readOnlySwitch = find.descendant(
        of: find.byType(ApiPermissionsDialog),
        matching: find.byType(Switch),
      ).first;

      await tester.tap(readOnlySwitch);
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify ApiSettingsCard now displays Read-Only badge!
      expect(find.text('Read-Only Mode Active'), findsOneWidget);
      expect(find.text('7 categories allowed'), findsNothing);
    });
  });
}

class TestSettingsNotifier extends SettingsNotifier {
  SettingsState _currentSettings;
  TestSettingsNotifier(SettingsState initial)
      : _currentSettings = initial.copyWith(isLocalIpcServerEnabled: true);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': _currentSettings};
  }

  @override
  Future<void> updateApiPermissions(ApiPermissionsConfig permissions) async {
    _currentSettings = _currentSettings.copyWith(
      isLocalIpcServerEnabled: true,
      apiPermissions: permissions,
    );
    state = AsyncData({'all': _currentSettings});
  }
}
