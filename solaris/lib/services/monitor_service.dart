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

  MonitorInfo({
    required this.id,
    required this.name,
    required this.friendlyName,
    required this.deviceName,
    required this.deviceIdHash,
    required this.isPrimary,
    this.realBrightness,
    this.realTemperature,
  });

  bool get isDdcSupported => realBrightness != null;
}

class MonitorService {
  static const _channel = MethodChannel('com.solaris.monitor/names');
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
      print('Failed to set temperature for $deviceName: $e');
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
      print('Failed to reset temperature for $deviceName: $e');
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
      print('Failed to reset all monitors temperature: $e');
      return false;
    }
  }

  Future<bool> setBrightness(String deviceName, int brightness) async {
    // Avoid redundant calls to slow native DDC/CI methods if brightness hasn't changed.
    if (_lastSentBrightness[deviceName] == brightness) {
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setMonitorBrightness',
        {'devicePath': deviceName, 'brightness': brightness},
      );
      if (success == true) {
        _lastSentBrightness[deviceName] = brightness;

        if (kDebugMode) {
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
      print('Failed to set brightness for $deviceName: $e');
      return false;
    }
  }

  Future<int?> getBrightness(String deviceName) async {
    try {
      final int? brightness = await _channel.invokeMethod<int?>(
        'getMonitorBrightness',
        {'devicePath': deviceName},
      );
      return brightness;
    } catch (e) {
      print('Failed to get brightness for $deviceName: $e');
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
      print('Failed to get friendly names: $e');
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

          // Fetch real brightness for this monitor
          final realBrightness = await getBrightness(deviceName);

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
          realBrightness: null,
        ),
      );
    }

    return monitors;
  }
}
