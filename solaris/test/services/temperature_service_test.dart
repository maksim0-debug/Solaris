import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:solaris/services/monitor_service.dart';

class FakeMonitorService extends Fake implements MonitorService {
  @override
  Future<bool> resetMonitorTemperature(String deviceName) async {
    return true;
  }

  @override
  Future<bool> setMonitorTemperature(String deviceName, int kelvins) async {
    return true;
  }
}

void main() {
  group('TemperatureService Reset Lock Tests', () {
    late TemperatureService service;
    late FakeMonitorService mockMonitorService;

    setUp(() {
      service = TemperatureService();
      mockMonitorService = FakeMonitorService();
    });

    test('lockTemperatureControl locks temperature service and sets 6500K', () async {
      expect(service.isResetLocked, false);

      final monitor = MonitorInfo(
        id: r'\\.\DISPLAY1\Monitor0',
        deviceName: 'DISPLAY1',
        name: 'Monitor 1',
        friendlyName: 'Monitor 1',
        deviceIdHash: 'a1b2c3d4',
        isPrimary: true,
      );

      service.lockTemperatureControl();
      await service.resetTemperatureNow(
        selection: 'all',
        monitors: [monitor],
        monitorService: mockMonitorService,
        updateTemperatureCallback: (id, val) {},
      );

      expect(service.isResetLocked, true);
    });

    test('setTemperatureInstant ignores non-6500K target when reset lock is active', () async {
      final monitor = MonitorInfo(
        id: r'\\.\DISPLAY1\Monitor0',
        deviceName: 'DISPLAY1',
        name: 'Monitor 1',
        friendlyName: 'Monitor 1',
        deviceIdHash: 'a1b2c3d4',
        isPrimary: true,
      );

      int reportedTemp = -1;

      // Lock temperature control
      service.lockTemperatureControl();
      await service.resetTemperatureNow(
        selection: 'all',
        monitors: [monitor],
        monitorService: mockMonitorService,
        updateTemperatureCallback: (id, val) {
          reportedTemp = val;
        },
      );

      expect(service.isResetLocked, true);

      // Attempt to set custom manual temperature (3500K) while locked
      await service.setTemperatureInstant(
        selection: 'all',
        targetValue: 3500.0,
        monitors: [monitor],
        monitorService: mockMonitorService,
        updateTemperatureCallback: (id, val) {
          reportedTemp = val;
        },
      );

      // Callback should NOT be invoked for 3500K
      expect(reportedTemp, 6500);

      // Unlock and re-attempt
      service.unlockTemperatureControl();
      expect(service.isResetLocked, false);

      await service.setTemperatureInstant(
        selection: 'all',
        targetValue: 3500.0,
        monitors: [monitor],
        monitorService: mockMonitorService,
        updateTemperatureCallback: (id, val) {
          reportedTemp = val;
        },
      );

      expect(reportedTemp, 3500);
    });

    test('setTemperatureInstant dispatches native commands to ALL monitors when selection is all', () async {
      final monitor1 = MonitorInfo(
        id: r'\\.\DISPLAY1',
        deviceName: r'\\.\DISPLAY1',
        name: 'ASUS',
        friendlyName: 'ASUS',
        deviceIdHash: 'hash1',
        isPrimary: true,
      );
      final monitor2 = MonitorInfo(
        id: r'\\.\DISPLAY2',
        deviceName: r'\\.\DISPLAY2',
        name: 'LG',
        friendlyName: 'LG',
        deviceIdHash: 'hash2',
        isPrimary: false,
      );

      final updatedMonitors = <String, int>{};

      await service.setTemperatureInstant(
        selection: 'all',
        targetValue: 4000.0,
        monitors: [monitor1, monitor2],
        monitorService: mockMonitorService,
        updateTemperatureCallback: (id, val) {
          updatedMonitors[id] = val;
        },
      );

      expect(updatedMonitors[r'\\.\DISPLAY1'], 4000);
      expect(updatedMonitors[r'\\.\DISPLAY2'], 4000);
    });
  });
}
