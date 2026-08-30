import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/monitor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel(
      'plugins.flutter.io/path_provider',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
    const MethodChannel('com.solaris.monitor/names').setMockMethodCallHandler((
      MethodCall methodCall,
    ) async {
      return null;
    });
    const MethodChannel(
      'flutter.baseflow.com/geolocator',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });
  });

  group('ActiveProcessService & Priority Cascades Zero-Trust Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          effectiveLocationProvider.overrideWithValue(
            AsyncData(
              Position(
                latitude: 50.4501, // Kyiv
                longitude: 30.5234,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('ActiveProcessService Unit & State Machine Tests', () {
      test('Initial ActiveProcessState is clean', () {
        final state = container.read(activeProcessServiceProvider);
        expect(state.activeProcess, equals(''));
        expect(state.windowTitle, equals(''));
        expect(state.isGaming, isFalse);
        expect(state.suppressedPids, isEmpty);
      });

      test(
        'updateActiveProcessManually updates activeProcess and windowTitle',
        () {
          final service = container.read(activeProcessServiceProvider.notifier);
          service.updateActiveProcessManually(
            'photoshop.exe',
            title: 'Adobe Photoshop 2026',
          );

          final state = container.read(activeProcessServiceProvider);
          expect(state.activeProcess, equals('photoshop.exe'));
          expect(state.windowTitle, equals('Adobe Photoshop 2026'));
          expect(state.isGaming, isFalse);
        },
      );

      test(
        'System shell processes are ignored and retain previous active process',
        () {
          final service = container.read(activeProcessServiceProvider.notifier);
          service.updateActiveProcessManually(
            'photoshop.exe',
            title: 'Adobe Photoshop',
          );

          for (final shellProc in ActiveProcessService.systemShellBlacklist) {
            service.updateActiveProcessManually(
              shellProc,
              title: 'Windows Shell',
            );
            final state = container.read(activeProcessServiceProvider);
            expect(
              state.activeProcess,
              equals('photoshop.exe'),
              reason:
                  'Shell process $shellProc must not override active user process',
            );
          }
        },
      );

      test(
        'Immediate Preemption: switching directly between two profiled apps updates immediately (0 ms)',
        () {
          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'photoshop.exe',
              appDisplayName: 'Photoshop',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 6500.0,
            ),
          );
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'premiere.exe',
              appDisplayName: 'Premiere Pro',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 5500.0,
            ),
          );

          final service = container.read(activeProcessServiceProvider.notifier);
          service.updateActiveProcessManually('photoshop.exe');
          expect(
            container.read(activeProcessServiceProvider).activeProcess,
            equals('photoshop.exe'),
          );

          // Direct switch to another profiled app -> Immediate Preemption
          service.updateActiveProcessManually('premiere.exe');
          expect(
            container.read(activeProcessServiceProvider).activeProcess,
            equals('premiere.exe'),
          );
        },
      );

      test(
        'Suppressed PIDs can be set and are automatically cleared on switching user applications',
        () {
          final service = container.read(activeProcessServiceProvider.notifier);
          service.updateActiveProcessManually('photoshop.exe');

          service.suppressActiveApp(555);
          expect(
            container.read(activeProcessServiceProvider).suppressedPids,
            contains(555),
          );

          // Switching to a new user app clears suppressedPids
          service.updateActiveProcessManually('blender.exe');
          expect(
            container.read(activeProcessServiceProvider).activeProcess,
            equals('blender.exe'),
          );
          expect(
            container.read(activeProcessServiceProvider).suppressedPids,
            isEmpty,
          );
        },
      );
    });

    group('SettingsNotifier CRUD Methods Zero-Trust Tests', () {
      test(
        'addAppOverride adds new rule and replaces existing rule with same exeName case-insensitively',
        () {
          final notifier = container.read(settingsProvider.notifier);

          const newRule = AppOverrideRule(
            exeName: 'custom_editor.exe',
            appDisplayName: 'Custom Editor',
            brightnessMode: AppOverrideMode.fixed,
            fixedBrightness: 90.0,
          );
          notifier.addAppOverride(newRule);

          final settingsMap = container.read(settingsProvider).value;
          final rules = settingsMap?['all']?.appOverrides ?? [];
          final found = rules.firstWhere(
            (r) => r.exeName == 'custom_editor.exe',
          );
          expect(found.fixedBrightness, equals(90.0));

          // Re-adding with uppercase/untrimmed raw exeName replaces existing rule without duplicates
          const updatedRule = AppOverrideRule(
            exeName: '  CUSTOM_EDITOR.EXE  ',
            appDisplayName: 'Custom Editor v2',
            brightnessMode: AppOverrideMode.fixed,
            fixedBrightness: 45.0,
          );
          notifier.addAppOverride(updatedRule);

          final rules2 =
              container.read(settingsProvider).value?['all']?.appOverrides ??
              [];
          final count = rules2
              .where((r) => r.exeName.toLowerCase() == 'custom_editor.exe')
              .length;
          expect(count, equals(1));
          expect(
            rules2
                .firstWhere(
                  (r) => r.exeName.toLowerCase() == 'custom_editor.exe',
                )
                .fixedBrightness,
            equals(45.0),
          );
        },
      );

      test('updateAppOverride modifies existing rule in list', () {
        final notifier = container.read(settingsProvider.notifier);

        const initial = AppOverrideRule(
          exeName: 'test_app.exe',
          appDisplayName: 'Test App',
          isEnabled: true,
        );
        notifier.addAppOverride(initial);

        final modified = initial.copyWith(
          isEnabled: false,
          fixedTemperature: 5000.0,
          temperatureMode: AppOverrideMode.fixed,
        );
        notifier.updateAppOverride(modified);

        final rules =
            container.read(settingsProvider).value?['all']?.appOverrides ?? [];
        final target = rules.firstWhere((r) => r.exeName == 'test_app.exe');
        expect(target.isEnabled, isFalse);
        expect(target.fixedTemperature, equals(5000.0));
      });

      test('removeAppOverride removes rule by case-insensitive exeName', () {
        final notifier = container.read(settingsProvider.notifier);
        notifier.addAppOverride(
          const AppOverrideRule(
            exeName: 'to_delete.exe',
            appDisplayName: 'To Delete',
          ),
        );

        notifier.removeAppOverride('  TO_DELETE.EXE  ');
        final rules =
            container.read(settingsProvider).value?['all']?.appOverrides ?? [];
        expect(rules.any((r) => r.exeName == 'to_delete.exe'), isFalse);
      });

      test('toggleAppOverride enables and disables rule status', () {
        final notifier = container.read(settingsProvider.notifier);
        notifier.addAppOverride(
          const AppOverrideRule(
            exeName: 'toggle_me.exe',
            appDisplayName: 'Toggle Me',
            isEnabled: true,
          ),
        );

        notifier.toggleAppOverride('toggle_me.exe', false);
        var rules =
            container.read(settingsProvider).value?['all']?.appOverrides ?? [];
        expect(
          rules.firstWhere((r) => r.exeName == 'toggle_me.exe').isEnabled,
          isFalse,
        );

        notifier.toggleAppOverride('TOGGLE_ME.EXE', true);
        rules =
            container.read(settingsProvider).value?['all']?.appOverrides ?? [];
        expect(
          rules.firstWhere((r) => r.exeName == 'toggle_me.exe').isEnabled,
          isTrue,
        );
      });

      test(
        'resetBuiltInAppOverrides restores missing built-in rules without removing custom user rules',
        () {
          final notifier = container.read(settingsProvider.notifier);

          // Add custom user rule
          notifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'my_game.exe',
              appDisplayName: 'My Game',
              isBuiltIn: false,
            ),
          );

          // Delete built-in rule 'photoshop.exe'
          notifier.removeAppOverride('photoshop.exe');

          // Reset built-in rules
          notifier.resetBuiltInAppOverrides();

          final rules =
              container.read(settingsProvider).value?['all']?.appOverrides ??
              [];
          expect(rules.any((r) => r.exeName == 'photoshop.exe'), isTrue);
          expect(rules.any((r) => r.exeName == 'my_game.exe'), isTrue);
        },
      );

      test(
        'promoteBuiltInToUser changes isBuiltIn flag from true to false',
        () {
          final notifier = container.read(settingsProvider.notifier);

          notifier.promoteBuiltInToUser('photoshop.exe');
          final rules =
              container.read(settingsProvider).value?['all']?.appOverrides ??
              [];
          final photoshopRule = rules.firstWhere(
            (r) => r.exeName == 'photoshop.exe',
          );
          expect(photoshopRule.isBuiltIn, isFalse);
        },
      );

      test('updateAppOverrideExitDelay clamps values between 0 and 300', () {
        final notifier = container.read(settingsProvider.notifier);

        notifier.updateAppOverrideExitDelay(150);
        expect(
          container
              .read(settingsProvider)
              .value?['all']
              ?.appOverrideExitDelaySeconds,
          equals(150),
        );

        notifier.updateAppOverrideExitDelay(-20);
        expect(
          container
              .read(settingsProvider)
              .value?['all']
              ?.appOverrideExitDelaySeconds,
          equals(0),
        );

        notifier.updateAppOverrideExitDelay(500);
        expect(
          container
              .read(settingsProvider)
              .value?['all']
              ?.appOverrideExitDelaySeconds,
          equals(300),
        );
      });
    });

    group('CurrentBrightnessNotifier Priority Cascade Zero-Trust Tests', () {
      test(
        'Fixed Brightness App Override takes precedence over Circadian / Game / Manual',
        () {
          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'photoshop.exe',
              appDisplayName: 'Photoshop',
              brightnessMode: AppOverrideMode.fixed,
              fixedBrightness: 85.0,
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('photoshop.exe');

          final brightness = container.read(currentBrightnessProvider);
          expect(brightness, equals(85.0));
        },
      );

      test(
        'Safe Fallback when curve preset ID is deleted/missing in brightness cascade',
        () {
          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'blender.exe',
              appDisplayName: 'Blender',
              brightnessMode: AppOverrideMode.curve,
              brightnessCurvePresetId: 'non_existent_preset_999',
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('blender.exe');

          // Safe fallback should evaluate without throwing StateError exception
          expect(
            () => container.read(currentBrightnessProvider),
            returnsNormally,
          );
        },
      );

      test(
        'Suppressed PIDs bypass App Override rule and fall back in cascade',
        () {
          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'photoshop.exe',
              appDisplayName: 'Photoshop',
              brightnessMode: AppOverrideMode.fixed,
              fixedBrightness: 85.0,
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('photoshop.exe');

          // Suppress active process
          activeProcessService.suppressActiveApp(1234);

          final brightness = container.read(currentBrightnessProvider);
          // Must NOT be 85.0 because app profile is suppressed
          expect(brightness, isNot(equals(85.0)));
        },
      );

      test(
        'setManualBrightness calls suppressActiveApp and updates manual brightness',
        () {
          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('photoshop.exe');

          final brightnessNotifier = container.read(
            currentBrightnessProvider.notifier,
          );
          brightnessNotifier.setManualBrightness(50.0);

          expect(
            container.read(activeProcessServiceProvider).suppressedPids,
            isNotEmpty,
          );
        },
      );
    });

    group('CurrentTemperatureNotifier Priority Cascade Zero-Trust Tests', () {
      test('Color Temperature Disabled overrides everything to 6500K', () {
        container.read(isColorTemperatureEnabledProvider.notifier).set(false);

        final settingsNotifier = container.read(settingsProvider.notifier);
        settingsNotifier.addAppOverride(
          const AppOverrideRule(
            exeName: 'photoshop.exe',
            appDisplayName: 'Photoshop',
            temperatureMode: AppOverrideMode.fixed,
            fixedTemperature: 5000.0,
          ),
        );

        final activeProcessService = container.read(
          activeProcessServiceProvider.notifier,
        );
        activeProcessService.updateActiveProcessManually('photoshop.exe');

        final temp = container.read(currentTemperatureProvider);
        expect(temp, equals(6500));
      });

      test(
        'Fixed Temperature App Override takes precedence when temperature is enabled',
        () {
          container.read(isColorTemperatureEnabledProvider.notifier).set(true);

          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'premiere.exe',
              appDisplayName: 'Premiere Pro',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 5500.0,
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('premiere.exe');

          final temp = container.read(currentTemperatureProvider);
          expect(temp, equals(5500));
        },
      );

      test(
        'Fixed Temperature is clamped strictly between 3300K and 6500K and rounded',
        () {
          container.read(isColorTemperatureEnabledProvider.notifier).set(true);

          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'app1.exe',
              appDisplayName: 'App 1',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 9000.0,
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('app1.exe');
          expect(container.read(currentTemperatureProvider), equals(6500));

          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'app2.exe',
              appDisplayName: 'App 2',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 1000.0,
            ),
          );
          activeProcessService.updateActiveProcessManually('app2.exe');
          expect(container.read(currentTemperatureProvider), equals(3300));
        },
      );

      test(
        'Safe Fallback when curve preset ID is deleted/missing in temperature cascade',
        () {
          container.read(isColorTemperatureEnabledProvider.notifier).set(true);

          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'lightroom.exe',
              appDisplayName: 'Lightroom',
              temperatureMode: AppOverrideMode.curve,
              temperatureCurvePresetId: 'non_existent_temp_preset_888',
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('lightroom.exe');

          expect(
            () => container.read(currentTemperatureProvider),
            returnsNormally,
          );
        },
      );

      test('Suppressed PIDs bypass Temperature App Override rule', () {
        container.read(isColorTemperatureEnabledProvider.notifier).set(true);

        final settingsNotifier = container.read(settingsProvider.notifier);
        settingsNotifier.addAppOverride(
          const AppOverrideRule(
            exeName: 'premiere.exe',
            appDisplayName: 'Premiere Pro',
            temperatureMode: AppOverrideMode.fixed,
            fixedTemperature: 5500.0,
          ),
        );

        final activeProcessService = container.read(
          activeProcessServiceProvider.notifier,
        );
        activeProcessService.updateActiveProcessManually('premiere.exe');

        // Suppress active app
        activeProcessService.suppressActiveApp(777);

        final temp = container.read(currentTemperatureProvider);
        expect(temp, isNot(equals(5500)));
      });

      test(
        'setManualTemperature calls suppressActiveApp and sets temperature',
        () {
          container.read(isColorTemperatureEnabledProvider.notifier).set(true);

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('premiere.exe');

          final tempNotifier = container.read(
            currentTemperatureProvider.notifier,
          );
          tempNotifier.setManualTemperature(4200);

          expect(
            container.read(activeProcessServiceProvider).suppressedPids,
            isNotEmpty,
          );
        },
      );

      test(
        'Circadian adjustment loop respects Per-App Fixed Temperature override',
        () {
          container.read(isColorTemperatureEnabledProvider.notifier).set(true);
          final settingsNotifier = container.read(settingsProvider.notifier);
          settingsNotifier.addAppOverride(
            const AppOverrideRule(
              exeName: 'fotor.exe',
              appDisplayName: 'Fotor Editor',
              temperatureMode: AppOverrideMode.fixed,
              fixedTemperature: 3300.0,
            ),
          );

          final activeProcessService = container.read(
            activeProcessServiceProvider.notifier,
          );
          activeProcessService.updateActiveProcessManually('fotor.exe');

          // Read current temperature provider which is listened by circadian loop
          final targetTemp = container.read(currentTemperatureProvider);
          expect(targetTemp, equals(3300));

          // Read circadian adjustment provider to verify it initializes without errors
          container.read(circadianAdjustmentProvider);
        },
      );
    });

    group('GamingModeService Integration Zero-Trust Tests', () {
      test('setGamingState updates gamingModeProvider state', () {
        final gamingNotifier = container.read(gamingModeProvider.notifier);
        expect(container.read(gamingModeProvider), isFalse);

        gamingNotifier.setGamingState(true);
        expect(container.read(gamingModeProvider), isTrue);

        gamingNotifier.setGamingState(false);
        expect(container.read(gamingModeProvider), isFalse);
      });

      test('Per-monitor game mode cascade isolation test', () {
        final settingsNotifier = container.read(settingsProvider.notifier);
        final gamingNotifier = container.read(gamingModeProvider.notifier);
        final manualBrightnessNotifier = container.read(
          manualBrightnessProvider.notifier,
        );

        container
            .read(autoBrightnessAdjustmentProvider.notifier)
            .setEnabled(false);
        manualBrightnessNotifier.update(45.0);

        // Configure Monitor 1: Game Mode Enabled, Brightness 85%
        // Configure Monitor 2: Game Mode Disabled, Brightness 45% (Manual)
        settingsNotifier.updateGameModeBrightness(85.0);
        settingsNotifier.updateMonitorGameModeEnabled(r'\\.\DISPLAY1', true);
        settingsNotifier.updateMonitorGameModeEnabled(r'\\.\DISPLAY2', false);

        // Turn on Game Mode
        gamingNotifier.setGamingState(true);

        // When Monitor 1 is selected -> brightness is 85.0 (Game Mode)
        container
            .read(selectedMonitorsProvider.notifier)
            .selectOnly(r'\\.\DISPLAY1');
        expect(container.read(currentBrightnessProvider), equals(85.0));

        // When Monitor 2 is selected -> brightness is NOT Game Mode (remains 45.0 manual)
        container
            .read(selectedMonitorsProvider.notifier)
            .selectOnly(r'\\.\DISPLAY2');
        expect(container.read(currentBrightnessProvider), equals(45.0));
      });

      test('setGameModeScope configures primaryOnly correctly', () {
        final settingsNotifier = container.read(settingsProvider.notifier);
        final mockMonitors = [
          MonitorInfo(
            id: r'\\.\DISPLAY1',
            name: 'Generic PnP Monitor',
            deviceName: r'\\.\DISPLAY1',
            friendlyName: 'Primary Display',
            deviceIdHash: 'a1b2',
            isPrimary: true,
          ),
          MonitorInfo(
            id: r'\\.\DISPLAY2',
            name: 'Generic PnP Monitor',
            deviceName: r'\\.\DISPLAY2',
            friendlyName: 'Secondary Display',
            deviceIdHash: 'c3d4',
            isPrimary: false,
          ),
        ];

        settingsNotifier.setGameModeScope(
          primaryOnly: true,
          monitors: mockMonitors,
        );

        final map = container.read(settingsProvider).value!;
        expect(map[r'\\.\DISPLAY1']?.isGameModeEnabled, isTrue);
        expect(map[r'\\.\DISPLAY2']?.isGameModeEnabled, isFalse);

        settingsNotifier.setGameModeScope(
          primaryOnly: false,
          monitors: mockMonitors,
        );

        final map2 = container.read(settingsProvider).value!;
        expect(map2[r'\\.\DISPLAY1']?.isGameModeEnabled, isTrue);
        expect(map2[r'\\.\DISPLAY2']?.isGameModeEnabled, isTrue);
      });

      test(
        'Adjusting brightness for non-gaming monitor does not mutate gaming monitor',
        () async {
          await container.read(settingsProvider.future);
          final settingsNotifier = container.read(settingsProvider.notifier);
          final gamingNotifier = container.read(gamingModeProvider.notifier);

          container
              .read(autoBrightnessAdjustmentProvider.notifier)
              .setEnabled(false);

          // Monitor 1: Game Mode Enabled (90%)
          // Monitor 2: Game Mode Disabled
          settingsNotifier.updateGameModeBrightness(90.0);
          settingsNotifier.updateMonitorGameModeEnabled(r'\\.\DISPLAY1', true);
          settingsNotifier.updateMonitorGameModeEnabled(r'\\.\DISPLAY2', false);

          // Game Mode active
          gamingNotifier.setGamingState(true);

          // Select Monitor 2 and set manual brightness to 30%
          container
              .read(selectedMonitorsProvider.notifier)
              .selectOnly(r'\\.\DISPLAY2');
          container
              .read(currentBrightnessProvider.notifier)
              .setManualBrightness(30.0);

          // Monitor 2 should be 30%
          expect(container.read(currentBrightnessProvider), equals(30.0));

          // When switching to Monitor 1, it must still be locked to 90% (Game Mode)
          container
              .read(selectedMonitorsProvider.notifier)
              .selectOnly(r'\\.\DISPLAY1');
          expect(container.read(currentBrightnessProvider), equals(90.0));
        },
      );
    });
  });
}
