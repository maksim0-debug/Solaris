import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';

class HotkeyService {
  final Ref ref;

  HotkeyService(this.ref);

  String? _lastHotkeysJson;
  bool _isUpdating = false;

  Future<void> init() async {
    // Listen to settings changes to update hotkey registrations
    ref.listen<AsyncValue<Map<String, SettingsState>>>(
      settingsProvider,
      (previous, next) {
        next.whenData((settingsMap) {
          // Use microtask to avoid blocking the state update process
          // and prevent potential deadlocks in hotkey event loop
          Future.microtask(() => _updateRegistrations());
        });
      },
      fireImmediately: true,
    );
  }

  Future<void> _updateRegistrations() async {
    final settingsMap = ref.read(settingsProvider).value;
    if (settingsMap == null) return;

    final settings = settingsMap['all'] ?? SettingsState();

    // Create a unique footprint of the current hotkey configuration
    final currentHotkeysJson = [
      settings.nextPresetHotKey,
      settings.prevPresetHotKey,
      settings.brightnessUpHotKey,
      settings.brightnessDownHotKey,
      settings.brightnessStepUp,
      settings.brightnessStepDown,
    ].toString();

    // Only proceed if the hotkey definitions themselves have changed
    if (_lastHotkeysJson == currentHotkeysJson) return;

    // Prevent concurrent updates
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      await hotKeyManager.unregisterAll();

      // Next Preset
      if (settings.nextPresetHotKey != null) {
        try {
          final hotKey = HotKey.fromJson(settings.nextPresetHotKey!);
          await hotKeyManager.register(
            hotKey,
            keyDownHandler: (hotKey) {
              debugPrint('Hotkey pressed: Next Preset (${hotKey.toJson()})');
              ref.read(settingsProvider.notifier).cyclePreset(brighter: true);
            },
          );
        } catch (e) {
          debugPrint('Error registering next preset hotkey: $e');
        }
      }

      // Previous Preset
      if (settings.prevPresetHotKey != null) {
        try {
          final hotKey = HotKey.fromJson(settings.prevPresetHotKey!);
          await hotKeyManager.register(
            hotKey,
            keyDownHandler: (hotKey) {
              debugPrint('Hotkey pressed: Prev Preset (${hotKey.toJson()})');
              ref.read(settingsProvider.notifier).cyclePreset(brighter: false);
            },
          );
        } catch (e) {
          debugPrint('Error registering prev preset hotkey: $e');
        }
      }

      // Brightness Up
      if (settings.brightnessUpHotKey != null) {
        try {
          final hotKey = HotKey.fromJson(settings.brightnessUpHotKey!);
          await hotKeyManager.register(
            hotKey,
            keyDownHandler: (hotKey) {
              debugPrint('Hotkey pressed: Brightness Up (${hotKey.toJson()})');
              ref
                  .read(settingsProvider.notifier)
                  .adjustManualBrightness(settings.brightnessStepUp);
            },
          );
        } catch (e) {
          debugPrint('Error registering brightness up hotkey: $e');
        }
      }

      // Brightness Down
      if (settings.brightnessDownHotKey != null) {
        try {
          final hotKey = HotKey.fromJson(settings.brightnessDownHotKey!);
          await hotKeyManager.register(
            hotKey,
            keyDownHandler: (hotKey) {
              debugPrint('Hotkey pressed: Brightness Down (${hotKey.toJson()})');
              ref
                  .read(settingsProvider.notifier)
                  .adjustManualBrightness(-settings.brightnessStepDown);
            },
          );
        } catch (e) {
          debugPrint('Error registering brightness down hotkey: $e');
        }
      }

      _lastHotkeysJson = currentHotkeysJson;
    } finally {
      _isUpdating = false;
    }
  }
}

final hotkeyServiceProvider = Provider((ref) => HotkeyService(ref));
