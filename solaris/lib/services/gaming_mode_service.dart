import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';

class GamingModeService extends Notifier<bool> {
  static const _methodChannel = MethodChannel('com.solaris.monitor/names');
  static const _eventChannel = EventChannel('com.solaris.monitor/events');

  StreamSubscription<dynamic>? _subscription;

  // Default Stage 4 Blacklist (Apps that might be fullscreen but aren't games)
  static const List<String> defaultBlacklist = [
    'chrome.exe',
    'explorer.exe',
    'devenv.exe', // Visual Studio
    'code.exe', // VS Code
    'msedge.exe',
    'firefox.exe',
    'opera.exe',
    'browser.exe',
    'applicationframehost.exe', // Windows UI elements
    'shellexperiencehost.exe',
    'searchhost.exe',
    'telegram.exe', // False positive (Media Player)
    'sharex.exe', // False positive
    'vlc.exe',
    'mpc-hc64.exe',
    'potplayer64.exe',
    'zoom.exe',
  ];

  @override
  bool build() {
    // Watch settings to automatically sync blacklist/whitelist to native code
    final settingsAsync = ref.watch(settingsProvider);

    settingsAsync.whenData((Map<String, SettingsState> settingsMap) {
      final settings = settingsMap['all'] ?? SettingsState();

      // Sync Whitelist
      _updateWhitelistNative(settings.gameModeWhitelist);

      // Sync Blacklist (Default + User)
      _updateBlacklistNative([
        ...defaultBlacklist,
        ...settings.gameModeBlacklist,
      ]);
    });

    _init();

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return false;
  }

  void _init() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is bool) {
          state = event;
          dev.log('Gaming Mode Changed: $state', name: 'GamingModeService');
        }
      },
      onError: (Object error) {
        dev.log(
          'Error in GamingMode EventChannel: $error',
          name: 'GamingModeService',
        );
      },
    );
  }

  Future<void> _updateWhitelistNative(List<String> whitelist) async {
    try {
      await _methodChannel.invokeMethod('updateWhitelist', whitelist);
    } catch (e) {
      dev.log('Failed to update whitelist: $e', name: 'GamingModeService');
    }
  }

  Future<void> _updateBlacklistNative(List<String> blacklist) async {
    try {
      await _methodChannel.invokeMethod('updateBlacklist', blacklist);
    } catch (e) {
      dev.log('Failed to update blacklist: $e', name: 'GamingModeService');
    }
  }

  /// Manually update whitelist (e.g. from UI)
  Future<void> updateWhitelist(List<String> whitelist) async {
    await _updateWhitelistNative(whitelist);
  }

  /// Manually update blacklist (e.g. from UI)
  Future<void> updateBlacklist(List<String> blacklist) async {
    await _updateBlacklistNative(blacklist);
  }
}

final gamingModeProvider = NotifierProvider<GamingModeService, bool>(() {
  return GamingModeService();
});
