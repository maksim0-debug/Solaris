import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/widgets/solar_phase_cards.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/theme/app_theme.dart';
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
              body: SingleChildScrollView(
                child: SolarPhaseCardsWidget(showResetButton: true),
              ),
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
              body: SingleChildScrollView(
                child: SolarPhaseCardsWidget(showResetButton: true),
              ),
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
              body: SingleChildScrollView(
                child: SolarPhaseCardsWidget(showResetButton: true),
              ),
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
              body: SingleChildScrollView(
                child: SolarPhaseCardsWidget(showResetButton: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since only temperature is modified, reset button MUST NOT be visible in brightness mode
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    },
  );

  testWidgets(
    'Phase cards use Solarus style: no glowColor, subtle border, and correct styling',
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

      final glassCards = tester
          .widgetList<GlassCard>(find.byType(GlassCard))
          .toList();
      expect(glassCards.length, equals(4));

      for (final card in glassCards) {
        // Must NOT have glowColor (no color flood)
        expect(card.glowColor, isNull);
        // Must have subtle 1.0 border with non-null borderColor
        expect(card.borderWidth, equals(1.0));
        expect(card.borderColor, isNotNull);
        expect(card.borderRadius, equals(14));
      }
    },
  );

  testWidgets(
    'Tapping value badge opens dialog with Solarus surface background 0xFF0F172A',
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

      // Find first value badge and tap it
      final firstBadge = find.byType(InkWell).first;
      await tester.tap(firstBadge);
      await tester.pumpAndSettle();

      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(alertDialog.backgroundColor, equals(const Color(0xFF0F172A)));

      // Close dialog cleanly to dispose controller and avoid resource leaks
      final cancelButton = find.widgetWithText(TextButton, 'Скасувати');
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Phase cards use unified Solaris monochrome accent for all sliders and badges',
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

      final sliderThemes = tester
          .widgetList<SliderTheme>(find.byType(SliderTheme))
          .toList();
      expect(sliderThemes.length, equals(4));

      for (final theme in sliderThemes) {
        expect(theme.data.activeTrackColor, equals(AppTheme.accent));
      }

      // Check phase icons are present
      expect(find.byIcon(LucideIcons.moon), findsOneWidget);
      expect(find.byIcon(LucideIcons.sunrise), findsOneWidget);
      expect(find.byIcon(LucideIcons.sun), findsOneWidget);
      expect(find.byIcon(LucideIcons.sunset), findsOneWidget);
    },
  );

  group('SolarPhasesConfig domain methods', () {
    test(
      'isModified detects changes accurately for temperature and brightness',
      () {
        final config = SolarPhasesConfig.defaultBalanced;
        expect(config.isModified(isTemp: true), isFalse);
        expect(config.isModified(isTemp: false), isFalse);

        final tempModified = config.copyWith(
          night: config.night.copyWith(temperature: 1800),
        );
        expect(tempModified.isModified(isTemp: true), isTrue);
        expect(tempModified.isModified(isTemp: false), isFalse);

        final brightModified = config.copyWith(
          day: config.day.copyWith(brightness: 80.0),
        );
        expect(brightModified.isModified(isTemp: true), isFalse);
        expect(brightModified.isModified(isTemp: false), isTrue);

        // Verify tiny floating point variations within 0.05 are treated as unmodified
        final epsilonConfig = config.copyWith(
          day: config.day.copyWith(brightness: 100.0001),
        );
        expect(epsilonConfig.isModified(isTemp: false), isFalse);
      },
    );

    test('resetToDefault resets target metric while preserving the other', () {
      final custom = const SolarPhasesConfig(
        night: PhaseTarget(brightness: 10.0, temperature: 1900),
        sunrise: PhaseTarget(brightness: 30.0, temperature: 3500),
        day: PhaseTarget(brightness: 90.0, temperature: 6000),
        sunset: PhaseTarget(brightness: 25.0, temperature: 2800),
      );

      final resetTemp = custom.resetToDefault(isTemp: true);
      expect(
        resetTemp.night.temperature,
        equals(SolarPhasesConfig.defaultBalanced.night.temperature),
      );
      expect(
        resetTemp.sunrise.temperature,
        equals(SolarPhasesConfig.defaultBalanced.sunrise.temperature),
      );
      expect(
        resetTemp.day.temperature,
        equals(SolarPhasesConfig.defaultBalanced.day.temperature),
      );
      expect(
        resetTemp.sunset.temperature,
        equals(SolarPhasesConfig.defaultBalanced.sunset.temperature),
      );
      expect(resetTemp.night.brightness, equals(10.0));
      expect(resetTemp.sunrise.brightness, equals(30.0));
      expect(resetTemp.day.brightness, equals(90.0));
      expect(resetTemp.sunset.brightness, equals(25.0));

      final resetBright = custom.resetToDefault(isTemp: false);
      expect(
        resetBright.night.brightness,
        equals(SolarPhasesConfig.defaultBalanced.night.brightness),
      );
      expect(
        resetBright.sunrise.brightness,
        equals(SolarPhasesConfig.defaultBalanced.sunrise.brightness),
      );
      expect(
        resetBright.day.brightness,
        equals(SolarPhasesConfig.defaultBalanced.day.brightness),
      );
      expect(
        resetBright.sunset.brightness,
        equals(SolarPhasesConfig.defaultBalanced.sunset.brightness),
      );
      expect(resetBright.night.temperature, equals(1900));
      expect(resetBright.sunrise.temperature, equals(3500));
      expect(resetBright.day.temperature, equals(6000));
      expect(resetBright.sunset.temperature, equals(2800));
    });
  });
}
