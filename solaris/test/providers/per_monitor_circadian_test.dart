import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/preset_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-Monitor Settings & Selection Provider Tests', () {
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

    test('SelectedMonitorsNotifier prevents empty selection and defaults to all', () {
      final notifier = container.read(selectedMonitorsProvider.notifier);

      expect(container.read(selectedMonitorsProvider), {'all'});

      // Select specific monitor
      notifier.toggle(r'\\.\DISPLAY1');
      expect(container.read(selectedMonitorsProvider), {r'\\.\DISPLAY1'});

      // Toggle off specific monitor -> should fallback to {'all'}
      notifier.toggle(r'\\.\DISPLAY1');
      expect(container.read(selectedMonitorsProvider), {'all'});
    });

    test('SettingsNotifier updates specific monitor without crashing on new key', () async {
      final notifier = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);

      // Select specific monitor
      container.read(selectedMonitorsProvider.notifier).selectOnly(r'\\.\DISPLAY2');

      // Set active preset for DISPLAY2
      notifier.setActivePreset(PresetType.dimmest);

      final settingsMap = container.read(settingsProvider).value;
      expect(settingsMap, isNotNull);
      expect(settingsMap![r'\\.\DISPLAY2'], isNotNull);
      expect(settingsMap[r'\\.\DISPLAY2']!.activePreset, PresetType.dimmest);

      // Global 'all' preset remains bright
      expect(settingsMap['all']!.activePreset, PresetType.bright);
    });

    test('Selecting ALL MONITORS syncs per-monitor preset back to global preset', () async {
      final settingsNotifier = container.read(settingsProvider.notifier);
      final selectionNotifier = container.read(selectedMonitorsProvider.notifier);
      await container.read(settingsProvider.future);

      // 1. Select DISPLAY2 and assign dimmest
      selectionNotifier.selectOnly(r'\\.\DISPLAY2');
      settingsNotifier.setActivePreset(PresetType.dimmest);

      var map = container.read(settingsProvider).value!;
      expect(map[r'\\.\DISPLAY2']!.activePreset, PresetType.dimmest);
      expect(map['all']!.activePreset, PresetType.bright);

      // 2. Select 'all' -> triggers syncAllMonitorsToGlobal
      selectionNotifier.toggle('all');

      map = container.read(settingsProvider).value!;
      expect(map[r'\\.\DISPLAY2']!.activePreset, PresetType.bright);
      expect(map['all']!.activePreset, PresetType.bright);
      expect(map[r'\\.\DISPLAY2']!.activeUserPresetId, isNull);
    });

    test('curvePoints fallback returns curvesMap when activeUserPresetId is invalid', () async {
      await container.read(settingsProvider.future);

      final state = SettingsState(
        activePreset: PresetType.brightest,
        activeUserPresetId: 'non_existent_preset_id',
      );

      // Should fall back to curvesMap[brightest], NOT throw or return userPresets.first
      expect(state.curvePoints, state.curvesMap[PresetType.brightest]);
    });

    test('Toggling auto-brightness off preserves user manual brightness setting', () async {
      await container.read(settingsProvider.future);

      // 1. User sets manual brightness to 20.0
      container.read(manualBrightnessProvider.notifier).update(20.0);
      expect(container.read(manualBrightnessProvider), 20.0);

      // 2. Auto-brightness enabled -> manualBrightnessProvider must remain 20.0
      container.read(settingsProvider.notifier).updateAutoBrightness(true);
      expect(container.read(manualBrightnessProvider), 20.0);

      // 3. Auto-brightness disabled -> manualBrightnessProvider must still be 20.0
      container.read(settingsProvider.notifier).updateAutoBrightness(false);
      expect(container.read(manualBrightnessProvider), 20.0);
    });
  });
}
