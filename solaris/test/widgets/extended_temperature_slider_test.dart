import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/widgets/temperature_slider.dart';

class FakeMonitorService extends MonitorService {
  final ExpandedGammaStatus status;
  FakeMonitorService({required this.status});

  @override
  Future<ExpandedGammaStatus> getExpandedGammaStatus() async => status;

  @override
  Future<bool> isExpandedGammaUnlocked() async =>
      status == ExpandedGammaStatus.active;
}

void main() {
  group('TemperatureSlider Pure Linear Mapping Tests (1000K..6500K)', () {
    test('Linear 6500K..1000K mapping over full 0.0..1.0 range', () {
      // 6500K = 0.0 (Daylight Blue)
      expect(TemperatureSlider.valueToProgress(value: 6500.0), equals(0.0));
      // Midpoint: (6500 + 1000) / 2 = 3750K = 0.5
      expect(TemperatureSlider.valueToProgress(value: 3750.0), equals(0.5));
      // 1000K = 1.0 (Candlelight Ember)
      expect(TemperatureSlider.valueToProgress(value: 1000.0), equals(1.0));

      // Inverse
      expect(TemperatureSlider.progressToValue(progress: 0.0), equals(6500.0));
      expect(TemperatureSlider.progressToValue(progress: 0.5), equals(3750.0));
      expect(TemperatureSlider.progressToValue(progress: 1.0), equals(1000.0));
    });

    test('Boundary clamping respects 1000K..6500K native limits', () {
      // Below 1000 clamps to 1000 (progress 1.0)
      expect(TemperatureSlider.valueToProgress(value: 500.0), equals(1.0));
      // Above 6500 clamps to 6500 (progress 0.0)
      expect(TemperatureSlider.valueToProgress(value: 7500.0), equals(0.0));

      // Inverse progress clamping
      expect(TemperatureSlider.progressToValue(progress: -0.2), equals(6500.0));
      expect(TemperatureSlider.progressToValue(progress: 1.2), equals(1000.0));
    });

    test(
      'Color transition smoothly interpolates from Blue to Amber to Ember',
      () {
        final blue = TemperatureSlider.progressToColor(0.0);
        expect(blue, equals(const Color(0xFF60A5FA)));

        final amber = TemperatureSlider.progressToColor(0.58);
        expect(amber, equals(const Color(0xFFFDBA74)));

        final ember = TemperatureSlider.progressToColor(1.0);
        expect(ember, equals(const Color(0xFFEA580C)));
      },
    );
  });

  group('TemperatureSlider Widget Interaction Tests', () {
    testWidgets('Renders properly across various temperatures without badges', (
      tester,
    ) async {
      double latestValue = 6500.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                    width: 400,
                    child: TemperatureSlider(
                      value: latestValue,
                      onChanged: (val) {
                        setState(() {
                          latestValue = val;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(SliderTheme);
      expect(sliderFinder, findsOneWidget);
      expect(find.text('6500K'), findsOneWidget);
    });

    testWidgets(
      'Displays formatted temperature for candle temperature (1500K)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: TemperatureSlider(value: 1500.0, onChanged: (_) {}),
              ),
            ),
          ),
        );

        expect(find.text('1500K'), findsOneWidget);
      },
    );

    testWidgets('Renders ultra-warm temperature at 1000K', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TemperatureSlider(value: 1000.0, onChanged: (_) {}),
            ),
          ),
        ),
      );

      expect(find.text('1000K'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
      'Hides warning and restart icons when expanded gamma is active',
      (tester) async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.active,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
        expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
      },
    );

    testWidgets('Shows warning icon when expanded gamma is disabled', (
      tester,
    ) async {
      final fakeService = FakeMonitorService(
        status: ExpandedGammaStatus.disabled,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
    });

    testWidgets('Shows rotateCcw icon when expanded gamma is pendingRestart', (
      tester,
    ) async {
      final fakeService = FakeMonitorService(
        status: ExpandedGammaStatus.pendingRestart,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TemperatureSlider(value: 2000.0, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
      expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
    });

    testWidgets(
      'Temperature label remains precisely centered regardless of status icons',
      (tester) async {
        final fakeServiceDisabled = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monitorServiceProvider.overrideWithValue(fakeServiceDisabled),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final centerWithIcon = tester.getCenter(find.text('3000K')).dx;

        final fakeServiceActive = FakeMonitorService(
          status: ExpandedGammaStatus.active,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monitorServiceProvider.overrideWithValue(fakeServiceActive),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final centerWithoutIcon = tester.getCenter(find.text('3000K')).dx;

        expect(centerWithIcon, equals(200.0));
        expect(centerWithoutIcon, equals(200.0));
        expect(centerWithIcon, equals(centerWithoutIcon));
      },
    );

    testWidgets(
      'Shows warning icon when disabled regardless of temperature (e.g. at 5000K)',
      (tester) async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TemperatureSlider(value: 5000.0, onChanged: (_) {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
        expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
      },
    );
  });
}
