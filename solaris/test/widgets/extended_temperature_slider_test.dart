import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/widgets/deep_link_target.dart';
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

class _AsyncPendingMonitorService extends MonitorService {
  final Future<ExpandedGammaStatus> future;
  _AsyncPendingMonitorService(this.future);

  @override
  Future<ExpandedGammaStatus> getExpandedGammaStatus() => future;

  @override
  Future<bool> isExpandedGammaUnlocked() async => false;
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

    testWidgets(
      'Warning icon is positioned to the right of slider container and vertically centered',
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
                body: SizedBox(
                  width: 400,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sliderCenter = tester.getCenter(find.byType(Slider));
        final iconCenter = tester.getCenter(
          find.byIcon(LucideIcons.triangleAlert),
        );
        final flameCenter = tester.getCenter(find.byIcon(LucideIcons.flame));

        // The icon is strictly to the right of the slider center
        expect(iconCenter.dx, greaterThan(sliderCenter.dx));

        // The icon is below the flame icon (which is in the top header row)
        expect(iconCenter.dy, greaterThan(flameCenter.dy));

        // The icon is vertically centered on the slider row (within 2 pixels)
        expect((iconCenter.dy - sliderCenter.dy).abs(), lessThan(2.0));

        // Verify the icon size is 20 (prominent touch/click target for status indicator)
        final iconWidget = tester.widget<Icon>(
          find.byIcon(LucideIcons.triangleAlert),
        );
        expect(iconWidget.size, equals(20.0));
      },
    );

    testWidgets('Tapping warning icon opens expanded gamma dialog', (
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
              body: Center(
                child: SizedBox(
                  width: 320 + TemperatureSlider.kSideSlotWidth * 2,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final warningFinder = find.byIcon(LucideIcons.triangleAlert);
      expect(warningFinder, findsOneWidget);

      await tester.tap(warningFinder);
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets(
      'DeepLinkTarget wraps only slider body when deepLinkId is provided',
      (tester) async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
        );
        final anchorKey = GlobalKey<DeepLinkTargetState>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320 + TemperatureSlider.kSideSlotWidth * 2,
                    child: TemperatureSlider(
                      deepLinkKey: anchorKey,
                      deepLinkId: 'color_temperature',
                      value: 3000.0,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final targetFinder = find.byType(DeepLinkTarget);
        expect(targetFinder, findsOneWidget);

        final targetSize = tester.getSize(targetFinder);
        // The DeepLinkTarget is exactly 320px wide (matching BrightnessSlider)
        expect(targetSize.width, equals(320.0));

        // Trigger highlight animation on the target key
        anchorKey.currentState?.highlight();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Pulse indicator is wrapped in RepaintBoundary with comfortable hit target',
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
                body: SizedBox(
                  width: 400,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find InkWell for the status indicator
        final inkWellFinder = find.ancestor(
          of: find.byIcon(LucideIcons.triangleAlert),
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsOneWidget);

        final inkWellSize = tester.getSize(inkWellFinder);
        expect(inkWellSize.width, equals(TemperatureSlider.kSideSlotWidth));
        expect(inkWellSize.height, equals(40.0));

        // Verify RepaintBoundary is protecting the tree
        final repaintBoundaries = find.ancestor(
          of: find.byIcon(LucideIcons.triangleAlert),
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaries, findsWidgets);
      },
    );

    testWidgets(
      'Hovering and unmounting status indicator does not trigger lifecycle errors',
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
                body: SizedBox(
                  width: 400,
                  child: TemperatureSlider(value: 3000.0, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(LucideIcons.triangleAlert);
        expect(iconFinder, findsOneWidget);

        // Hover over the indicator
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: tester.getCenter(iconFinder));
        await tester.pump();

        // Unmount the widget while hovered
        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: const MaterialApp(
              home: Scaffold(body: SizedBox.shrink()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Move pointer away after unmount
        await gesture.moveTo(Offset.zero);
        await gesture.removePointer();
        await tester.pump();

        // No exceptions thrown
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Hides status indicator while gammaStatusAsync is loading and has no value',
      (tester) async {
        final completer = Completer<ExpandedGammaStatus>();
        final fakeService = _AsyncPendingMonitorService(completer.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
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

        // First frame while future is pending: gammaStatusAsync.hasValue is false
        await tester.pump();

        // Indicator should NOT be displayed while loading to prevent micro-flicker
        expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
        expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);

        // Resolve future with disabled
        completer.complete(ExpandedGammaStatus.disabled);
        await tester.pumpAndSettle();

        // Now indicator is visible
        expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
      },
    );
  });
}
