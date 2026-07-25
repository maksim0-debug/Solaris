import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/settings/api_keys_management_dialog.dart';
import 'package:solaris/widgets/settings/api_settings_card.dart';
import 'package:solaris/widgets/settings/create_api_key_dialog.dart';
import 'package:solaris/widgets/settings/show_new_token_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 3 UI & Management Interface Widget Tests', () {
    testWidgets('CreateApiKeyDialog renders and submits new ApiKeyEntry', (WidgetTester tester) async {
      ApiKeyEntry? result;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await showCreateApiKeyDialog(context, existingKeysCount: 1);
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateApiKeyDialog), findsOneWidget);
      expect(find.text('API Key 2'), findsOneWidget);

      // Enter custom key name
      await tester.enterText(find.byType(TextFormField), 'Home Assistant Key');
      await tester.pump();

      // Tap Create button
      final createBtn = find.widgetWithText(ElevatedButton, 'Create New Key');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, equals('Home Assistant Key'));
      expect(result!.token, startsWith('sol_sec_'));
    });

    testWidgets('ShowNewTokenDialog displays token and dismisses on confirmation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ShowNewTokenDialog(
              token: 'sol_sec_test_token_12345',
              keyName: 'Test Key',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ShowNewTokenDialog), findsOneWidget);
      expect(find.text('sol_sec_test_token_12345'), findsOneWidget);

      // Click "Saved" button
      await tester.tap(find.text('I Have Saved the Token'));
      await tester.pumpAndSettle();

      expect(find.byType(ShowNewTokenDialog), findsNothing);
    });

    testWidgets('ApiKeysManagementDialog single key guard prevents deleting sole key', (WidgetTester tester) async {
      final defaultKey = ApiKeyEntry(
        id: 'sole_key_1',
        name: 'Primary Key',
        token: 'sol_sec_sole_token',
        permissions: const ApiPermissionsConfig(),
        createdAt: DateTime.now(),
      );

      final initialSettings = SettingsState(apiKeys: [defaultKey]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => SettingsNotifierFake(initialSettings)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ApiKeysManagementDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ApiKeysManagementDialog), findsOneWidget);
      expect(find.text('Primary Key'), findsOneWidget);

      // Verify single key protection tooltip
      final tooltipFinder = find.byTooltip('Cannot delete the sole remaining API key.');
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('ApiSettingsCard renders DPAPI fallback banner and dismisses it', (WidgetTester tester) async {
      final fallbackKey = ApiKeyEntry(
        id: 'dpapi_key_1',
        name: 'Fallback Key',
        token: 'sol_sec_fallback',
        permissions: const ApiPermissionsConfig(),
        createdAt: DateTime.now(),
        isDpapiFallback: true,
      );

      final initialSettings = SettingsState(
        isLocalIpcServerEnabled: true,
        apiKeys: [fallbackKey],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => SettingsNotifierFake(initialSettings)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ApiSettingsCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Fallback Key'), findsWidgets);
      expect(find.textContaining('reset due to Windows account password change'), findsOneWidget);

      // Dismiss DPAPI warning banner by tapping X icon
      final closeButton = find.widgetWithIcon(IconButton, LucideIcons.x).first;
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
    });
  });
}

class SettingsNotifierFake extends SettingsNotifier {
  final SettingsState _initial;

  SettingsNotifierFake(this._initial);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': _initial};
  }

  @override
  void dismissDpapiFallbackWarning(String id) {
    final stateVal = state.value?['all'] ?? _initial;
    final keys = List<ApiKeyEntry>.from(stateVal.apiKeys);
    final idx = keys.indexWhere((k) => k.id == id);
    if (idx != -1) {
      keys[idx] = keys[idx].copyWith(isDpapiFallback: false);
      state = AsyncData({'all': stateVal.copyWith(apiKeys: keys)});
    }
  }
}
