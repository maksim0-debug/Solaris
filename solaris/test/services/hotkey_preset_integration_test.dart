import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/preset_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hotkey & Preset Integration Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('setActivePreset automatically enables auto-brightness', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);

      // 1. Manually disable auto-brightness
      settingsNotifier.updateAutoBrightness(false);
      var map = container.read(settingsProvider).value!;
      expect(map['all']!.isAutoBrightnessEnabled, false);

      // 2. Call setActivePreset
      settingsNotifier.setActivePreset(PresetType.dimmest);
      map = container.read(settingsProvider).value!;

      expect(map['all']!.activePreset, PresetType.dimmest);
      expect(map['all']!.isAutoBrightnessEnabled, true);
    });

    test('setActiveUserPreset automatically enables auto-brightness', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);

      // 1. Save a new user preset
      settingsNotifier.saveAsNewPreset('My Custom Preset');
      var map = container.read(settingsProvider).value!;
      final userPresetId = map['all']!.userPresets.first.id;

      // 2. Disable auto-brightness
      settingsNotifier.updateAutoBrightness(false);
      map = container.read(settingsProvider).value!;
      expect(map['all']!.isAutoBrightnessEnabled, false);

      // 3. Set active user preset
      settingsNotifier.setActiveUserPreset(userPresetId);
      map = container.read(settingsProvider).value!;

      expect(map['all']!.activeUserPresetId, userPresetId);
      expect(map['all']!.isAutoBrightnessEnabled, true);
    });

    test('cyclePreset forward and backward enables auto-brightness and cycles order', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);

      // 1. Disable auto-brightness
      settingsNotifier.updateAutoBrightness(false);
      var map = container.read(settingsProvider).value!;
      expect(map['all']!.isAutoBrightnessEnabled, false);

      // 2. Cycle preset forward
      settingsNotifier.cyclePreset(brighter: true);
      map = container.read(settingsProvider).value!;

      expect(map['all']!.isAutoBrightnessEnabled, true);

      // 3. Disable auto-brightness again
      settingsNotifier.updateAutoBrightness(false);

      // 4. Cycle preset backward
      settingsNotifier.cyclePreset(brighter: false);
      map = container.read(settingsProvider).value!;

      expect(map['all']!.isAutoBrightnessEnabled, true);
    });

    test('cyclePreset synchronizes all monitors to master preset and order', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      final selectionNotifier = container.read(selectedMonitorsProvider.notifier);
      await container.read(settingsProvider.future);

      // Set individual preset for DISPLAY1
      selectionNotifier.selectOnly(r'\\.\DISPLAY1');
      settingsNotifier.setActivePreset(PresetType.dimmest);

      // Set individual preset for DISPLAY2
      selectionNotifier.selectOnly(r'\\.\DISPLAY2');
      settingsNotifier.setActivePreset(PresetType.brightest);

      // Now cycle preset
      settingsNotifier.cyclePreset(brighter: true);

      final map = container.read(settingsProvider).value!;
      final masterPreset = map['all']!.activePreset;
      final masterUserPresetId = map['all']!.activeUserPresetId;

      // Every monitor entry must match the master active preset
      for (final entry in map.entries) {
        expect(entry.value.activePreset, masterPreset);
        expect(entry.value.activeUserPresetId, masterUserPresetId);
        expect(entry.value.isAutoBrightnessEnabled, true);
      }
    });

    test('adjustManualBrightness disables auto-brightness and updates manual value', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);

      settingsNotifier.updateAutoBrightness(true);
      expect(container.read(autoBrightnessAdjustmentProvider), true);

      settingsNotifier.adjustManualBrightness(10.0);

      final map = container.read(settingsProvider).value!;
      expect(map['all']!.isAutoBrightnessEnabled, false);
      expect(container.read(autoBrightnessAdjustmentProvider), false);
    });

    test('Hotkey JSON footprint is deterministic with jsonEncode', () {
      final settings = SettingsState(
        nextPresetHotKey: const {'key': 'Key N', 'modifiers': ['control']},
        prevPresetHotKey: const {'key': 'Key P', 'modifiers': ['control']},
        brightnessUpHotKey: const {'key': 'Arrow Up', 'modifiers': ['control', 'alt']},
        brightnessStepUp: 5.0,
        brightnessStepDown: 5.0,
      );

      final footprint1 = jsonEncode([
        settings.nextPresetHotKey,
        settings.prevPresetHotKey,
        settings.brightnessUpHotKey,
        settings.brightnessDownHotKey,
        settings.autoBrightnessHotKey,
        settings.brightnessStepUp,
        settings.brightnessStepDown,
      ]);

      final footprint2 = jsonEncode([
        settings.nextPresetHotKey,
        settings.prevPresetHotKey,
        settings.brightnessUpHotKey,
        settings.brightnessDownHotKey,
        settings.autoBrightnessHotKey,
        settings.brightnessStepUp,
        settings.brightnessStepDown,
      ]);

      expect(footprint1, equals(footprint2));
      expect(footprint1, contains('Key N'));
    });
  });
}
