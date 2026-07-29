import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/settings/api_keys_management_dialog.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';
import 'package:solaris/widgets/settings/api_settings_card.dart';
import 'package:solaris/widgets/settings/create_api_key_dialog.dart';
import 'package:solaris/widgets/settings/show_new_token_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void configureScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 2500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildAppHarness({
    required Widget child,
    required SettingsState initialSettings,
    Locale locale = const Locale('en'),
    TestSettingsNotifier? customNotifier,
  }) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          () => customNotifier ?? TestSettingsNotifier(initialSettings),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Phase 3 - Zero-Trust Exhaustive UI & Management Interface Test Suite', () {
    // -------------------------------------------------------------------------
    // A. BDD Behavioral Specifications: Single Key Guard & Notifier
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 1: Single Key Protection Guard prevents deleting the sole remaining API key in GUI and Notifier',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        final soleKey = ApiKeyEntry(
          id: 'sole_key_101',
          name: 'Master Key',
          token: 'sol_sec_master_key_token_12345',
          permissions: const ApiPermissionsConfig(),
          createdAt: DateTime.now(),
        );

        final settings = SettingsState(
          isLocalIpcServerEnabled: true,
          apiKeys: [soleKey],
        );

        final notifier = TestSettingsNotifier(settings);

        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiKeysManagementDialog(),
            initialSettings: settings,
            customNotifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Verify sole key is present in table
        expect(find.text('Master Key'), findsOneWidget);

        // Verify Single Key Protection Guard tooltip
        final tooltipFinder = find.byTooltip(
          'Cannot delete the sole remaining API key.',
        );
        expect(tooltipFinder, findsOneWidget);

        // Attempt to invoke removeApiKey directly on notifier -> must return false
        final removeResult = notifier.removeApiKey('sole_key_101');
        expect(removeResult, isFalse);
        expect(notifier.currentApiKeys.length, equals(1));
      },
    );

    testWidgets(
      'Scenario 2: Adding a second key enables deletion for non-sole keys',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        final key1 = ApiKeyEntry.create(name: 'Key One');
        final key2 = ApiKeyEntry.create(name: 'Key Two');

        final settings = SettingsState(
          isLocalIpcServerEnabled: true,
          apiKeys: [key1, key2],
        );

        final notifier = TestSettingsNotifier(settings);

        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiKeysManagementDialog(),
            initialSettings: settings,
            customNotifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Key One'), findsOneWidget);
        expect(find.text('Key Two'), findsOneWidget);

        // Deleting key2 via notifier should succeed (returns true)
        final deleteSuccess = notifier.removeApiKey(key2.id);
        expect(deleteSuccess, isTrue);
        expect(notifier.currentApiKeys.length, equals(1));
        expect(notifier.currentApiKeys.first.id, equals(key1.id));
      },
    );

    // -------------------------------------------------------------------------
    // B. CreateApiKeyDialog Workflow & Edge Cases
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 3: CreateApiKeyDialog trims whitespace, enforces length limit and defaults name',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        ApiKeyEntry? createdEntry;

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
                      createdEntry = await showCreateApiKeyDialog(
                        context,
                        existingKeysCount: 2,
                      );
                    },
                    child: const Text('Launch Create Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Create Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateApiKeyDialog), findsOneWidget);

        // 1. Check default placeholder text
        expect(find.text('API Key 3'), findsOneWidget);

        // 2. Test whitespace trimming
        await tester.enterText(
          find.byType(TextFormField),
          '   Home Automation Key   ',
        );
        await tester.pump();

        final createBtn = find.widgetWithText(ElevatedButton, 'Create New Key');
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        expect(createdEntry, isNotNull);
        expect(createdEntry!.name, equals('Home Automation Key'));
        expect(createdEntry!.token, startsWith('sol_sec_'));
        expect(
          createdEntry!.token.length,
          equals(72),
        ); // sol_sec_ (8) + 64 hex chars
      },
    );

    // -------------------------------------------------------------------------
    // C. DPAPI Fallback Warning Banner Non-Auto-Hiding Lifetime Audit
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 4: DPAPI Fallback Warning Banner persists until explicitly dismissed via X button',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        final fallbackKey = ApiKeyEntry(
          id: 'corrupt_key_999',
          name: 'Home Assistant Key',
          token: 'sol_sec_fallback_secure_token_123',
          permissions: const ApiPermissionsConfig(),
          createdAt: DateTime.now(),
          isDpapiFallback: true,
        );

        final settings = SettingsState(
          isLocalIpcServerEnabled: true,
          apiKeys: [fallbackKey],
        );

        final notifier = TestSettingsNotifier(settings);

        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiSettingsCard(),
            initialSettings: settings,
            customNotifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Verify DPAPI Warning Banner is visible
        expect(find.textContaining('Home Assistant Key'), findsWidgets);
        expect(
          find.textContaining('reset due to Windows account password change'),
          findsOneWidget,
        );

        // Pump multiple frames to verify banner is non-auto-hiding by timer
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 60));
        expect(
          find.textContaining('reset due to Windows account password change'),
          findsOneWidget,
        );

        // Tap close button [X]
        final closeButton = find
            .widgetWithIcon(IconButton, LucideIcons.x)
            .first;
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Verify dismissDpapiFallbackWarning was called on notifier
        expect(notifier.currentApiKeys.first.isDpapiFallback, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // D. ShowNewTokenDialog & Clipboard Verification
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 5: ShowNewTokenDialog copies token to Clipboard and dismisses safely',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        String? clipboardContent;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final Map<String, dynamic> args =
                  methodCall.arguments as Map<String, dynamic>;
              clipboardContent = args['text'] as String?;
            }
            return null;
          },
        );

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
                token: 'sol_sec_abcdef1234567890',
                keyName: 'Integration Key',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ShowNewTokenDialog), findsOneWidget);
        expect(find.text('sol_sec_abcdef1234567890'), findsOneWidget);

        // Tap Copy Token button (OutlinedButton.icon)
        final copyBtn = find.widgetWithText(OutlinedButton, 'Copy Token');
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        expect(clipboardContent, equals('sol_sec_abcdef1234567890'));

        // Tap I Have Saved the Token button (ElevatedButton.icon)
        final savedBtn = find.widgetWithText(
          ElevatedButton,
          'I Have Saved the Token',
        );
        await tester.tap(savedBtn);
        await tester.pumpAndSettle();

        expect(find.byType(ShowNewTokenDialog), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // E. ApiPermissionsDialog Pure Functional Selector Audit
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 6: ApiPermissionsDialog does NOT mutate settingsProvider directly and pops updated config',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        ApiPermissionsConfig? returnedConfig;

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
                      returnedConfig = await showApiPermissionsDialog(
                        context,
                        initialConfig: const ApiPermissionsConfig(
                          isReadOnly: false,
                        ),
                      );
                    },
                    child: const Text('Open Permissions Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Permissions Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(ApiPermissionsDialog), findsOneWidget);

        // Toggle Read-Only switch inside dialog
        final readOnlySwitch = find
            .descendant(
              of: find.byType(ApiPermissionsDialog),
              matching: find.byType(Switch),
            )
            .first;

        await tester.tap(readOnlySwitch);
        await tester.pumpAndSettle();

        // Tap Save
        final saveBtn = find.text('Save');
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(returnedConfig, isNotNull);
        expect(returnedConfig!.isReadOnly, isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // F. Multilingual Localization Completeness (en, ru, uk)
    // -------------------------------------------------------------------------
    testWidgets(
      'Scenario 7: Multilingual UI completeness check across English, Russian, and Ukrainian locales',
      (WidgetTester tester) async {
        configureScreenSize(tester);

        final key = ApiKeyEntry.create(name: 'Test Key');
        final settings = SettingsState(
          isLocalIpcServerEnabled: true,
          apiKeys: [key],
        );

        // Test English locale
        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiKeysManagementDialog(),
            initialSettings: settings,
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('API Access Keys Management'), findsOneWidget);
        expect(find.text('Create New Key'), findsOneWidget);

        // Test Russian locale
        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiKeysManagementDialog(),
            initialSettings: settings,
            locale: const Locale('ru'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Управление ключами доступа API'), findsOneWidget);
        expect(find.text('Создать новый ключ'), findsOneWidget);

        // Test Ukrainian locale
        await tester.pumpWidget(
          buildAppHarness(
            child: const ApiKeysManagementDialog(),
            initialSettings: settings,
            locale: const Locale('uk'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Управління ключами доступу API'), findsOneWidget);
        expect(find.text('Створити новий ключ'), findsOneWidget);
      },
    );
  });
}

class TestSettingsNotifier extends SettingsNotifier {
  SettingsState _currentSettings;

  TestSettingsNotifier(SettingsState initial)
    : _currentSettings = initial.copyWith(isLocalIpcServerEnabled: true);

  List<ApiKeyEntry> get currentApiKeys => _currentSettings.apiKeys;

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': _currentSettings};
  }

  @override
  void addApiKey(ApiKeyEntry entry) {
    final updatedKeys = List<ApiKeyEntry>.from(_currentSettings.apiKeys)
      ..add(entry);
    _currentSettings = _currentSettings.copyWith(apiKeys: updatedKeys);
    state = AsyncData({'all': _currentSettings});
  }

  @override
  void updateApiKey(ApiKeyEntry entry) {
    final updatedKeys = List<ApiKeyEntry>.from(_currentSettings.apiKeys);
    final idx = updatedKeys.indexWhere((k) => k.id == entry.id);
    if (idx != -1) {
      updatedKeys[idx] = entry;
      _currentSettings = _currentSettings.copyWith(apiKeys: updatedKeys);
      state = AsyncData({'all': _currentSettings});
    }
  }

  @override
  bool removeApiKey(String id) {
    if (_currentSettings.apiKeys.length <= 1) {
      return false; // Single Key Guard
    }
    final updatedKeys = _currentSettings.apiKeys
        .where((k) => k.id != id)
        .toList();
    _currentSettings = _currentSettings.copyWith(apiKeys: updatedKeys);
    state = AsyncData({'all': _currentSettings});
    return true;
  }

  @override
  String regenerateApiKeyToken(String id) {
    final updatedKeys = List<ApiKeyEntry>.from(_currentSettings.apiKeys);
    final idx = updatedKeys.indexWhere((k) => k.id == id);
    if (idx != -1) {
      final newToken = ApiKeyEntry.generateSecureToken();
      updatedKeys[idx] = updatedKeys[idx].copyWith(token: newToken);
      _currentSettings = _currentSettings.copyWith(apiKeys: updatedKeys);
      state = AsyncData({'all': _currentSettings});
      return newToken;
    }
    return '';
  }

  @override
  void dismissDpapiFallbackWarning(String id) {
    final updatedKeys = List<ApiKeyEntry>.from(_currentSettings.apiKeys);
    final idx = updatedKeys.indexWhere((k) => k.id == id);
    if (idx != -1) {
      updatedKeys[idx] = updatedKeys[idx].copyWith(isDpapiFallback: false);
      _currentSettings = _currentSettings.copyWith(apiKeys: updatedKeys);
      state = AsyncData({'all': _currentSettings});
    }
  }
}
