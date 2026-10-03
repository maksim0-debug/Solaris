import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MonitorInfo {
  final String id;
  final String name;
  final String friendlyName;
  final String deviceName;
  final String deviceIdHash;
  final bool isPrimary;
  final int? realBrightness;
  final int? realTemperature;
  final bool isDdcSupported;

  MonitorInfo({
    required this.id,
    required this.name,
    required this.friendlyName,
    required this.deviceName,
    required this.deviceIdHash,
    required this.isPrimary,
    this.realBrightness,
    this.realTemperature,
    bool? isDdcSupported,
  }) : isDdcSupported = isDdcSupported ?? (realBrightness != null);

  MonitorInfo copyWith({
    String? id,
    String? name,
    String? friendlyName,
    String? deviceName,
    String? deviceIdHash,
    bool? isPrimary,
    int? realBrightness,
    int? realTemperature,
    bool? isDdcSupported,
    bool overrideBrightnessWithNull = false,
    bool overrideTemperatureWithNull = false,
  }) {
    return MonitorInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      friendlyName: friendlyName ?? this.friendlyName,
      deviceName: deviceName ?? this.deviceName,
      deviceIdHash: deviceIdHash ?? this.deviceIdHash,
      isPrimary: isPrimary ?? this.isPrimary,
      realBrightness: overrideBrightnessWithNull
          ? null
          : (realBrightness ?? this.realBrightness),
      realTemperature: overrideTemperatureWithNull
          ? null
          : (realTemperature ?? this.realTemperature),
      isDdcSupported: isDdcSupported ?? this.isDdcSupported,
    );
  }

  /// Determines whether the given [selection] of monitors is overlay-only.
  /// If 'all' is selected, returns true only if ALL connected monitors lack DDC/CI support.
  /// If a subset of monitors is selected, returns true only if ALL monitors in that selection lack DDC/CI support.
  static bool isSelectionOverlayOnly(
    Set<String> selection,
    List<MonitorInfo> monitors,
  ) {
    if (selection.contains('all')) {
      return monitors.isNotEmpty && monitors.every((m) => !m.isDdcSupported);
    }
    final selectedMonitors = monitors
        .where(
          (m) => selection.contains(m.deviceName) || selection.contains(m.id),
        )
        .toList();
    return selectedMonitors.isNotEmpty &&
        selectedMonitors.every((m) => !m.isDdcSupported);
  }

  /// Calculates the effective minimum brightness percentage based on whether the
  /// target monitor(s) are overlay-only and whether software dimming is enabled.
  /// Overlay-only monitors never dim below 0.0%, whereas hybrid DDC/CI monitors
  /// can dim down to -100.0% when software dimming is enabled.
  static double effectiveMinBrightness({
    required bool isOverlayOnly,
    required bool isSoftwareDimmingEnabled,
  }) {
    if (isOverlayOnly) return 0.0;
    return isSoftwareDimmingEnabled ? -100.0 : 0.0;
  }
}

class MonitorService {
  static const _channel = MethodChannel('com.solaris.monitor/names');

  /// Physical DDC/CI hardware brightness floor threshold (0-5%).
  /// Many external displays clamp minimum physical backlight to non-zero values (e.g. 1-5%).
  static const int hardwareBrightnessFloorThreshold = 5;

  final Map<String, int> _lastSentBrightness = {};
  final Map<String, Timer> _immediateDebugTimers = {};
  final Map<String, Timer> _delayedDebugTimers = {};

  Future<bool> setMonitorTemperature(String deviceName, int temperature) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setMonitorTemperature',
        {'devicePath': deviceName, 'temperature': temperature},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to set temperature for $deviceName: $e');
      return false;
    }
  }

  Future<bool> resetMonitorTemperature(String deviceName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'resetMonitorTemperature',
        {'devicePath': deviceName},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to reset temperature for $deviceName: $e');
      return false;
    }
  }

  Future<bool> resetAllMonitorsTemperature() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'resetAllMonitorsTemperature',
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to reset all monitors temperature: $e');
      return false;
    }
  }

  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    // Avoid redundant calls to slow native DDC/CI methods if brightness hasn't changed.
    final cacheKey = '$deviceName:$isOverlayOnly';
    if (_lastSentBrightness[cacheKey] == brightness) {
      return true;
    }

    try {
      final bool? success = await _channel
          .invokeMethod<bool>('setMonitorBrightness', {
            'devicePath': deviceName,
            'brightness': brightness,
            'isOverlayOnly': isOverlayOnly,
          });
      if (success == true) {
        _lastSentBrightness[cacheKey] = brightness;
        _lastSentBrightness[deviceName] = brightness;

        if (kDebugMode && !isOverlayOnly) {
          _immediateDebugTimers[deviceName]?.cancel();
          _immediateDebugTimers[deviceName] = Timer(
            const Duration(milliseconds: 200),
            () {
              _logRealBrightness(deviceName, brightness, 'Immediately');
            },
          );

          _delayedDebugTimers[deviceName]?.cancel();
          _delayedDebugTimers[deviceName] = Timer(
            const Duration(seconds: 3),
            () {
              _logRealBrightness(deviceName, brightness, 'After 3s');
            },
          );
        }
      }
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to set brightness for $deviceName: $e');
      return false;
    }
  }

  Future<int?> getBrightness(
    String deviceName, {
    bool isOverlayOnly = false,
    bool probeHardware = false,
  }) async {
    try {
      final int? brightness = await _channel
          .invokeMethod<int?>('getMonitorBrightness', {
            'devicePath': deviceName,
            'isOverlayOnly': isOverlayOnly,
            'probeHardware': probeHardware,
          });
      return brightness;
    } catch (e) {
      debugPrint('Failed to get brightness for $deviceName: $e');
      return null;
    }
  }

  void _logRealBrightness(
    String deviceName,
    int targetBrightness,
    String timing,
  ) {
    Future(() async {
      final real = await getBrightness(deviceName);
      if (real == null) {
        debugPrint(
          '❌ [DDC/CI Debug] [$timing] Device: $deviceName | Target: $targetBrightness% | Real: Failed to read',
        );
      } else if (real != targetBrightness) {
        debugPrint(
          '⚠️ [DDC/CI Debug] [$timing] Device: $deviceName | MISMATCH! Target: $targetBrightness% | Real (DDC/CI): $real%',
        );
      }
    });
  }

  Future<List<MonitorInfo>> getConnectedMonitors() async {
    final monitors = <MonitorInfo>[];

    // Get friendly names from native side (keyed by device interface path, lowercased)
    Map<String, String> friendlyNames = {};
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getMonitorNames',
      );
      if (result != null) {
        friendlyNames = result.cast<String, String>().map(
          (key, value) => MapEntry(key.toLowerCase(), value),
        );
      }
    } catch (e) {
      debugPrint('Failed to get friendly names: $e');
    }

    final displayDevice = calloc<DISPLAY_DEVICE>();
    displayDevice.ref.cb = sizeOf<DISPLAY_DEVICE>();

    var deviceIndex = 0;
    while (EnumDisplayDevices(nullptr, deviceIndex, displayDevice, 0) != 0) {
      final stateFlags = displayDevice.ref.StateFlags;

      if ((stateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0) {
        final deviceName = displayDevice.ref.DeviceName;
        final isPrimary = (stateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0;

        final monitorDevice = calloc<DISPLAY_DEVICE>();
        monitorDevice.ref.cb = sizeOf<DISPLAY_DEVICE>();
        final deviceNamePtr = deviceName.toNativeUtf16();

        // An adapter (e.g. \\.\DISPLAY1) may contain multiple historical or inactive monitor entries.
        // We iterate through all monitor endpoints to select the actively attached monitor.
        String? selectedMonitorName;
        String? selectedDeviceId;
        String? selectedInterfaceId;
        bool foundActive = false;

        var monIndex = 0;
        while (EnumDisplayDevices(deviceNamePtr, monIndex, monitorDevice, 0) !=
            0) {
          final monFlags = monitorDevice.ref.StateFlags;
          final monName = monitorDevice.ref.DeviceString;
          final monId = monitorDevice.ref.DeviceID;

          // DISPLAY_DEVICE_ATTACHED_TO_DESKTOP (0x1) / DISPLAY_DEVICE_ACTIVE (0x1)
          final bool isMonActive =
              (monFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0 ||
              (monFlags & 0x1) != 0;

          // Fetch device interface name using EDD_GET_DEVICE_INTERFACE_NAME (flag = 1)
          final interfaceDevice = calloc<DISPLAY_DEVICE>();
          interfaceDevice.ref.cb = sizeOf<DISPLAY_DEVICE>();
          String interfaceId = '';
          if (EnumDisplayDevices(deviceNamePtr, monIndex, interfaceDevice, 1) !=
              0) {
            interfaceId = interfaceDevice.ref.DeviceID;
          }
          free(interfaceDevice);

          if (isMonActive && !foundActive) {
            selectedMonitorName = monName;
            selectedDeviceId = monId;
            selectedInterfaceId = interfaceId;
            foundActive = true;
          } else if (selectedMonitorName == null && monId.isNotEmpty) {
            // Fallback to first available entry if no monitor has explicit active flag
            selectedMonitorName = monName;
            selectedDeviceId = monId;
            selectedInterfaceId = interfaceId;
          }

          monIndex++;
        }

        if (selectedMonitorName != null && selectedDeviceId != null) {
          final monitorName = selectedMonitorName;
          final deviceID = selectedDeviceId.toLowerCase();
          final deviceInterfaceID = (selectedInterfaceId ?? '').toLowerCase();
          final deviceIdHash = deviceID.hashCode
              .toRadixString(16)
              .toLowerCase();

          // Fetch real physical DDC/CI brightness for this monitor.
          // Hardware probe: if monitor lacks DDC/CI, physical query returns null.
          int? realBrightness = await getBrightness(
            deviceName,
            probeHardware: true,
          );
          if (realBrightness == null) {
            // Transient retry: DDC/CI I2C bus can occasionally drop first packet on display wake/startup
            await Future<void>.delayed(const Duration(milliseconds: 50));
            realBrightness = await getBrightness(
              deviceName,
              probeHardware: true,
            );
          }
          final bool isDdcSupported = realBrightness != null;
          if (realBrightness != null &&
              realBrightness >= 0 &&
              realBrightness <= hardwareBrightnessFloorThreshold &&
              (_lastSentBrightness[deviceName] ?? 0) < 0) {
            realBrightness = _lastSentBrightness[deviceName];
          }

          // If monitor doesn't support DDC/CI, initialize overlay brightness to last sent value,
          // or query active overlay opacity, or default to 100% (un-dimmed).
          if (!isDdcSupported) {
            realBrightness =
                _lastSentBrightness[deviceName] ??
                await getBrightness(deviceName, isOverlayOnly: true) ??
                100;
          }

          // 1. Direct lookup by exact SetupAPI device interface path or deviceID
          String friendly =
              friendlyNames[deviceInterfaceID] ??
              friendlyNames[deviceID] ??
              monitorName;

          // 2. Substring matching for PNP hardware identifiers (e.g. GSM58D6, AUS258C)
          if (friendly == monitorName) {
            for (final entry in friendlyNames.entries) {
              final parts = entry.key.split('#');
              if (parts.length > 1) {
                final hardwareId = parts[1].toLowerCase();
                if (hardwareId.isNotEmpty &&
                    (deviceID.contains(hardwareId) ||
                        deviceInterfaceID.contains(hardwareId))) {
                  friendly = entry.value;
                  break;
                }
              }
            }
          }

          monitors.add(
            MonitorInfo(
              id: deviceName,
              name: monitorName,
              friendlyName: friendly,
              deviceName: deviceName,
              deviceIdHash: deviceIdHash,
              isPrimary: isPrimary,
              realBrightness: realBrightness,
              isDdcSupported: isDdcSupported,
            ),
          );
        }

        free(deviceNamePtr);
        free(monitorDevice);
      }
      deviceIndex++;
    }

    free(displayDevice);

    if (monitors.isEmpty) {
      monitors.add(
        MonitorInfo(
          id: 'DISPLAY1',
          name: 'Generic Monitor',
          friendlyName: 'Generic Monitor',
          deviceName: 'DISPLAY1',
          deviceIdHash: 'generic',
          isPrimary: true,
          realBrightness: _lastSentBrightness['DISPLAY1'] ?? 100,
          isDdcSupported: false,
        ),
      );
    }

    return monitors;
  }

  Future<ExpandedGammaStatus> getExpandedGammaStatus() async {
    try {
      final int? statusCode = await _channel.invokeMethod<int>(
        'getExpandedGammaStatus',
      );
      return ExpandedGammaStatus.fromInt(statusCode);
    } catch (e) {
      debugPrint('Failed to query getExpandedGammaStatus: $e');
      return ExpandedGammaStatus.disabled;
    }
  }

  Future<bool> isExpandedGammaUnlocked() async {
    try {
      final bool? isUnlocked = await _channel.invokeMethod<bool>(
        'isExpandedGammaUnlocked',
      );
      return isUnlocked ?? false;
    } catch (e) {
      debugPrint('Failed to query isExpandedGammaUnlocked: $e');
      return false;
    }
  }

  Future<bool> unlockExpandedGamma() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'unlockExpandedGamma',
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to unlockExpandedGamma: $e');
      return false;
    }
  }

  Future<bool> restartComputer() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'restartComputer',
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Failed to restartComputer: $e');
      return false;
    }
  }
}

enum ExpandedGammaStatus {
  disabled,
  pendingRestart,
  active;

  static ExpandedGammaStatus fromInt(int? value) {
    switch (value) {
      case 1:
        return ExpandedGammaStatus.pendingRestart;
      case 2:
        return ExpandedGammaStatus.active;
      default:
        return ExpandedGammaStatus.disabled;
    }
  }
}
