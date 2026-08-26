import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

void main() {
  group('Active Monitor Detection & Friendly Name Matching Logic', () {
    test(
      'Scenario: Adapter with inactive LG at index 0 and active ASUS at index 1 selects ASUS',
      () {
        // Given a mock setup API friendly name mapping from Windows registry
        final friendlyNames = {
          r'\\?\display#gsm58d6#5&e6a2ac1&0&uid24832#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}':
              'LG IPS224',
          r'\\?\display#aus258c#5&e6a2ac1&0&uid24834#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}':
              'ASUS VG259',
        };

        // Simulating the monitor records under DISPLAY1
        final records = [
          {
            'index': 0,
            'name': 'Generic PnP Monitor',
            'deviceId':
                r'MONITOR\GSM58D6\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001',
            'interfaceId':
                r'\\?\DISPLAY#GSM58D6#5&e6a2ac1&0&UID24832#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}',
            'stateFlags': 0x2, // Inactive (Attached=false)
          },
          {
            'index': 1,
            'name': 'Generic PnP Monitor',
            'deviceId':
                r'MONITOR\AUS258C\{4d36e96e-e325-11ce-bfc1-08002be10318}\0002',
            'interfaceId':
                r'\\?\DISPLAY#AUS258C#5&e6a2ac1&0&UID24834#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}',
            'stateFlags': 0x3, // Active (Attached=true, Active=true)
          },
        ];

        // Apply our selection algorithm
        String? selectedName;
        String? selectedDeviceId;
        String? selectedInterfaceId;
        bool foundActive = false;

        for (final rec in records) {
          final flags = rec['stateFlags'] as int;
          final monName = rec['name'] as String;
          final monId = rec['deviceId'] as String;
          final ifId = rec['interfaceId'] as String;

          final bool isMonActive = (flags & 0x1) != 0;

          if (isMonActive && !foundActive) {
            selectedName = monName;
            selectedDeviceId = monId;
            selectedInterfaceId = ifId;
            foundActive = true;
          } else if (selectedName == null && monId.isNotEmpty) {
            selectedName = monName;
            selectedDeviceId = monId;
            selectedInterfaceId = ifId;
          }
        }

        expect(foundActive, isTrue);
        expect(selectedDeviceId, contains('AUS258C'));

        // Match friendly name
        final deviceID = (selectedDeviceId ?? '').toLowerCase();
        final deviceInterfaceID = (selectedInterfaceId ?? '').toLowerCase();

        String friendly =
            friendlyNames[deviceInterfaceID] ??
            friendlyNames[deviceID] ??
            selectedName!;

        if (friendly == selectedName) {
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

        expect(friendly, equals('ASUS VG259'));
      },
    );

    test(
      'Friendly name lookup falls back to substring token match when interfaceId is missing',
      () {
        final friendlyNames = {
          r'\\?\display#aus258c#5&e6a2ac1&0&uid24834#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}':
              'ASUS VG259',
        };

        final rawDeviceId =
            r'MONITOR\AUS258C\{4d36e96e-e325-11ce-bfc1-08002be10318}\0002'
                .toLowerCase();
        final monitorName = 'Generic PnP Monitor';

        String friendly = friendlyNames[rawDeviceId] ?? monitorName;

        if (friendly == monitorName) {
          for (final entry in friendlyNames.entries) {
            final parts = entry.key.split('#');
            if (parts.length > 1) {
              final hardwareId = parts[1].toLowerCase();
              if (hardwareId.isNotEmpty && rawDeviceId.contains(hardwareId)) {
                friendly = entry.value;
                break;
              }
            }
          }
        }

        expect(friendly, equals('ASUS VG259'));
      },
    );

    test(
      'Slug resolver generates correct slug for resolved active ASUS monitor',
      () {
        final monitor = MonitorInfo(
          id: r'\\.\DISPLAY1',
          name: 'Generic PnP Monitor',
          friendlyName: 'ASUS VG259',
          deviceName: r'\\.\DISPLAY1',
          deviceIdHash: 'b5e8c1a0',
          isPrimary: true,
          realBrightness: 80,
        );

        MonitorSlugResolver.updateMonitors([monitor]);

        expect(
          MonitorSlugResolver.resolveToSystemId('primary'),
          equals(r'\\.\DISPLAY1'),
        );
        expect(
          MonitorSlugResolver.resolveToSystemId('asus-vg259-b5e8'),
          equals(r'\\.\DISPLAY1'),
        );
        expect(
          MonitorSlugResolver.getSlugForSystemId(r'\\.\DISPLAY1'),
          equals('asus-vg259-b5e8'),
        );
      },
    );
  });
}
