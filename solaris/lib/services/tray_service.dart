import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/app_shutdown_service.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  ProviderContainer? _container;

  Future<void> init([ProviderContainer? container]) async {
    _container = container;
    if (!Platform.isWindows) return;

    try {
      debugPrint('Initializing tray...');
      await trayManager.setIcon('assets/icon/icon.ico');
      await trayManager.setToolTip('Solaris');

      final Menu menu = Menu(
        items: [
          MenuItem(key: 'open_window', label: 'Открыть'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Выход'),
        ],
      );
      await trayManager.setContextMenu(menu);
      trayManager.addListener(this);
      debugPrint('Tray initialized successfully');
    } catch (e) {
      debugPrint('Error initializing tray: $e');
    }
  }

  Future<void> updateLabels(AppLocalizations l10n) async {
    if (!Platform.isWindows) return;

    try {
      final Menu menu = Menu(
        items: [
          MenuItem(key: 'open_window', label: l10n.trayOpen),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: l10n.trayExit),
        ],
      );
      await trayManager.setContextMenu(menu);
      debugPrint('Tray labels updated: ${l10n.trayOpen}, ${l10n.trayExit}');
    } catch (e) {
      debugPrint('Error updating tray labels: $e');
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await _restoreWindowFromTray();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'open_window') {
      await _restoreWindowFromTray();
    } else if (menuItem.key == 'exit_app') {
      if (_container != null) {
        final shutdownService = AppShutdownService(_container!);
        await shutdownService.performShutdown();
      } else {
        await trayManager.destroy();
        exit(0);
      }
    }
  }

  /// Restore the window from the system tray with anti-flicker strategy.
  ///
  /// When the app is hidden to tray, the entire UI subtree is destroyed
  /// (replaced with SizedBox.shrink) to free ~50-80 MB of RAM. Restoring
  /// requires rebuilding the full widget tree, which takes 1-2 frames.
  ///
  /// To prevent visible flicker (white flash or partially rendered UI):
  /// 1. Switch lifecycle to visible (triggers widget tree rebuild)
  /// 2. Wait 150ms for the first frame to be painted
  /// 3. Only then show the window to the user
  Future<void> _restoreWindowFromTray() async {
    _container?.read(appLifecycleProvider.notifier).setVisible();

    // Allow the Flutter engine to rebuild and paint the first frame
    // before making the window visible to the user
    await Future<void>.delayed(const Duration(milliseconds: 150));

    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }
}
