import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/settings_search_service.dart';

class MockMonitorService extends MonitorService {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<bool> setBrightness(String deviceName, int brightness) async {
    calls.add({'device': deviceName, 'brightness': brightness});
    return true;
  }
}

void main() {
  group('Software Dimming (Below 0) - Zero Trust Tests', () {
    test('SettingsState default and copyWith for isSoftwareDimmingEnabled', () {
      final state = SettingsState();
      expect(state.isSoftwareDimmingEnabled, isTrue);

      final updated = state.copyWith(isSoftwareDimmingEnabled: false);
      expect(updated.isSoftwareDimmingEnabled, isFalse);

      final reverted = updated.copyWith(isSoftwareDimmingEnabled: true);
      expect(reverted.isSoftwareDimmingEnabled, isTrue);
    });

    test(
      'SettingsState JSON serialization preserves isSoftwareDimmingEnabled',
      () {
        final state = SettingsState(isSoftwareDimmingEnabled: true);
        final json = state.toJson();
        expect(json['isSoftwareDimmingEnabled'], isTrue);

        final restored = SettingsState.fromJson(json);
        expect(restored.isSoftwareDimmingEnabled, isTrue);
      },
    );

    test(
      'BrightnessService supports negative target transitions when isSoftwareDimmingEnabled is true and isManual is true',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 0,
        );

        final List<int> reportedValues = [];

        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: -40.0,
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: true,
          isSoftwareDimmingEnabled: true,
          isUIVisible: false,
        );

        // Allow loop to settle completely (4 steps * 100ms + margin)
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(reportedValues, contains(-40));
        expect(
          mockMonitorService.calls.any((c) => c['brightness'] == -40),
          isTrue,
        );
      },
    );

    test(
      'BrightnessService clamps to 0.0 when isSoftwareDimmingEnabled is false, even with negative offsets',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 10,
        );

        final List<int> reportedValues = [];

        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: 5.0,
          offsets: {r'\\.\DISPLAY1': -20.0}, // 5 - 20 = -15
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: true,
          isSoftwareDimmingEnabled: false,
          isUIVisible: false,
        );

        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Must clamp to 0, never send negative values
        expect(reportedValues.any((v) => v < 0), isFalse);
        expect(
          mockMonitorService.calls.any((c) => (c['brightness'] as int) < 0),
          isFalse,
        );
      },
    );

    test(
      'BrightnessService clamps to 0.0 in automatic mode (!isManual), even if isSoftwareDimmingEnabled is true',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 10,
        );

        final List<int> reportedValues = [];

        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: 5.0,
          offsets: {r'\\.\DISPLAY1': -20.0}, // 5 - 20 = -15
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: false, // Automatic Circadian Mode
          isSoftwareDimmingEnabled: true,
          isUIVisible: false,
        );

        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Must clamp to 0, software dimming is manual only
        expect(reportedValues.any((v) => v < 0), isFalse);
        expect(
          mockMonitorService.calls.any((c) => (c['brightness'] as int) < 0),
          isFalse,
        );
      },
    );

    test(
      'In-flight transition override: automatic loop overridden by negative manual brightness propagates canDimSoftware and settles at negative target',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 30,
        );

        final List<int> reportedValues = [];

        // 1. Start an in-flight automatic adjustment (canDimSoftware: false)
        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: 20.0,
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: false,
          isSoftwareDimmingEnabled: false,
          isUIVisible: false,
        );

        // Allow loop to begin first step
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // 2. User immediately overrides with negative manual brightness
        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: -30.0,
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: true,
          isSoftwareDimmingEnabled: true,
          isUIVisible: true,
        );

        // Wait for loop to transition through zero down to -30
        await Future<void>.delayed(const Duration(milliseconds: 700));

        expect(reportedValues, contains(-30));
        expect(
          mockMonitorService.calls.any((c) => c['brightness'] == -30),
          isTrue,
        );
      },
    );

    test(
      'Negative range step-up (current < target) does not throw ArgumentError in clamp and transitions safely',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: -40,
        );

        final List<int> reportedValues = [];

        // Moving UP from -40 towards -10 within negative range (current < target)
        // Must never throw ArgumentError: lowerLimit (0) must be <= upperLimit (-10)
        brightnessService.applyBrightnessSmoothly(
          selection: r'\\.\DISPLAY1',
          targetValue: -10.0,
          monitors: [monitor],
          monitorService: mockMonitorService,
          updateBrightnessCallback: (dev, val) {
            reportedValues.add(val);
          },
          isManual: true,
          isSoftwareDimmingEnabled: true,
          isUIVisible: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(reportedValues, contains(-10));
        expect(
          mockMonitorService.calls.any((c) => c['brightness'] == -10),
          isTrue,
        );
      },
    );

    test(
      'Rapid back-and-forth oscillation across zero and negative thresholds completes cleanly',
      () async {
        final brightnessService = BrightnessService();
        final mockMonitorService = MockMonitorService();
        final monitor = MonitorInfo(
          id: '1',
          name: 'Display 1',
          friendlyName: 'LG UltraFine (Kyiv)',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'hash1',
          isPrimary: true,
          realBrightness: 0,
        );

        final List<int> reportedValues = [];

        void apply(double target) {
          brightnessService.applyBrightnessSmoothly(
            selection: r'\\.\DISPLAY1',
            targetValue: target,
            monitors: [monitor],
            monitorService: mockMonitorService,
            updateBrightnessCallback: (dev, val) {
              reportedValues.add(val);
            },
            isManual: true,
            isSoftwareDimmingEnabled: true,
            isUIVisible: true,
          );
        }

        // Rapid user slider adjustments
        apply(-50.0);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        apply(-20.0);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        apply(-45.0);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        apply(-5.0);

        // Allow final target to settle completely
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(reportedValues.last, equals(-5));
        expect(mockMonitorService.calls.last['brightness'], equals(-5));
      },
    );

    testWidgets(
      'SettingsSearchService indexes software_dimming with correct anchorId and screen',
      (WidgetTester tester) async {
        late SettingsSearchService service;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (context) {
                service = SettingsSearchService(context);
                return const SizedBox();
              },
            ),
          ),
        );

        final results = service.search('Extra Dark Dimming');
        expect(
          results.any((item) => item.anchorId == 'software_dimming'),
          isTrue,
        );
        final item = results.firstWhere(
          (item) => item.anchorId == 'software_dimming',
        );
        expect(item.screen, equals(AppScreen.settings));
        expect(item.id, equals('software_dimming'));
      },
    );
  });
}
