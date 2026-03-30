import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

class TemperatureService {
  final Map<String, int> _currentHardwareTemperature = {};
  final Map<String, Timer?> _adjustmentTimers = {};

  void stopTemperatureControlForDevice(String deviceName) {
    _adjustmentTimers[deviceName]?.cancel();
    _adjustmentTimers[deviceName] = null;
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
        _startSmoothTransition(
          monitor.deviceName,
          target,
          monitorService,
          updateTemperatureCallback,
          isUIVisible: isUIVisible,
        );
      }
    }
  }

  void _startSmoothTransition(
    String deviceName,
    int target,
    MonitorService monitorService,
    void Function(String, int) updateTemperatureCallback, {
    bool isUIVisible = true,
  }) {
    _adjustmentTimers[deviceName]?.cancel();
    _adjustmentTimers[deviceName] = null;

    // Default to 6500 if unknown initially
    int current = _currentHardwareTemperature[deviceName] ?? 6500;

    // If we're already at the target and not transitioning, nothing to do.
    // BUT if the target is 6500 and we were transitioning or just want to be sure,
    // we send a final reset call.
    if (current == target) {
      if (target == 6500) {
        monitorService.resetMonitorTemperature(deviceName);
      }
      return;
    }

    if (!isUIVisible) {
      _currentHardwareTemperature[deviceName] = target;
      updateTemperatureCallback(deviceName, target);
      if (target == 6500) {
        monitorService.resetMonitorTemperature(deviceName);
      } else {
        monitorService.setMonitorTemperature(deviceName, target);
      }
      return;
    }

    _adjustmentTimers[deviceName] = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        int step = 100; // Transition speed: 1000K per second
        if ((current - target).abs() <= step) {
          current = target;
        } else if (current < target) {
          current += step;
        } else {
          current -= step;
        }

        _currentHardwareTemperature[deviceName] = current;
        updateTemperatureCallback(deviceName, current);

        if (current == target && target == 6500) {
          monitorService.resetMonitorTemperature(deviceName);
        } else {
          monitorService.setMonitorTemperature(deviceName, current);
        }

        if (current == target) {
          timer.cancel();
          _adjustmentTimers[deviceName] = null;
        }
      },
    );
  }
}
