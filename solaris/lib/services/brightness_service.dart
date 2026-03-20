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
  }) {
    final target = targetValue.round();
    
    for (final monitor in monitors) {
      if (selection == 'all' || selection == monitor.deviceName) {
        _startSmoothTransition(
          monitor.deviceName, 
          target, 
          monitors, 
          monitorService, 
          updateBrightnessCallback
        );
      }
    }
  }

  void _startSmoothTransition(
    String deviceName, 
    int target, 
    List<MonitorInfo> monitors,
    MonitorService monitorService,
    void Function(String, int) updateBrightnessCallback,
  ) {
    _adjustmentTimers[deviceName]?.cancel();
    
    // Find monitor in list to get its current brightness
    int? currentFromList;
    try {
      currentFromList = monitors.firstWhere((m) => m.deviceName == deviceName).realBrightness;
    } catch (_) {}

    int current = _currentHardwareBrightness[deviceName] ?? 
              currentFromList ?? 
              target;

    if (current == target) return;

    _adjustmentTimers[deviceName] = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (current < target) {
        current++;
      } else if (current > target) {
        current--;
      }

      _currentHardwareBrightness[deviceName] = current;
      updateBrightnessCallback(deviceName, current);
      monitorService.setBrightness(deviceName, current);

      if (current == target) {
        timer.cancel();
        _adjustmentTimers[deviceName] = null;
      }
    });
  }
}
