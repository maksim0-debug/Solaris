import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/utils/memory_utils.dart';

enum AppVisibilityState { visible, minimized, hidden }

class AppLifecycleNotifier extends Notifier<AppVisibilityState> {
  @override
  AppVisibilityState build() => AppVisibilityState.visible;

  void setVisible() => state = AppVisibilityState.visible;

  void setMinimized() {
    state = AppVisibilityState.minimized;
    MemoryUtils.trimMemory();
  }

  void setHidden() {
    state = AppVisibilityState.hidden;
    MemoryUtils.trimMemory();
  }

  bool get isVisible => state == AppVisibilityState.visible;
}

final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppVisibilityState>(
      AppLifecycleNotifier.new,
    );

final startupArgsProvider = Provider<List<String>>((_) => []);
