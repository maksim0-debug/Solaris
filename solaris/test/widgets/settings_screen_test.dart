import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/screens/settings_screen.dart';
import 'package:solaris/widgets/solar_phase_cards.dart';
import 'package:timezone/data/latest.dart' as tz;

class _MockSettingsNotifier extends SettingsNotifier {
  final Map<String, SettingsState> _initialData;
  _MockSettingsNotifier(this._initialData);

  @override
  Future<Map<String, SettingsState>> build() async {
    return _initialData;
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });
  testWidgets('SettingsScreen builds cleanly without duplicate key errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    // Initial pump to build tree and verify no Duplicate key FlutterError is thrown
    await tester.pump();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets(
    'CircadianModeSelector and TypeSelector render in correct order and toggle state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
            home: Scaffold(body: SettingsScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Locate mode selector and metric type selector
      final modeSelector = find.byType(SegmentedButton<CircadianMode>);
      final typeSelector = find.byType(SegmentedButton<bool>);

      expect(modeSelector, findsOneWidget);
      expect(typeSelector, findsOneWidget);

      final modeTop = tester.getTopLeft(modeSelector).dy;
      final typeTop = tester.getTopLeft(typeSelector).dy;

      // Locate phase cards and verify hierarchy: modeSelector -> phaseCards -> typeSelector
      final phaseCards = find.byType(SolarPhaseCardsWidget);
      expect(phaseCards, findsOneWidget);
      final cardsTop = tester.getTopLeft(phaseCards).dy;

      expect(modeTop, lessThan(cardsTop));
      expect(cardsTop, lessThan(typeTop));

      // Verify styling properties on both selectors matching Screen 1
      final modeBtn = tester.widget<SegmentedButton<CircadianMode>>(
        modeSelector,
      );
      final typeBtn = tester.widget<SegmentedButton<bool>>(typeSelector);

      expect(modeBtn.showSelectedIcon, isFalse);
      expect(typeBtn.showSelectedIcon, isTrue);
      expect(modeBtn.style?.side?.resolve({}), isNot(equals(BorderSide.none)));
      expect(typeBtn.style?.side?.resolve({}), isNot(equals(BorderSide.none)));

      // Verify toggling metric between Brightness and Temperature
      await tester.tap(find.text('Temperature'));
      await tester.pump();

      // Verify toggling circadian mode between Solar Phases and Adaptive Curve
      await tester.tap(find.text('Adaptive Curve'));
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'CircadianModeSelector renders cleanly without overflow on narrow width',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({'all': SettingsState()}),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
            home: Scaffold(body: CircadianModeSelector()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<CircadianMode>), findsOneWidget);
    },
  );

  testWidgets(
    'CircadianModeSelector renders reset button below segmented button on narrow width when phases modified',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final modifiedConfig = SolarPhasesConfig.defaultBalanced.copyWith(
        day: SolarPhasesConfig.defaultBalanced.day.copyWith(brightness: 80.0),
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(
                circadianMode: CircadianMode.solarPhases,
                phasesConfig: modifiedConfig,
              ),
            }),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
            home: Scaffold(body: CircadianModeSelector()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<CircadianMode>), findsOneWidget);
      expect(find.byType(SolarPhaseResetButton), findsOneWidget);

      final segmentedBottom = tester
          .getBottomLeft(find.byType(SegmentedButton<CircadianMode>))
          .dy;
      final resetTop = tester.getTopLeft(find.byType(SolarPhaseResetButton)).dy;
      expect(resetTop, greaterThanOrEqualTo(segmentedBottom));
    },
  );

  testWidgets(
    'CircadianModeSelector renders reset button to the right on wide width when phases modified',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final modifiedConfig = SolarPhasesConfig.defaultBalanced.copyWith(
        day: SolarPhasesConfig.defaultBalanced.day.copyWith(brightness: 80.0),
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsNotifier({
              'all': SettingsState(
                circadianMode: CircadianMode.solarPhases,
                phasesConfig: modifiedConfig,
              ),
            }),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ru'), Locale('uk')],
            home: Scaffold(body: CircadianModeSelector()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<CircadianMode>), findsOneWidget);
      expect(find.byType(SolarPhaseResetButton), findsOneWidget);

      final segmentedRight = tester
          .getBottomRight(find.byType(SegmentedButton<CircadianMode>))
          .dx;
      final resetLeft = tester
          .getTopLeft(find.byType(SolarPhaseResetButton))
          .dx;
      expect(resetLeft, greaterThan(segmentedRight));
    },
  );
}
