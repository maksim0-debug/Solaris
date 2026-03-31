import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

// No import of providers.dart to avoid circular dependency

class BrightnessService {
  final Map<String, int> _currentHardwareBrightness = {};
  final Map<String, Timer?> _adjustmentTimers = {};

  final Map<String, int> _targetBrightness = {};

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
        _targetBrightness[monitor.deviceName] = target;

        if (_adjustmentTimers[monitor.deviceName] == null) {
          _runTransitionLoop(
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
  }

  Future<void> _runTransitionLoop(
    String deviceName,
    int initialTarget,
    List<MonitorInfo> monitors,
    MonitorService monitorService,
    void Function(String, int) updateBrightnessCallback, {
    bool isUIVisible = true,
  }) async {
    if (_adjustmentTimers[deviceName] != null) return;

    _adjustmentTimers[deviceName] = Timer(Duration.zero, () {});

    try {
      int? currentFromList;
      try {
        currentFromList = monitors
            .firstWhere((m) => m.deviceName == deviceName)
            .realBrightness;
      } catch (_) {}

      int current =
          _currentHardwareBrightness[deviceName] ??
          currentFromList ??
          initialTarget;

      while (true) {
        final target = _targetBrightness[deviceName] ?? initialTarget;
        final diff = (target - current).abs();

        if (diff == 0) break;

        if (!isUIVisible) {
          current = target;
        } else {
          final step = diff > 20 ? 4 : 2;
          if (current < target) {
            current = (current + step).clamp(0, target).toInt();
          } else {
            current = (current - step).clamp(target, 100).toInt();
          }
        }

        _currentHardwareBrightness[deviceName] = current;

        final int valToReport = current;
        Future.delayed(
          Duration.zero,
          () => updateBrightnessCallback(deviceName, valToReport),
        );

        await monitorService.setBrightness(deviceName, current);

        if (current == target) break;

        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _adjustmentTimers[deviceName]?.cancel();
      _adjustmentTimers.remove(deviceName);
    }
  }
}
