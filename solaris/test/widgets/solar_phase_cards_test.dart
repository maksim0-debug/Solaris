import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/solar_phase_cards.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _MockSettingsNotifier extends SettingsNotifier {
  final Map<String, SettingsState> _initialData;
  _MockSettingsNotifier(this._initialData);

  @override
  Future<Map<String, SettingsState>> build() async {
    return _initialData;
  }
}

void main() {
  testWidgets(
    'SolarPhaseCardsWidget does not show reset button when config is defaultBalanced',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(
                phasesConfig: SolarPhasesConfig.defaultBalanced,
              ),
            }),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('uk'),
            home: Scaffold(
              body: SingleChildScrollView(child: SolarPhaseCardsWidget()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    },
  );

  testWidgets(
    'In brightness mode, reset button only appears for brightness changes and only resets brightness',
    (WidgetTester tester) async {
      // Custom brightness AND custom temperature
      final customConfig = SolarPhasesConfig(
        night: const PhaseTarget(brightness: 5.0, temperature: 1800),
        sunrise: SolarPhasesConfig.defaultBalanced.sunrise,
        day: const PhaseTarget(brightness: 75.0, temperature: 5500),
        sunset: SolarPhasesConfig.defaultBalanced.sunset,
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(phasesConfig: customConfig),
            }),
          ),
        ],
      );

      // Default editingTemperatureProvider is false (brightness mode)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('uk'),
            home: Scaffold(
              body: SingleChildScrollView(child: SolarPhaseCardsWidget()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reset button should be visible in brightness mode because brightness was changed
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

      // Tap reset button
      await tester.tap(find.byIcon(LucideIcons.rotateCcw));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final updatedSettings = container.read(settingsProvider).value?['all'];
      final updatedConfig = updatedSettings?.phasesConfig;

      // Brightness MUST be reset to defaultBalanced
      expect(
        updatedConfig?.night.brightness,
        equals(SolarPhasesConfig.defaultBalanced.night.brightness),
      );
      expect(
        updatedConfig?.day.brightness,
        equals(SolarPhasesConfig.defaultBalanced.day.brightness),
      );

      // Temperature MUST NOT be reset - custom temperature preserved!
      expect(updatedConfig?.night.temperature, equals(1800));
      expect(updatedConfig?.day.temperature, equals(5500));
    },
  );

  testWidgets(
    'In temperature mode, reset button only appears for temperature changes and only resets temperature',
    (WidgetTester tester) async {
      // Custom brightness AND custom temperature
      final customConfig = SolarPhasesConfig(
        night: const PhaseTarget(brightness: 5.0, temperature: 1800),
        sunrise: SolarPhasesConfig.defaultBalanced.sunrise,
        day: const PhaseTarget(brightness: 75.0, temperature: 5500),
        sunset: SolarPhasesConfig.defaultBalanced.sunset,
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(phasesConfig: customConfig),
            }),
          ),
        ],
      );

      // Set mode to temperature
      container.read(editingTemperatureProvider.notifier).set(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('uk'),
            home: Scaffold(
              body: SingleChildScrollView(child: SolarPhaseCardsWidget()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reset button should be visible in temperature mode
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);

      // Tap reset button
      await tester.tap(find.byIcon(LucideIcons.rotateCcw));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final updatedSettings = container.read(settingsProvider).value?['all'];
      final updatedConfig = updatedSettings?.phasesConfig;

      // Temperature MUST be reset to defaultBalanced
      expect(
        updatedConfig?.night.temperature,
        equals(SolarPhasesConfig.defaultBalanced.night.temperature),
      );
      expect(
        updatedConfig?.day.temperature,
        equals(SolarPhasesConfig.defaultBalanced.day.temperature),
      );

      // Brightness MUST NOT be reset - custom brightness preserved!
      expect(updatedConfig?.night.brightness, equals(5.0));
      expect(updatedConfig?.day.brightness, equals(75.0));
    },
  );

  testWidgets(
    'Reset button is hidden in brightness mode if only temperature is modified',
    (WidgetTester tester) async {
      final configOnlyTempModified = SolarPhasesConfig(
        night: const PhaseTarget(brightness: 15.0, temperature: 1700),
        sunrise: SolarPhasesConfig.defaultBalanced.sunrise,
        day: SolarPhasesConfig.defaultBalanced.day,
        sunset: SolarPhasesConfig.defaultBalanced.sunset,
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(phasesConfig: configOnlyTempModified),
            }),
          ),
        ],
      );

      // Brightness mode
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('uk'),
            home: Scaffold(
              body: SingleChildScrollView(child: SolarPhaseCardsWidget()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since only temperature is modified, reset button MUST NOT be visible in brightness mode
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    },
  );
}
