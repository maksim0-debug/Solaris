import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/settings/api_keys_management_dialog.dart';
import 'package:solaris/widgets/settings/api_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({required SettingsState initialSettings}) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(initialSettings),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
        home: const Scaffold(
          body: SingleChildScrollView(child: ApiSettingsCard()),
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

  group('ApiSettingsCard Phase 3 Multiple Scoped API Keys Widget Tests', () {
    testWidgets('1. Displays active keys count and Manage API Keys button', (
      WidgetTester tester,
    ) async {
      configureLargeScreen(tester);
      final settings = SettingsState(
        isLocalIpcServerEnabled: true,
        apiKeys: [ApiKeyEntry.create(name: 'Default Key')],
      );

      await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
      await tester.pumpAndSettle();

      expect(find.text('1 active key configured'), findsOneWidget);
      expect(find.text('Manage API Keys...'), findsOneWidget);
    });

    testWidgets(
      '2. Displays requireLocalToken toggle and allows updating setting',
      (WidgetTester tester) async {
        configureLargeScreen(tester);
        final settings = SettingsState(
          isLocalIpcServerEnabled: true,
          requireLocalToken: false,
        );

        await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
        await tester.pumpAndSettle();

        expect(
          find.text('Require Authentication for Local Requests'),
          findsOneWidget,
        );

        final switches = find.byType(Switch);
        expect(
          switches,
          findsNWidgets(2),
        ); // Server enable switch & Require local token switch

        // Tap requireLocalToken switch
        await tester.tap(switches.last);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '3. Tapping Manage API Keys button opens ApiKeysManagementDialog',
      (WidgetTester tester) async {
        configureLargeScreen(tester);
        final settings = SettingsState(isLocalIpcServerEnabled: true);

        await tester.pumpWidget(buildTestableWidget(initialSettings: settings));
        await tester.pumpAndSettle();

        final manageBtn = find.text('Manage API Keys...');
        expect(manageBtn, findsOneWidget);

        await tester.tap(manageBtn);
        await tester.pumpAndSettle();

        // Verify ApiKeysManagementDialog is displayed
        expect(find.byType(ApiKeysManagementDialog), findsOneWidget);
        expect(
          find.text('API Access Keys Management'),
          findsAtLeastNWidgets(2),
        );
      },
    );
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
  void updateRequireLocalToken(bool value) {
    _currentSettings = _currentSettings.copyWith(requireLocalToken: value);
    state = AsyncData({'all': _currentSettings});
  }
}
