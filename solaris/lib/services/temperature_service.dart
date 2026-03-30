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

    // Default to 6500 if unknown initially
    int current = _currentHardwareTemperature[deviceName] ?? 6500;

    if (current == target) return;

    if (!isUIVisible) {
      _currentHardwareTemperature[deviceName] = target;
      updateTemperatureCallback(deviceName, target);
      monitorService.setMonitorTemperature(deviceName, target);
      _adjustmentTimers[deviceName] = null;
      return;
    }

    _adjustmentTimers[deviceName] = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        int step = 50; // Transition speed
        if ((current - target).abs() <= step) {
          current = target;
        } else if (current < target) {
          current += step;
        } else {
          current -= step;
        }

        _currentHardwareTemperature[deviceName] = current;
        updateTemperatureCallback(deviceName, current);
        monitorService.setMonitorTemperature(deviceName, current);

        if (current == target) {
          timer.cancel();
          _adjustmentTimers[deviceName] = null;
        }
      },
    );
  }
}
