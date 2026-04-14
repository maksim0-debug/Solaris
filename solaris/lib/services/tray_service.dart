import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:solaris/l10n/app_localizations.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  Future<void> init() async {
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
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'open_window') {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await trayManager.destroy();
      exit(0);
    }
  }
}
