import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';

class BrightnessService {
  final Ref _ref;
  final Map<String, int> _currentHardwareBrightness = {};
  final Map<String, Timer?> _adjustmentTimers = {};

  BrightnessService(this._ref);

  void applyBrightnessSmoothly(String selection, double targetValue) {
    final target = targetValue.round();
    final monitorsAsync = _ref.read(monitorListProvider);
    
    monitorsAsync.whenData((monitors) {
      for (final monitor in monitors) {
        if (selection == 'all' || selection == monitor.deviceName) {
          _startSmoothTransition(monitor.deviceName, target);
        }
      }
    });
  }

  void _startSmoothTransition(String deviceName, int target) {
    _adjustmentTimers[deviceName]?.cancel();
    
    final monitorService = _ref.read(monitorServiceProvider);
    final monitorNotifier = _ref.read(monitorListProvider.notifier);
    
    // Get current brightness from our cache or from monitor list
    int current = _currentHardwareBrightness[deviceName] ?? 
              _ref.read(monitorListProvider).value?.firstWhere((m) => m.deviceName == deviceName).realBrightness ?? 
              target;

    if (current == target) return;

    _adjustmentTimers[deviceName] = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (current < target) {
        current++;
      } else if (current > target) {
        current--;
      }

      _currentHardwareBrightness[deviceName] = current;
      monitorNotifier.updateBrightness(deviceName, current);
      monitorService.setBrightness(deviceName, current);

      if (current == target) {
        timer.cancel();
        _adjustmentTimers[deviceName] = null;
      }
    });
  }
}

final brightnessServiceProvider = Provider((ref) => BrightnessService(ref));
