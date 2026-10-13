import 'dart:async';
import 'package:solaris/services/log_service.dart';
import 'package:solaris/services/monitor_service.dart';

// No import of providers.dart to avoid circular dependency

class BrightnessService {
  static const _automaticStepInterval = Duration(milliseconds: 20);
  final Map<String, int> _currentHardwareBrightness = {};
  final Set<String> _runningTransitions = {};
  final Set<String> _uncertainDevices = {};
  final Map<String, _BrightnessRequest> _requests = {};
  final Map<String, double> _lastCalculatedFloat = {};
  final Map<String, bool> _lastAppliedOverlayOnly = {};
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _requests.clear();
  }

  void syncHardwareBrightness(String deviceName, int realBrightness) {
    if (_disposed) return;
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

  bool isTransitioning(String deviceName) =>
      _runningTransitions.contains(deviceName);

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
    if (_disposed || !targetValue.isFinite) return;
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
        final target = rawTarget.round();
        final previousRequest = _requests[deviceName];
        final modeChanged =
            previousRequest != null &&
            (previousRequest.isManual != isManual ||
                previousRequest.isOverlayOnly != isOverlayOnly ||
                previousRequest.canDimSoftware != canDimSoftware);

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

        if (!_uncertainDevices.contains(deviceName) &&
            !modeChanged &&
            !isManual &&
            !isHardwareDesynced &&
            (rawTarget - lastCalculated).abs() < 1.5) {
          continue; // Ignore micro-fluctuations
        }

        if (!_uncertainDevices.contains(deviceName) &&
            !modeChanged &&
            !_runningTransitions.contains(deviceName) &&
            _currentHardwareBrightness[deviceName] == target &&
            _lastAppliedOverlayOnly[deviceName] == isOverlayOnly &&
            !isHardwareDesynced &&
            (rawTarget - lastCalculated).abs() < 1.0) {
          continue; // Already at target with hardware aligned
        }

        _lastCalculatedFloat[deviceName] = rawTarget;

        _requests[deviceName] = _BrightnessRequest(
          target: target,
          monitorService: monitorService,
          callback: updateBrightnessCallback,
          isManual: isManual,
          canDimSoftware: canDimSoftware,
          isOverlayOnly: isOverlayOnly,
          isUIVisible: isUIVisible,
        );

        if (!_runningTransitions.contains(deviceName)) {
          unawaited(_runTransitionLoop(deviceName, monitor.realBrightness));
        }
      }
    }
  }

  Future<void> _runTransitionLoop(
    String deviceName,
    int? observedBrightness,
  ) async {
    if (!_runningTransitions.add(deviceName)) return;

    try {
      int? current =
          _currentHardwareBrightness[deviceName] ?? observedBrightness;
      var failures = 0;
      _BrightnessRequest? failedRequest;
      var automaticStep = 1;

      while (!_disposed) {
        final request = _requests[deviceName];
        if (request == null) break;
        current = _currentHardwareBrightness[deviceName] ?? current;
        final target = request.target;
        final diff = current == null ? null : (target - current).abs();
        final modeNeedsWrite =
            _lastAppliedOverlayOnly.containsKey(deviceName) &&
            _lastAppliedOverlayOnly[deviceName] != request.isOverlayOnly;
        if (diff == 0 &&
            !modeNeedsWrite &&
            failures == 0 &&
            !_uncertainDevices.contains(deviceName)) {
          _currentHardwareBrightness[deviceName] = current!;
          break;
        }

        int next;
        if (current == null ||
            diff == 0 ||
            (!request.isUIVisible && !request.isManual)) {
          next = target;
        } else {
          final step = request.isManual ? (diff! > 20 ? 12 : 6) : automaticStep;
          next = current < target
              ? (current + step).clamp(current, target)
              : (current - step).clamp(target, current);
        }
        final minimum = request.isOverlayOnly || !request.canDimSoftware
            ? 0
            : -100;
        next = next.clamp(minimum, 100);

        bool success;
        final writeTime = Stopwatch()..start();
        try {
          success = await request.monitorService.setBrightness(
            deviceName,
            next,
            isOverlayOnly: request.isOverlayOnly,
          );
        } catch (error, stack) {
          success = false;
          LogService.instance.log(
            'Brightness write threw: device=$deviceName target=$next error=$error\n$stack',
            level: 'ERROR',
          );
        }
        writeTime.stop();
        if (_disposed) break;

        if (!success) {
          // A rejected write may still have changed an overlay or some handles.
          _uncertainDevices.add(deviceName);
          _lastCalculatedFloat.remove(deviceName);
          if (!request.hasSameTarget(_requests[deviceName])) {
            failures = 0;
            continue;
          }
          if (!request.hasSameTarget(failedRequest)) failures = 0;
          failedRequest = request;
          failures++;
          LogService.instance.log(
            'Brightness write failed: device=$deviceName target=$next attempt=$failures',
            level: 'WARNING',
          );
          if (failures >= 3) break;
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (1 << (failures - 1))),
          );
          continue;
        }

        failures = 0;
        // Slow DDC writes use slightly larger steps without concurrent writes.
        automaticStep =
            (writeTime.elapsedMicroseconds /
                    _automaticStepInterval.inMicroseconds)
                .ceil()
                .clamp(1, 5);
        _uncertainDevices.remove(deviceName);
        failedRequest = null;
        current = next;
        _currentHardwareBrightness[deviceName] = next;
        _lastAppliedOverlayOnly[deviceName] = request.isOverlayOnly;
        try {
          _requests[deviceName]?.callback(deviceName, next);
        } catch (error, stack) {
          LogService.instance.log(
            'Brightness state update failed: device=$deviceName value=$next error=$error\n$stack',
            level: 'ERROR',
          );
        }

        final latest = _requests[deviceName];
        if (latest == null ||
            (next == latest.target &&
                request.isOverlayOnly == latest.isOverlayOnly)) {
          break;
        }
        if (!request.hasSameTarget(latest)) continue;
        final pause = request.isManual
            ? const Duration(milliseconds: 100)
            : _automaticStepInterval - writeTime.elapsed;
        if (pause > Duration.zero) await Future<void>.delayed(pause);
      }
    } finally {
      _runningTransitions.remove(deviceName);
    }
  }
}

class _BrightnessRequest {
  final int target;
  final MonitorService monitorService;
  final void Function(String, int) callback;
  final bool isManual;
  final bool canDimSoftware;
  final bool isOverlayOnly;
  final bool isUIVisible;

  const _BrightnessRequest({
    required this.target,
    required this.monitorService,
    required this.callback,
    required this.isManual,
    required this.canDimSoftware,
    required this.isOverlayOnly,
    required this.isUIVisible,
  });

  bool hasSameTarget(_BrightnessRequest? other) =>
      other != null &&
      target == other.target &&
      isManual == other.isManual &&
      isOverlayOnly == other.isOverlayOnly &&
      canDimSoftware == other.canDimSoftware;
}
