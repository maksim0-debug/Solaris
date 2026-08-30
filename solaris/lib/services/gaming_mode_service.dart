import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';

class GamingModeService extends Notifier<bool> {
  static const _methodChannel = MethodChannel('com.solaris.monitor/names');

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
    // Listen to settings to automatically sync blacklist/whitelist to native code
    ref.listen<AsyncValue<Map<String, SettingsState>>>(settingsProvider, (
      previous,
      next,
    ) {
      next.whenData((Map<String, SettingsState> settingsMap) {
        final settings = settingsMap['all'] ?? SettingsState();

        // Sync Whitelist
        _updateWhitelistNative(settings.gameModeWhitelist);

        // Sync Blacklist (Default + User)
        _updateBlacklistNative([
          ...defaultBlacklist,
          ...settings.gameModeBlacklist,
        ]);

        // Sync Exit Delay
        _updateExitDelayNative(settings.gameModeExitDelaySeconds);
      });
    }, fireImmediately: true);

    return false;
  }

  /// Update gaming state from ActiveProcessService to avoid EventSink overwrite in C++
  void setGamingState(bool isGaming) {
    if (state != isGaming) {
      state = isGaming;
      debugPrint('[GamingModeService] Gaming Mode Changed: $state');
    }
  }

  Future<void> _updateWhitelistNative(List<String> whitelist) async {
    try {
      await _methodChannel.invokeMethod('updateWhitelist', whitelist);
    } catch (e) {
      debugPrint('[GamingModeService] Failed to update whitelist: $e');
    }
  }

  Future<void> _updateBlacklistNative(List<String> blacklist) async {
    try {
      await _methodChannel.invokeMethod('updateBlacklist', blacklist);
    } catch (e) {
      debugPrint('[GamingModeService] Failed to update blacklist: $e');
    }
  }

  Future<void> _updateExitDelayNative(int seconds) async {
    try {
      await _methodChannel.invokeMethod('setGameModeExitDelay', seconds);
    } catch (e) {
      debugPrint('[GamingModeService] Failed to update exit delay: $e');
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
