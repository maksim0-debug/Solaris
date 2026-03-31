import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:flutter/foundation.dart';

class HotkeyService {
  final Ref ref;
  bool _isInitialized = false;

  HotkeyService(this.ref);

  Future<void> init() async {
    if (_isInitialized) return;

    // Ensure hotkey_manager is initialized
    await hotKeyManager.unregisterAll();
    _isInitialized = true;

    // Listen to settings changes to update hotkey registrations
    ref.listen<AsyncValue<Map<String, SettingsState>>>(settingsProvider, (
      previous,
      next,
    ) {
      next.whenData((settingsMap) {
        final settings = settingsMap['all'] ?? SettingsState();
        _updateRegistrations(settings);
      });
    }, fireImmediately: true);
  }

  Future<void> _updateRegistrations(SettingsState settings) async {
    // Unregister all first to avoid conflicts or duplicates
    await hotKeyManager.unregisterAll();

    // Register Brighter Hotkey
    if (settings.brighterHotKey != null) {
      try {
        final hotKey = HotKey.fromJson(settings.brighterHotKey!);
        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (hotKey) {
            debugPrint('Hotkey pressed: Brighter (${hotKey.toJson()})');
            ref.read(settingsProvider.notifier).cyclePreset(brighter: true);
          },
        );
        debugPrint(
          'Successfully registered Brighter hotkey: ${hotKey.toJson()}',
        );
      } catch (e) {
        debugPrint('Error registering brighter hotkey: $e');
      }
    }

    // Register Darker Hotkey
    if (settings.darkerHotKey != null) {
      try {
        final hotKey = HotKey.fromJson(settings.darkerHotKey!);
        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (hotKey) {
            debugPrint('Hotkey pressed: Darker (${hotKey.toJson()})');
            ref.read(settingsProvider.notifier).cyclePreset(brighter: false);
          },
        );
        debugPrint('Successfully registered Darker hotkey: ${hotKey.toJson()}');
      } catch (e) {
        debugPrint('Error registering darker hotkey: $e');
      }
    }
  }
}

final hotkeyServiceProvider = Provider((ref) => HotkeyService(ref));
