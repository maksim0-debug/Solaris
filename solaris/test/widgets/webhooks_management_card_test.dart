import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/webhook_service.dart';
import 'package:solaris/widgets/settings/webhooks_management_card.dart';

class _MockSettingsNotifier extends SettingsNotifier {
  final Map<String, SettingsState> _initialData;
  _MockSettingsNotifier(this._initialData);

  @override
  Future<Map<String, SettingsState>> build() async {
    return _initialData;
  }
}

class _MockWebhookService extends WebhookService {
  @override
  WebhookServiceState build() {
    return const WebhookServiceState();
  }
}

void main() {
  group('WebhooksManagementCard Dialog Tests', () {
    testWidgets(
      'Clicking Add Webhook button opens dialog without ListTile background color FlutterError',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => _MockSettingsNotifier({'all': SettingsState()}),
            ),
            webhookServiceProvider.overrideWith(() => _MockWebhookService()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('ru'),
              home: Scaffold(
                body: SingleChildScrollView(child: WebhooksManagementCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addButton = find.text('Добавить вебхук');
        expect(addButton, findsOneWidget);

        await tester.tap(addButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsWidgets);
        expect(find.text('on_sunrise'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'Clicking Edit Webhook button opens dialog without ListTile background color FlutterError',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingWebhook = WebhookConfig(
          id: 'test-wh-1',
          name: 'Home Assistant Webhook',
          url: 'https://homeassistant.local:8123/api/webhook/solaris',
          events: {WebhookEventType.onSunrise, WebhookEventType.onSunset},
        );

        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => _MockSettingsNotifier({
                'all': SettingsState(webhooks: [existingWebhook]),
              }),
            ),
            webhookServiceProvider.overrideWith(() => _MockWebhookService()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('ru'),
              home: Scaffold(
                body: SingleChildScrollView(child: WebhooksManagementCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Home Assistant Webhook'), findsOneWidget);
        final editButton = find.byIcon(LucideIcons.edit2);
        expect(editButton, findsOneWidget);

        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsWidgets);

        // Cancel dialog
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });
}
