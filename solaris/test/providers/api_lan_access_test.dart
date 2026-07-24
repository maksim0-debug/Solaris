import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/settings_state.dart';

void main() {
  group('SettingsState - updateApiLanAccessEnabled Test', () {
    test('disabling LAN access keeps isLocalIpcServerEnabled as true', () {
      final initial = SettingsState(
        isLocalIpcServerEnabled: true,
        isApiLanAccessEnabled: true,
      );

      final updated = initial.copyWith(isApiLanAccessEnabled: false);

      expect(updated.isLocalIpcServerEnabled, isTrue);
      expect(updated.isApiLanAccessEnabled, isFalse);
    });

    test('enabling LAN access keeps isLocalIpcServerEnabled unchanged', () {
      final initial = SettingsState(
        isLocalIpcServerEnabled: true,
        isApiLanAccessEnabled: false,
      );

      final updated = initial.copyWith(isApiLanAccessEnabled: true);

      expect(updated.isLocalIpcServerEnabled, isTrue);
      expect(updated.isApiLanAccessEnabled, isTrue);
    });
  });
}
