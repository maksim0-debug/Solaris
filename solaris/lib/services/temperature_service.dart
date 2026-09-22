import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

class TemperatureService {
  final Map<String, int> _currentHardwareTemperature = {};
  Map<String, int> get currentHardwareTemperature =>
      Map.unmodifiable(_currentHardwareTemperature);

  final Map<String, int?> _targetTemperatures = {};

  final Map<String, int> _lastTempSentTime = {};

  bool _isResetLocked = false;
  bool get isResetLocked => _isResetLocked;

  void lockTemperatureControl() {
    _isResetLocked = true;
  }

  void unlockTemperatureControl() {
    _isResetLocked = false;
  }

  final Map<String, Timer?> _throttleTrailingTimers = {};

  void stopTemperatureControlForDevice(String deviceName) {
    _throttleTrailingTimers[deviceName]?.cancel();
    _throttleTrailingTimers.remove(deviceName);
    _targetTemperatures[deviceName] = null; // Signal loop to stop
  }

  Future<void> resetTemperatureNow({
    String selection = 'all',
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateTemperatureCallback,
  }) async {
    if (selection == 'all') {
      for (final timer in _throttleTrailingTimers.values) {
        timer?.cancel();
      }
      _throttleTrailingTimers.clear();
    } else {
      _throttleTrailingTimers[selection]?.cancel();
      _throttleTrailingTimers.remove(selection);
    }

    if (monitors.isEmpty) return;

    final targetMonitors = (selection == 'all')
        ? monitors
        : monitors
              .where((m) => m.deviceName == selection || m.id == selection)
              .toList();

    for (final monitor in targetMonitors) {
      stopTemperatureControlForDevice(monitor.deviceName);
      _currentHardwareTemperature[monitor.deviceName] = 6500;
      updateTemperatureCallback(monitor.deviceName, 6500);
    }

    await monitorService.resetMonitorTemperature(selection);
  }

  Future<void> setTemperatureInstant({
    String selection = 'all',
    required double targetValue,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateTemperatureCallback,
  }) async {
    final target = targetValue.round();
    if (_isResetLocked && target != 6500) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    if (monitors.isEmpty) return;

    final targetMonitors = (selection == 'all')
        ? monitors
        : monitors
              .where((m) => m.deviceName == selection || m.id == selection)
              .toList();

    // Deduplication check: If all target monitors are already at target and no trailing
    // timer is pending, avoid redundant native GPU Gamma Ramp calls.
    final bool isAlreadyAtTarget =
        targetMonitors.isNotEmpty &&
        _throttleTrailingTimers[selection] == null &&
        targetMonitors.every(
          (m) => _currentHardwareTemperature[m.deviceName] == target,
        );

    if (isAlreadyAtTarget) {
      for (final monitor in targetMonitors) {
        updateTemperatureCallback(monitor.deviceName, target);
      }
      return;
    }

    for (final monitor in targetMonitors) {
      // Stop any active smooth transition
      stopTemperatureControlForDevice(monitor.deviceName);
      _currentHardwareTemperature[monitor.deviceName] = target;
      updateTemperatureCallback(monitor.deviceName, target);
    }

    // Throttle check: Software gamma is fast, but 60Hz bridge calls can be overhead.
    // 20ms (50Hz) provides responsiveness while trailing edge ensures final slider point is never lost.
    final throttleKey = selection;
    final lastSent = _lastTempSentTime[throttleKey] ?? 0;
    final shouldThrottle = (now - lastSent < 20) && target != 6500;

    if (shouldThrottle) {
      _throttleTrailingTimers[throttleKey]?.cancel();
      _throttleTrailingTimers[throttleKey] = Timer(
        const Duration(milliseconds: 25),
        () async {
          _throttleTrailingTimers.remove(throttleKey);
          _lastTempSentTime[throttleKey] =
              DateTime.now().millisecondsSinceEpoch;
          if (target == 6500) {
            await monitorService.resetMonitorTemperature(selection);
          } else {
            await monitorService.setMonitorTemperature(selection, target);
          }
        },
      );
      return;
    }

    _throttleTrailingTimers[throttleKey]?.cancel();
    _throttleTrailingTimers.remove(throttleKey);
    _lastTempSentTime[throttleKey] = now;
    if (target == 6500) {
      await monitorService.resetMonitorTemperature(selection);
    } else {
      await monitorService.setMonitorTemperature(selection, target);
    }
  }

  final Map<String, bool> _isLoopRunning = {};

  void applyTemperatureSmoothly({
    String selection = 'all',
    required double targetValue,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateTemperatureCallback,
    bool isUIVisible = true,
  }) {
    if (selection == 'all') {
      for (final timer in _throttleTrailingTimers.values) {
        timer?.cancel();
      }
      _throttleTrailingTimers.clear();
    } else {
      _throttleTrailingTimers[selection]?.cancel();
      _throttleTrailingTimers.remove(selection);
    }

    final target = targetValue.round();
    if (_isResetLocked && target != 6500) {
      return;
    }

    for (final monitor in monitors) {
      if (selection == 'all' ||
          selection == monitor.deviceName ||
          selection == monitor.id) {
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
          if (diff > 1500) {
            step = 400;
          } else if (diff > 800) {
            step = 250;
          } else if (diff > 300) {
            step = 120;
          } else if (diff < 30) {
            step = diff;
          }

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
              _targetTemperatures[deviceName] == null) {
            break;
          }
        }

        // Wait between commands for monitor stability.
        // 120ms (~8 Hz) is plenty for color-temperature smoothness — the eye
        // is far less time-sensitive to hue shifts than to motion — and cuts
        // SetDeviceGammaRamp + MethodChannel traffic ~4x vs the old 30ms.
        await Future<void>.delayed(const Duration(milliseconds: 120));

        // Re-check target after delay
        if (_targetTemperatures[deviceName] == null) break;
      }
    } finally {
      _isLoopRunning[deviceName] = false;
    }
  }
}
