import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/rfc7807_error.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';
import 'package:solaris/services/openapi_spec.dart';

void main() {
  group('Phase 1 E2E Architectural Verification', () {
    final testMonitorPrimary = MonitorInfo(
      id: r'\\.\DISPLAY1\Monitor0',
      name: 'LG 27GL850',
      friendlyName: 'LG UltraGear',
      deviceName: r'\\.\DISPLAY1\Monitor0',
      deviceIdHash: 'a1f9b2c3',
      isPrimary: true,
      realBrightness: 80,
      realTemperature: 5000,
    );

    final testMonitorSecondary = MonitorInfo(
      id: r'\\.\DISPLAY2\Monitor0',
      name: 'Dell U2720Q',
      friendlyName: 'Dell 4K',
      deviceName: r'\\.\DISPLAY2\Monitor0',
      deviceIdHash: 'e4f5d6c7',
      isPrimary: false,
      realBrightness: 65,
      realTemperature: 6500,
    );

    setUp(() {
      MonitorSlugResolver.updateMonitors([testMonitorPrimary, testMonitorSecondary]);
    });

    test('MonitorSlugResolver deterministically resolves all 5 slug types', () {
      // 1. Index slugs
      expect(MonitorSlugResolver.resolveToSystemId('display-1'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('display-2'), equals(r'\\.\DISPLAY2\Monitor0'));

      // 2. Primary / Main aliases
      expect(MonitorSlugResolver.resolveToSystemId('primary'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('main'), equals(r'\\.\DISPLAY1\Monitor0'));

      // 3. EDID Friendly name + Hash slugs
      expect(MonitorSlugResolver.resolveToSystemId('lg-ultragear-a1f9'), equals(r'\\.\DISPLAY1\Monitor0'));
      expect(MonitorSlugResolver.resolveToSystemId('dell-4k-e4f5'), equals(r'\\.\DISPLAY2\Monitor0'));

      // 4. Raw Win32 System ID fallback
      expect(MonitorSlugResolver.resolveToSystemId(r'\\.\DISPLAY1\Monitor0'), equals(r'\\.\DISPLAY1\Monitor0'));

      // 5. Reverse slug resolution (EDID slug)
      expect(MonitorSlugResolver.getSlugForSystemId(r'\\.\DISPLAY1\Monitor0'), equals('lg-ultragear-a1f9'));
      expect(MonitorSlugResolver.getSlugForSystemId(r'\\.\DISPLAY2\Monitor0'), equals('dell-4k-e4f5'));
    });

    test('OpenAPI 3.0.3 specification contains required endpoints and definitions', () {
      final spec = OpenApiSpec.generateSpec(port: 45321);
      final paths = spec['paths'] as Map<String, dynamic>;

      expect(paths.containsKey('/api/v1/status'), isTrue);
      expect(paths.containsKey('/api/v1/health'), isTrue);
      expect(paths.containsKey('/api/v1/control'), isTrue);
      expect(paths.containsKey('/api/v1/monitors'), isTrue);
      expect(paths.containsKey('/api/v1/monitors/{slug}'), isTrue);
      expect(paths.containsKey('/api/v1/presets'), isTrue);
      expect(paths.containsKey('/api/v1/solar'), isTrue);
      expect(paths.containsKey('/api/v1/sleep/sessions'), isTrue);

      final components = spec['components'] as Map<String, dynamic>;
      final schemas = components['schemas'] as Map<String, dynamic>;
      expect(schemas.containsKey('StatusResponse'), isTrue);
      expect(schemas.containsKey('Rfc7807Error'), isTrue);
      expect(schemas.containsKey('ControlRequest'), isTrue);
    });

    test('RFC 7807 Error model respects RFC spec structure', () {
      final err = Rfc7807Error(
        type: 'https://solaris.local/errors/validation',
        title: 'Unprocessable Entity',
        status: 422,
        detail: 'Value must be between 0 and 100.',
        instance: '/api/v1/control',
        invalidParams: {
          'value': 'out_of_range',
        },
      );

      final json = err.toJson();
      expect(json['type'], equals('https://solaris.local/errors/validation'));
      expect(json['status'], equals(422));
      expect(json['invalid_params'], isNotNull);
      expect((json['invalid_params'] as Map)['value'], equals('out_of_range'));
    });
  });
}
