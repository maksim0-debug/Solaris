import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

void main() {
  group('MonitorSlugResolver Tests', () {
    final monitor1 = MonitorInfo(
      id: r'\\.\DISPLAY1\Monitor0',
      name: 'LG 27GL850',
      friendlyName: 'LG UltraGear',
      deviceName: r'\\.\DISPLAY1\Monitor0',
      deviceIdHash: 'a1f9b2c3',
      isPrimary: true,
      realBrightness: 75,
    );

    final monitor2 = MonitorInfo(
      id: r'\\.\DISPLAY2\Monitor0',
      name: 'Dell U2720Q',
      friendlyName: 'Dell Monitor',
      deviceName: r'\\.\DISPLAY2\Monitor0',
      deviceIdHash: 'e4f5d6c7',
      isPrimary: false,
      realBrightness: 60,
    );

    setUp(() {
      MonitorSlugResolver.updateMonitors([monitor1, monitor2]);
    });

    test('should resolve friendly index slugs', () {
      expect(MonitorSlugResolver.resolveToSystemId('display-1'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('display-2'), equals(r'\\.\DISPLAY2\Monitor0'));
    });

    test('should resolve primary and main aliases', () {
      expect(MonitorSlugResolver.resolveToSystemId('primary'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('main'), equals(r'\\.\DISPLAY1\Monitor0'));
    });

    test('should resolve EDID/device hash slugs', () {
      expect(MonitorSlugResolver.resolveToSystemId('lg-ultragear-a1f9'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('dell-monitor-e4f5'), equals(r'\\.\DISPLAY2\Monitor0'));
    });

    test('should fallback to raw Win32 system ID', () {
      expect(MonitorSlugResolver.resolveToSystemId(r'\\.\DISPLAY1\Monitor0'), equals(r'\\.\DISPLAY1\Monitor0'));
    });

    test('should return null for unknown slugs', () {
      expect(MonitorSlugResolver.resolveToSystemId('unknown-display-999'), isNull);
    });
  });
}
