import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/screens/sleep_screen.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState customSettings;
  FakeSettingsNotifier(this.customSettings);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': customSettings};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, Object>{};
            }
            return true;
          },
        );
  });

  group('Sleep Analysis Settings Slider & Scroll Stability Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1200,
        2400,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets(
      'SleepScreen renders settings accordion and visible sessions slider',
      (tester) async {
        final fakeNotifier = FakeSettingsNotifier(
          SettingsState(sleepVisibleSessionsCount: 5),
        );
        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(() => fakeNotifier)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('uk'),
              home: Scaffold(body: SleepScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Find the Sleep Analysis Settings section header
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SleepScreen)),
        )!;
        final settingsHeader = find.text(l10n.sleepAnalysisSettings);
        expect(settingsHeader, findsOneWidget);

        // Scroll to it and tap to expand
        await tester.ensureVisible(settingsHeader);
        await tester.tap(settingsHeader);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The visible regime sessions slider should be visible
        final visibleSessionsTitle = find.text(l10n.visibleRegimeSessions);
        expect(visibleSessionsTitle, findsOneWidget);

        // Badge initially displays default 5 sessions
        expect(find.text('5 ${l10n.sessionsCountUnit}'), findsOneWidget);

        // Find the slider
        final sliders = find.byType(Slider);
        expect(sliders, findsWidgets);

        // The last slider is the visible sessions slider
        final visibleSessionsSlider = sliders.last;
        final sliderWidget = tester.widget<Slider>(visibleSessionsSlider);
        expect(sliderWidget.value, 5.0);
        expect(sliderWidget.min, 1.0);
        expect(sliderWidget.max, 50.0);
      },
    );

    testWidgets(
      'Dragging visible sessions slider updates badge locally and commits to state on release',
      (tester) async {
        final fakeNotifier = FakeSettingsNotifier(
          SettingsState(sleepVisibleSessionsCount: 5),
        );
        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(() => fakeNotifier)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('uk'),
              home: Scaffold(body: SleepScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(SleepScreen)),
        )!;
        final settingsHeader = find.text(l10n.sleepAnalysisSettings);
        await tester.ensureVisible(settingsHeader);
        await tester.tap(settingsHeader);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final visibleSessionsSlider = find.byType(Slider).last;
        await tester.ensureVisible(visibleSessionsSlider);

        // Verify initial state is 5
        expect(
          container
              .read(settingsProvider)
              .value?['all']
              ?.sleepVisibleSessionsCount,
          5,
        );

        // Start dragging the slider
        final gesture = await tester.startGesture(
          tester.getCenter(visibleSessionsSlider),
        );
        await tester.pump();

        // Move the slider to the right
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();

        // While dragging, the Riverpod state should STILL be 5 (no jump/rebuild above)
        expect(
          container
              .read(settingsProvider)
              .value?['all']
              ?.sleepVisibleSessionsCount,
          5,
        );

        // Release the drag
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Now after release, Riverpod state must have updated
        final updatedCount = container
            .read(settingsProvider)
            .value?['all']
            ?.sleepVisibleSessionsCount;
        expect(updatedCount, isNotNull);
        expect(updatedCount, isNot(5));
      },
    );
  });
}
