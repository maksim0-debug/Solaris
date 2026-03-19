import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';

class MonitorInfo {
  final String name;
  final String friendlyName;
  final String deviceName;
  final bool isPrimary;
  final int? realBrightness;

  MonitorInfo({
    required this.name,
    required this.friendlyName,
    required this.deviceName,
    required this.isPrimary,
    this.realBrightness,
  });
}

class MonitorService {
  static const _channel = MethodChannel('com.solaris.monitor/names');

  Future<bool> setBrightness(String deviceName, int brightness) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setMonitorBrightness',
        {'devicePath': deviceName, 'brightness': brightness},
      );
      return success ?? false;
    } catch (e) {
      print('Failed to set brightness: $e');
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

  Future<List<MonitorInfo>> getConnectedMonitors() async {
    final monitors = <MonitorInfo>[];

    // Get friendly names from native side
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

        if (EnumDisplayDevices(deviceNamePtr, 0, monitorDevice, 0) != 0) {
          final monitorName = monitorDevice.ref.DeviceString;
          final deviceID = monitorDevice.ref.DeviceID.toLowerCase();

          // Fetch real brightness for this monitor
          final realBrightness = await getBrightness(deviceName);

          // Try to find a friendly name from our native map
          // The deviceID from EnumDisplayDevices looks like:
          // \\.\DISPLAY1\Monitor0
          // But our C++ code gets the symbolic link path, which might look different.
          // Actually, let's use a simpler heuristic or improve the C++ to return something matching.
          // In C++, we used SetupDi to get the path. Let's see if we can match it.

          String friendly = friendlyNames[deviceID] ?? monitorName;

          // Match by searching for the deviceID substring if exact match fails
          if (friendly == monitorName) {
            for (final entry in friendlyNames.entries) {
              if (deviceID.contains(entry.key.split('#')[1].toLowerCase())) {
                friendly = entry.value;
                break;
              }
            }
          }

          monitors.add(
            MonitorInfo(
              name: monitorName,
              friendlyName: friendly,
              deviceName: deviceName,
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
          name: 'Generic Monitor',
          friendlyName: 'Generic Monitor',
          deviceName: 'DISPLAY1',
          isPrimary: true,
          realBrightness: null,
        ),
      );
    }

    return monitors;
  }
}
