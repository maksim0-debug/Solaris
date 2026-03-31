import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

class GamingModeService extends Notifier<bool> {
  static const _methodChannel = MethodChannel('com.solaris.monitor/names');
  static const _eventChannel = EventChannel('com.solaris.monitor/events');
  
  StreamSubscription<dynamic>? _subscription;

  // Default Stage 4 Blacklist (Apps that might be fullscreen but aren't games)
  static const List<String> defaultBlacklist = [
    'chrome.exe',
    'explorer.exe',
    'devenv.exe', // Visual Studio
    'code.exe',   // VS Code
    'msedge.exe',
    'firefox.exe',
    'opera.exe',
    'browser.exe',
    'applicationframehost.exe', // Windows UI elements
    'shellexperiencehost.exe',
    'searchhost.exe',
  ];

  @override
  bool build() {
    // Standard initialization
    _init();
    
    // Automatically cancel subscription when provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return false;
  }

  Future<void> _init() async {
    // 1. Initialize native blacklist
    await updateBlacklist(defaultBlacklist);
    
    // 2. Listen to gaming mode changes
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is bool) {
          state = event;
          dev.log('Gaming Mode Changed: $state', name: 'GamingModeService');
        }
      },
      onError: (Object error) {
        dev.log('Error in GamingMode EventChannel: $error', name: 'GamingModeService');
      },
    );
  }

  /// Updates the user-defined whitelist in native code (Stage 3).
  Future<void> updateWhitelist(List<String> whitelist) async {
    try {
      await _methodChannel.invokeMethod('updateWhitelist', whitelist);
    } on PlatformException catch (e) {
      dev.log('Failed to update whitelist: ${e.message}', name: 'GamingModeService');
    }
  }

  /// Updates the Stage 4 blacklist in native code.
  Future<void> updateBlacklist(List<String> blacklist) async {
    try {
      await _methodChannel.invokeMethod('updateBlacklist', blacklist);
    } on PlatformException catch (e) {
      dev.log('Failed to update blacklist: ${e.message}', name: 'GamingModeService');
    }
  }
}

final gamingModeProvider = NotifierProvider<GamingModeService, bool>(() {
  return GamingModeService();
});
