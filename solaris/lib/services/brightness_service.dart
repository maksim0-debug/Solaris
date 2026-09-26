import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

// No import of providers.dart to avoid circular dependency

class BrightnessService {
  final Map<String, int> _currentHardwareBrightness = {};
  final Map<String, Timer?> _adjustmentTimers = {};
  final Map<String, bool> _isManualTransition = {};
  final Map<String, bool> _canDimSoftware = {};

  final Map<String, int> _targetBrightness = {};
  final Map<String, double> _lastCalculatedFloat = {};

  void applyBrightnessSmoothly({
    required String selection,
    required double targetValue,
    required List<MonitorInfo> monitors,
    required MonitorService monitorService,
    required void Function(String, int) updateBrightnessCallback,
    Map<String, double>? offsets,
    bool isUIVisible = true,
    bool isManual = false,
    bool isSoftwareDimmingEnabled = true,
  }) {
    for (final monitor in monitors) {
      if (selection == 'all' || selection == monitor.deviceName) {
        final deviceName = monitor.deviceName;
        final offset = offsets?[deviceName] ?? 0.0;
        final bool canDimSoftware = isSoftwareDimmingEnabled && isManual;
        final double minVal = canDimSoftware ? -100.0 : 0.0;
        final rawTarget = (targetValue + offset).clamp(minVal, 100.0);

        // HYSTERESIS: Filter out noise to prevent flicker.
        // Sentinel -999.0 avoids collision with the valid -100.0 lower bound.
        final double lastCalculated =
            _lastCalculatedFloat[deviceName] ?? -999.0;
        if (!isManual && (rawTarget - lastCalculated).abs() < 1.5) {
          continue; // Ignore micro-fluctuations
        }

        _lastCalculatedFloat[deviceName] = rawTarget;
        final target = rawTarget.round();

        _targetBrightness[deviceName] = target;
        _isManualTransition[deviceName] = isManual;
        _canDimSoftware[deviceName] = canDimSoftware;

        if (_adjustmentTimers[deviceName] == null) {
          _runTransitionLoop(
            deviceName,
            target,
            monitors,
            monitorService,
            updateBrightnessCallback,
            isUIVisible: isUIVisible,
            isManual: isManual,
            canDimSoftware: canDimSoftware,
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
    bool isManual = false,
    bool canDimSoftware = false,
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
        final currentIsManual = _isManualTransition[deviceName] ?? isManual;
        final currentCanDim = _canDimSoftware[deviceName] ?? canDimSoftware;
        final diff = (target - current).abs();

        if (diff == 0) break;

        final int minVal = currentCanDim ? -100 : 0;
        final int safeLower = minVal < target ? minVal : target;

        if (!isUIVisible && !currentIsManual) {
          current = target;
        } else if (currentIsManual) {
          // Manual control or visible UI (fast transition, 60-120%/sec)
          final step = diff > 20 ? 12 : 6;
          if (current < target) {
            current = (current + step).clamp(safeLower, target).toInt();
          } else {
            current = (current - step).clamp(target, 100).toInt();
          }
        } else {
          // Automatic background adjustment (gradual transition, 3% every 150-200ms)
          final step = 3;
          if (current < target) {
            current = (current + step).clamp(safeLower, target).toInt();
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

        // ALWAYS check against the most recent target, to avoid race conditions
        // where target updates while we were waiting for setBrightness.
        if (current == _targetBrightness[deviceName]) break;

        // Wait 100ms for manual changes, 150ms for automatic adjustments
        await Future<void>.delayed(
          Duration(milliseconds: currentIsManual ? 100 : 150),
        );
      }
    } finally {
      // Free the timer so it can be restarted if new requests come in
      _adjustmentTimers[deviceName]?.cancel();
      _adjustmentTimers.remove(deviceName);
      _isManualTransition.remove(deviceName);
      _canDimSoftware.remove(deviceName);
    }
  }
}
