import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

class TemperatureService {
  final Map<String, int> _currentHardwareTemperature = {};
  final Map<String, Timer?> _adjustmentTimers = {};

  final Map<String, int> _targetTemperatures = {};

  void stopTemperatureControlForDevice(String deviceName) {
    _adjustmentTimers[deviceName]?.cancel();
    _adjustmentTimers[deviceName] = null;
    _targetTemperatures.remove(deviceName);
  }

  Future<void> resetTemperatureNow({
    required String selection,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateTemperatureCallback,
  }) async {
    for (final monitor in monitors) {
      if (selection == 'all' || selection == monitor.deviceName) {
        stopTemperatureControlForDevice(monitor.deviceName);
        _currentHardwareTemperature[monitor.deviceName] = 6500;
        updateTemperatureCallback(monitor.deviceName, 6500);
        await monitorService.resetMonitorTemperature(monitor.deviceName);
      }
    }
  }

  final Map<String, bool> _isLoopRunning = {};

  void applyTemperatureSmoothly({
    required String selection,
    required double targetValue,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateTemperatureCallback,
    bool isUIVisible = true,
  }) {
    final target = targetValue.round();

    for (final monitor in monitors) {
      if (selection == 'all' || selection == monitor.deviceName) {
        _targetTemperatures[monitor.deviceName] = target;

        // If no loop is running, start one.
        if (_isLoopRunning[monitor.deviceName] != true) {
          _runTransitionLoop(
            monitor.deviceName,
            target,
            monitors,
            monitorService,
            updateTemperatureCallback,
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
    void Function(String, int) updateTemperatureCallback, {
    bool isUIVisible = true,
  }) async {
    if (_isLoopRunning[deviceName] == true) return;
    _isLoopRunning[deviceName] = true;

    try {
      int? currentFromList;
      try {
        currentFromList = monitors
            .firstWhere((m) => m.deviceName == deviceName)
            .realTemperature;
      } catch (_) {}

      // Start from known hardware state or provided target
      bool isFirstIteration = true;
      int current =
          _currentHardwareTemperature[deviceName] ??
          currentFromList ??
          initialTarget;

      while (true) {
        final targetSnapshot = _targetTemperatures[deviceName];
        // Safety exit if control stopped or device removed
        if (targetSnapshot == null) break;

        final target = targetSnapshot;
        final diff = (target - current).abs();

        // If we are at the target, check if any new target was set while we were waiting.
        // On the first iteration, we always proceed once to ensure alignment.
        if (diff == 0 && !isFirstIteration) {
          if (_targetTemperatures[deviceName] == target) break;

          // New target arrived but diff is 0?
          // Add a small yield to prevent main isolate freeze.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          continue;
        }

        if (!isUIVisible) {
          current = target;
        } else {
          // Adaptive step size: smoother for small changes
          int step = 80;
          if (diff > 1500)
            step = 400;
          else if (diff > 800)
            step = 250;
          else if (diff > 300)
            step = 120;
          else if (diff < 30)
            step = diff;

          if (diff <= step) {
            current = target;
          } else if (current < target) {
            current += step;
          } else {
            current -= step;
          }
        }

        _currentHardwareTemperature[deviceName] = current;

        // Wrap callback to prevent "update during build/notify" errors
        final int valToReport = current;
        Future.delayed(
          Duration.zero,
          () => updateTemperatureCallback(deviceName, valToReport),
        );

        // Use the hardware command
        if (current == 6500) {
          await monitorService.resetMonitorTemperature(deviceName);
        } else {
          await monitorService.setMonitorTemperature(deviceName, current);
        }

        isFirstIteration = false;

        if (current == target) {
          // Double check if target changed during the await.
          // If null, it means stopTemperatureControl was called.
          if (_targetTemperatures[deviceName] == target ||
              _targetTemperatures[deviceName] == null)
            break;
        }

        // Wait between commands for monitor stability.
        // 130ms for even better compatibility with slow DDC/CI controllers.
        await Future<void>.delayed(const Duration(milliseconds: 130));
      }
    } finally {
      _isLoopRunning[deviceName] = false;
    }
  }
}
