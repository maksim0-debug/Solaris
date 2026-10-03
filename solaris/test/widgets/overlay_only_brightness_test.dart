import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/screens/dashboard.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/widgets/brightness_dial.dart';
import 'package:solaris/widgets/brightness_slider.dart';

class _MockMonitorService extends Fake implements MonitorService {
  final List<Map<String, dynamic>> recordedBrightnessCalls = [];
  final List<Map<String, dynamic>> recordedGetBrightnessCalls = [];
  List<MonitorInfo> mockMonitors = [];

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async => mockMonitors;

  @override
  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    recordedBrightnessCalls.add({
      'deviceName': deviceName,
      'brightness': brightness,
      'isOverlayOnly': isOverlayOnly,
    });
    return true;
  }

  @override
  Future<int?> getBrightness(
    String deviceName, {
    bool isOverlayOnly = false,
    bool probeHardware = false,
  }) async {
    recordedGetBrightnessCalls.add({
      'deviceName': deviceName,
      'isOverlayOnly': isOverlayOnly,
      'probeHardware': probeHardware,
    });
    return null;
  }
}

void main() {
  group('MonitorInfo isDdcSupported & Overlay Only Tests', () {
    test(
      'MonitorInfo retains isDdcSupported false even when realBrightness is set',
      () {
        final monitor = MonitorInfo(
          id: 'DISPLAY2',
          name: 'ASUS VG259QMR5A',
          friendlyName: 'ASUS VG259QMR5A',
          deviceName: r'\\.\DISPLAY2',
          deviceIdHash: 'hash123',
          isPrimary: false,
          realBrightness: 80,
          isDdcSupported: false,
        );

        expect(monitor.isDdcSupported, isFalse);
        expect(monitor.realBrightness, equals(80));

        final updated = monitor.copyWith(realBrightness: 65);
        expect(updated.isDdcSupported, isFalse);
        expect(updated.realBrightness, equals(65));
      },
    );
  });

  group('BrightnessSlider Overlay Only Mapping & UI Tests', () {
    test(
      'valueToProgress and progressToValue are linear across 0..100 when isOverlayOnly is true',
      () {
        expect(
          BrightnessSlider.valueToProgress(
            value: 0.0,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(0.0),
        );
        expect(
          BrightnessSlider.valueToProgress(
            value: 50.0,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(0.5),
        );
        expect(
          BrightnessSlider.valueToProgress(
            value: 100.0,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(1.0),
        );

        expect(
          BrightnessSlider.progressToValue(
            progress: 0.0,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(0.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.5,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(50.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 1.0,
            isSoftwareDimmingEnabled: true,
            isOverlayOnly: true,
          ),
          equals(100.0),
        );
      },
    );

    testWidgets(
      'BrightnessSlider renders purple moon badge and icons in isOverlayOnly mode',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrightnessSlider(
                value: 70.0,
                isOverlayOnly: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // In isOverlayOnly mode, moon icon is present in purple badge and on left
        expect(find.byIcon(LucideIcons.moon), findsNWidgets(2));
        expect(find.text('70%'), findsOneWidget);
      },
    );
  });

  group('BrightnessDialPainter Overlay Only Tests', () {
    test(
      'BrightnessDialPainter handles isOverlayOnly flag cleanly without error',
      () {
        final painter = BrightnessDialPainter(
          brightness: 0.7,
          isOverlayOnly: true,
        );
        expect(painter.brightness, equals(0.7));
        expect(painter.isOverlayOnly, isTrue);

        final painterDdc = BrightnessDialPainter(
          brightness: 0.7,
          isOverlayOnly: false,
        );
        expect(painter.shouldRepaint(painterDdc), isTrue);
      },
    );
  });

  group('DisplayInfo UI Overlay Tooltip & Brightness Label Tests', () {
    Widget buildTestableWidget(
      Widget child, [
      Locale locale = const Locale('uk'),
    ]) {
      return ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets(
      'DisplayInfo renders percentage even when isDdcSupported is false if brightness is present',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            const DisplayInfo(
              label: 'ASUS VG259QMR5A',
              brightness: 85,
              isDdcSupported: false,
              isSelected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ASUS VG259QMR5A: 85%'), findsOneWidget);
      },
    );

    testWidgets(
      'Tooltip contains overlay dimming notice when DDC/CI is unsupported (Ukrainian)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            const DisplayInfo(
              label: 'ASUS VG259QMR5A',
              brightness: 100,
              isDdcSupported: false,
              isSelected: false,
            ),
            const Locale('uk'),
          ),
        );
        await tester.pumpAndSettle();

        final tooltipFinder = find.byType(Tooltip);
        expect(tooltipFinder, findsWidgets);

        final Tooltip tooltip = tester.widget(tooltipFinder.first);
        expect(tooltip.message, contains('програмний оверлей'));
      },
    );
  });

  group('BrightnessService isOverlayOnly routing', () {
    test(
      'BrightnessService routes to setBrightness with isOverlayOnly: true for non-DDC monitors',
      () async {
        final mockService = _MockMonitorService();
        final brightnessService = BrightnessService();

        final nonDdcMonitor = MonitorInfo(
          id: 'DISPLAY_NO_DDC',
          name: 'ASUS VG259QMR5A',
          friendlyName: 'ASUS VG259QMR5A',
          deviceName: r'\\.\DISPLAY_NO_DDC',
          deviceIdHash: 'hash999',
          isPrimary: false,
          realBrightness: 100,
          isDdcSupported: false,
        );

        brightnessService.applyBrightnessSmoothly(
          selection: nonDdcMonitor.deviceName,
          targetValue: 60.0,
          monitors: [nonDdcMonitor],
          monitorService: mockService,
          isManual: true,
          updateBrightnessCallback: (_, _) {},
        );

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(mockService.recordedBrightnessCalls.isNotEmpty, isTrue);
        final lastCall = mockService.recordedBrightnessCalls.last;
        expect(lastCall['deviceName'], equals(nonDdcMonitor.deviceName));
        expect(lastCall['isOverlayOnly'], isTrue);
      },
    );

    test(
      'MonitorService.getBrightness records isOverlayOnly flag accurately',
      () async {
        final mockService = _MockMonitorService();
        await mockService.getBrightness(r'\\.\DISPLAY1', isOverlayOnly: false);
        await mockService.getBrightness(r'\\.\DISPLAY2', isOverlayOnly: true);

        expect(mockService.recordedGetBrightnessCalls.length, equals(2));
        expect(
          mockService.recordedGetBrightnessCalls[0]['isOverlayOnly'],
          isFalse,
        );
        expect(
          mockService.recordedGetBrightnessCalls[1]['isOverlayOnly'],
          isTrue,
        );

        await mockService.getBrightness(r'\\.\DISPLAY1', probeHardware: true);
        expect(mockService.recordedGetBrightnessCalls.length, equals(3));
        expect(
          mockService.recordedGetBrightnessCalls[2]['probeHardware'],
          isTrue,
        );
      },
    );
  });

  group('Mixed Multi-Monitor isOverlayOnly Selection Tests', () {
    test(
      'isOverlayOnly is false when at least one monitor in selection supports DDC/CI',
      () {
        final ddcMonitor = MonitorInfo(
          id: 'DISPLAY1',
          name: 'Primary DDC Monitor',
          friendlyName: 'Primary DDC Monitor',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 80,
          isDdcSupported: true,
        );
        final nonDdcMonitor = MonitorInfo(
          id: 'DISPLAY2',
          name: 'Secondary Non-DDC Monitor',
          friendlyName: 'Secondary Non-DDC Monitor',
          deviceName: r'\\.\DISPLAY2',
          deviceIdHash: 'hash2',
          isPrimary: false,
          realBrightness: 100,
          isDdcSupported: false,
        );

        final monitors = [ddcMonitor, nonDdcMonitor];

        // Selection is 'all': mixed fleet -> isOverlayOnly should be false
        final bool isOverlayOnlyAll =
            monitors.isNotEmpty && monitors.every((m) => !m.isDdcSupported);
        expect(isOverlayOnlyAll, isFalse);

        // Selection is single non-DDC: isOverlayOnly should be true
        final nonDdcSelected = monitors
            .where((m) => m.deviceName == nonDdcMonitor.deviceName)
            .firstOrNull;
        expect(
          nonDdcSelected != null && !nonDdcSelected.isDdcSupported,
          isTrue,
        );

        // Test static helper MonitorInfo.isSelectionOverlayOnly
        expect(MonitorInfo.isSelectionOverlayOnly({'all'}, monitors), isFalse);
        expect(
          MonitorInfo.isSelectionOverlayOnly({
            nonDdcMonitor.deviceName,
          }, monitors),
          isTrue,
        );
        expect(
          MonitorInfo.isSelectionOverlayOnly({ddcMonitor.deviceName}, monitors),
          isFalse,
        );
      },
    );

    test('isOverlayOnly is true when ALL connected monitors lack DDC/CI', () {
      final nonDdc1 = MonitorInfo(
        id: 'DISPLAY1',
        name: 'Non-DDC 1',
        friendlyName: 'Non-DDC 1',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'h1',
        isPrimary: true,
        realBrightness: 100,
        isDdcSupported: false,
      );
      final nonDdc2 = MonitorInfo(
        id: 'DISPLAY2',
        name: 'Non-DDC 2',
        friendlyName: 'Non-DDC 2',
        deviceName: r'\\.\DISPLAY2',
        deviceIdHash: 'h2',
        isPrimary: false,
        realBrightness: 90,
        isDdcSupported: false,
      );

      final monitors = [nonDdc1, nonDdc2];
      final bool isOverlayOnlyAll =
          monitors.isNotEmpty && monitors.every((m) => !m.isDdcSupported);
      expect(isOverlayOnlyAll, isTrue);
      expect(MonitorInfo.isSelectionOverlayOnly({'all'}, monitors), isTrue);
      expect(
        MonitorInfo.isSelectionOverlayOnly({r'\\.\DISPLAY1'}, monitors),
        isTrue,
      );
    });

    test(
      'adjustManualBrightness clamps to 0.0 when selected monitor is overlay-only',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final mockService = _MockMonitorService();

        final nonDdcMonitor = MonitorInfo(
          id: 'DISPLAY1',
          name: 'Non-DDC 1',
          friendlyName: 'Non-DDC 1',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'h1',
          isPrimary: true,
          realBrightness: 50,
          isDdcSupported: false,
        );
        mockService.mockMonitors = [nonDdcMonitor];

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            monitorServiceProvider.overrideWithValue(mockService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);
        container.read(manualBrightnessProvider.notifier).update(10.0);
        container
            .read(selectedMonitorsProvider.notifier)
            .selectOnly(r'\\.\DISPLAY1');

        // Adjust brightness down by 50 points (10 - 50 = -40)
        container.read(settingsProvider.notifier).adjustManualBrightness(-50.0);

        // Because DISPLAY1 is overlay-only, lower bound MUST be clamped to 0.0, not -100.0
        expect(container.read(manualBrightnessProvider), equals(0.0));
      },
    );

    test(
      'isSelectionOverlayOnly correctly identifies multi-selection subset of non-DDC monitors in mixed 3-monitor fleet',
      () {
        final ddc1 = MonitorInfo(
          id: r'\\.\DISPLAY1',
          name: 'DDC Monitor 1',
          friendlyName: 'DDC Monitor 1',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'h_ddc1',
          isPrimary: true,
          realBrightness: 80,
          isDdcSupported: true,
        );
        final nonDdc2 = MonitorInfo(
          id: r'\\.\DISPLAY2',
          name: 'Non-DDC Monitor 2',
          friendlyName: 'Non-DDC Monitor 2',
          deviceName: r'\\.\DISPLAY2',
          deviceIdHash: 'h_nonddc2',
          isPrimary: false,
          realBrightness: 100,
          isDdcSupported: false,
        );
        final nonDdc3 = MonitorInfo(
          id: r'\\.\DISPLAY3',
          name: 'Non-DDC Monitor 3',
          friendlyName: 'Non-DDC Monitor 3',
          deviceName: r'\\.\DISPLAY3',
          deviceIdHash: 'h_nonddc3',
          isPrimary: false,
          realBrightness: 100,
          isDdcSupported: false,
        );

        final monitors = [ddc1, nonDdc2, nonDdc3];

        // 1. Both non-DDC selected: subset selection is overlay-only!
        expect(
          MonitorInfo.isSelectionOverlayOnly({
            r'\\.\DISPLAY2',
            r'\\.\DISPLAY3',
          }, monitors),
          isTrue,
        );

        // 2. One DDC and one non-DDC selected: hybrid mode!
        expect(
          MonitorInfo.isSelectionOverlayOnly({
            r'\\.\DISPLAY1',
            r'\\.\DISPLAY2',
          }, monitors),
          isFalse,
        );

        // 3. 'all' selected: hybrid mode because DDC monitor exists!
        expect(MonitorInfo.isSelectionOverlayOnly({'all'}, monitors), isFalse);
      },
    );

    test('MonitorInfo.effectiveMinBrightness enforces bounds correctly', () {
      expect(
        MonitorInfo.effectiveMinBrightness(
          isOverlayOnly: true,
          isSoftwareDimmingEnabled: true,
        ),
        equals(0.0),
      );
      expect(
        MonitorInfo.effectiveMinBrightness(
          isOverlayOnly: true,
          isSoftwareDimmingEnabled: false,
        ),
        equals(0.0),
      );
      expect(
        MonitorInfo.effectiveMinBrightness(
          isOverlayOnly: false,
          isSoftwareDimmingEnabled: true,
        ),
        equals(-100.0),
      );
      expect(
        MonitorInfo.effectiveMinBrightness(
          isOverlayOnly: false,
          isSoftwareDimmingEnabled: false,
        ),
        equals(0.0),
      );
    });
  });
}
