import 'dart:async';
import 'package:solaris/services/monitor_service.dart';

// No import of providers.dart to avoid circular dependency

class BrightnessService {
  final Map<String, int> _currentHardwareBrightness = {};
  final Map<String, Timer?> _adjustmentTimers = {};
  final Map<String, bool> _isManualTransition = {};
  final Map<String, bool> _canDimSoftware = {};
  final Map<String, bool> _isOverlayOnly = {};

  final Map<String, int> _targetBrightness = {};
  final Map<String, double> _lastCalculatedFloat = {};
  final Map<String, void Function(String, int)> _activeBrightnessCallbacks = {};

  void syncHardwareBrightness(String deviceName, int realBrightness) {
    // If the monitor is currently in software dimming mode (< 0) and the incoming
    // reading is at physical floor (0-5% for DDC/CI hardware), preserve the
    // active negative dimming state to prevent flicker and jumping back to floor.
    final current = _currentHardwareBrightness[deviceName];
    if (current != null &&
        current < 0 &&
        realBrightness >= 0 &&
        realBrightness <= MonitorService.hardwareBrightnessFloorThreshold) {
      return;
    }
    _currentHardwareBrightness[deviceName] = realBrightness;
    _lastCalculatedFloat[deviceName] = realBrightness.toDouble();
  }

  int? getCurrentHardwareBrightness(String deviceName) =>
      _currentHardwareBrightness[deviceName];

  void invalidateCache([String? deviceName]) {
    if (deviceName != null) {
      _lastCalculatedFloat.remove(deviceName);
    } else {
      _lastCalculatedFloat.clear();
    }
  }

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
        final bool isOverlayOnly = !monitor.isDdcSupported;
        final bool canDimSoftware =
            isOverlayOnly || (isSoftwareDimmingEnabled && isManual);
        final double minVal = isOverlayOnly
            ? 0.0
            : (canDimSoftware ? -100.0 : 0.0);
        final rawTarget = (targetValue + offset).clamp(minVal, 100.0);

        // HYSTERESIS: Filter out noise to prevent flicker.
        // Sentinel -999.0 avoids collision with the valid -100.0 lower bound.
        // If physical monitor hardware brightness differs from rawTarget by >= 1%,
        // hardware reality takes precedence over calculation hysteresis!
        final double lastCalculated =
            _lastCalculatedFloat[deviceName] ?? -999.0;
        final int? realHardware = monitor.isDdcSupported
            ? monitor.realBrightness
            : (_currentHardwareBrightness[deviceName] ??
                  monitor.realBrightness);
        final bool isHardwareDesynced =
            realHardware != null &&
            (rawTarget < 0 &&
                    realHardware >= 0 &&
                    realHardware <=
                        MonitorService.hardwareBrightnessFloorThreshold
                ? false
                : (rawTarget.round() - realHardware).abs() >= 1);

        if (!isManual &&
            !isHardwareDesynced &&
            (rawTarget - lastCalculated).abs() < 1.5) {
          continue; // Ignore micro-fluctuations
        }

        final target = rawTarget.round();
        if (_currentHardwareBrightness[deviceName] == target &&
            !isHardwareDesynced &&
            (rawTarget - lastCalculated).abs() < 1.0) {
          continue; // Already at target with hardware aligned
        }

        _lastCalculatedFloat[deviceName] = rawTarget;

        _targetBrightness[deviceName] = target;
        _isManualTransition[deviceName] = isManual;
        _canDimSoftware[deviceName] = canDimSoftware;
        _isOverlayOnly[deviceName] = isOverlayOnly;
        _activeBrightnessCallbacks[deviceName] = updateBrightnessCallback;

        if (_adjustmentTimers[deviceName] == null) {
          _runTransitionLoop(
            deviceName,
            target,
            monitors,
            monitorService,
            isUIVisible: isUIVisible,
            isManual: isManual,
            canDimSoftware: canDimSoftware,
            isOverlayOnly: isOverlayOnly,
          );
        }
      }
    }
  }

  Future<void> _runTransitionLoop(
    String deviceName,
    int initialTarget,
    List<MonitorInfo> monitors,
    MonitorService monitorService, {
    bool isUIVisible = true,
    bool isManual = false,
    bool canDimSoftware = false,
    bool isOverlayOnly = false,
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
          (isOverlayOnly ? 100 : initialTarget);

      while (true) {
        final target = _targetBrightness[deviceName] ?? initialTarget;
        final currentIsManual = _isManualTransition[deviceName] ?? isManual;
        final currentCanDim = _canDimSoftware[deviceName] ?? canDimSoftware;
        final currentOverlayOnly = _isOverlayOnly[deviceName] ?? isOverlayOnly;
        final diff = (target - current).abs();

        if (diff == 0) {
          _currentHardwareBrightness[deviceName] = current;
          break;
        }

        final int minVal = currentOverlayOnly ? 0 : (currentCanDim ? -100 : 0);
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
        final cb = _activeBrightnessCallbacks[deviceName];
        if (cb != null) {
          Future.delayed(Duration.zero, () {
            try {
              cb(deviceName, valToReport);
            } catch (_) {}
          });
        }

        await monitorService.setBrightness(
          deviceName,
          current,
          isOverlayOnly: currentOverlayOnly,
        );

        // ALWAYS check against the most recent target, to avoid race conditions
        // where target updates while we were waiting for setBrightness.
        if (current == _targetBrightness[deviceName]) {
          break;
        }

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
      _isOverlayOnly.remove(deviceName);
      _activeBrightnessCallbacks.remove(deviceName);
    }
  }
}
