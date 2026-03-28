import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppVisibilityState {
  visible,
  minimized,
  hidden,
}

class AppLifecycleNotifier extends Notifier<AppVisibilityState> {
  @override
  AppVisibilityState build() => AppVisibilityState.visible;

  void setVisible() => state = AppVisibilityState.visible;
  void setMinimized() => state = AppVisibilityState.minimized;
  void setHidden() => state = AppVisibilityState.hidden;

  bool get isVisible => state == AppVisibilityState.visible;
}

final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppVisibilityState>(
  AppLifecycleNotifier.new,
);
