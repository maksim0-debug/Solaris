import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

// No import of providers.dart to avoid circular dependency

class BrightnessService {
  final Map<String, int> _currentHardwareBrightness = {};
  final Map<String, Timer?> _adjustmentTimers = {};

  void applyBrightnessSmoothly({
    required String selection,
    required double targetValue,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateBrightnessCallback,
    bool isUIVisible = true,
  }) {
    final target = targetValue.round();

    for (final monitor in monitors) {
      if (selection == 'all' || selection == monitor.deviceName) {
        _startSmoothTransition(
          monitor.deviceName,
          target,
          monitors,
          monitorService,
          updateBrightnessCallback,
          isUIVisible: isUIVisible,
        );
      }
    }
  }

  void _startSmoothTransition(
    String deviceName,
    int target,
    List<MonitorInfo> monitors,
    MonitorService monitorService,
    void Function(String, int) updateBrightnessCallback, {
    bool isUIVisible = true,
  }) {
    _adjustmentTimers[deviceName]?.cancel();

    // Find monitor in list to get its current brightness
    int? currentFromList;
    try {
      currentFromList = monitors
          .firstWhere((m) => m.deviceName == deviceName)
          .realBrightness;
    } catch (_) {}

    int current =
        _currentHardwareBrightness[deviceName] ?? currentFromList ?? target;

    if (current == target) return;

    // If the UI is hidden, don't use high-frequency timers for smooth transitions.
    // This dramatically reduces CPU usage by avoiding 20 DDC/CI commands per second.
    if (!isUIVisible) {
      _currentHardwareBrightness[deviceName] = target;
      // We still use the callback to keep the provider in sync (though it's gated in the provider itself)
      updateBrightnessCallback(deviceName, target);
      monitorService.setBrightness(deviceName, target);
      _adjustmentTimers[deviceName] = null;
      return;
    }

    _adjustmentTimers[deviceName] = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final diff = (target - current).abs();
        if (diff == 0) {
          timer.cancel();
          _adjustmentTimers[deviceName] = null;
          return;
        }

        // Use slightly larger steps for large transitions to maintain perceived speed
        // while respecting the 100ms hardware interval.
        final step = diff > 20 ? 2 : 1;

        if (current < target) {
          current = (current + step).clamp(0, target).toInt();
        } else if (current > target) {
          current = (current - step).clamp(target, 100).toInt();
        }

        _currentHardwareBrightness[deviceName] = current;
        updateBrightnessCallback(deviceName, current);
        monitorService.setBrightness(deviceName, current);

        if (current == target) {
          timer.cancel();
          _adjustmentTimers[deviceName] = null;
        }
      },
    );
  }
}
