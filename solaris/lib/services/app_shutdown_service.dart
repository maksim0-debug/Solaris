import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';

/// Centralized service responsible for performing a clean, graceful shutdown
/// of the application before an update or exit.
class AppShutdownService {
  final ProviderContainer container;

  AppShutdownService(this.container);

  /// Performs a complete graceful shutdown of all sub-systems in strict sequential order.
  ///
  /// Set [exitProcess] to false during unit tests to prevent terminating the test runner.
  Future<void> performShutdown({bool exitProcess = true}) async {
    debugPrint('AppShutdownService: Initiating graceful shutdown...');

    // Step 1: Save any pending settings to disk (bypassing debouncers)
    await _savePendingSettings();

    // Step 2: Unregister all system-wide global hotkeys
    await _unregisterHotkeys();

    // Step 3: Stop the local IPC HTTP server (with force: true to avoid hanging keep-alive sockets)
    await _stopIpcServer();

    // Step 4: Destroy system tray icon
    await _destroyTray();

    // Pause 150ms to allow Windows OS Shell_NotifyIcon IPC loop to clean up the tray icon
    // and avoid creating "ghost" tray icons.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // Step 5: Reset monitor color temperature/gamma ramp back to neutral (6500K)
    await _resetMonitorGamma();

    debugPrint('AppShutdownService: Shutdown sequence complete.');

    // Step 6: Terminate process if requested
    if (exitProcess) {
      exit(0);
    }
  }

  Future<void> _savePendingSettings() async {
    try {
      debugPrint('AppShutdownService: Step 1 - Saving pending settings...');
      await container.read(settingsProvider.notifier).savePendingSettings();
    } catch (e) {
      debugPrint('AppShutdownService: Error saving pending settings: $e');
    }
  }

  Future<void> _unregisterHotkeys() async {
    try {
      debugPrint('AppShutdownService: Step 2 - Unregistering global hotkeys...');
      await hotKeyManager.unregisterAll();
    } catch (e) {
      debugPrint('AppShutdownService: Error unregistering hotkeys: $e');
    }
  }

  Future<void> _stopIpcServer() async {
    try {
      debugPrint('AppShutdownService: Step 3 - Stopping local IPC server...');
      final ipcNotifier = container.read(localIpcServiceProvider.notifier);
      await ipcNotifier.stop();
    } catch (e) {
      debugPrint('AppShutdownService: Error stopping IPC server: $e');
    }
  }

  Future<void> _destroyTray() async {
    try {
      debugPrint('AppShutdownService: Step 4 - Destroying tray icon...');
      await trayManager.destroy();
    } catch (e) {
      debugPrint('AppShutdownService: Error destroying tray icon: $e');
    }
  }

  Future<void> _resetMonitorGamma() async {
    try {
      debugPrint('AppShutdownService: Step 5 - Resetting monitor gamma to neutral...');
      final monitorService = container.read(monitorServiceProvider);
      await monitorService.resetAllMonitorsTemperature();
      await container
          .read(isColorTemperatureEnabledProvider.notifier)
          .resetToNeutralNow();
      // Allow 200ms for OS GPU driver to settle gamma ramp changes across all displays before exit(0)
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('AppShutdownService: Error resetting monitor gamma: $e');
    }
  }
}

/// Provider definition for [AppShutdownService].
final appShutdownServiceProvider =
    Provider.family<AppShutdownService, ProviderContainer>(
  (ref, container) => AppShutdownService(container),
);
