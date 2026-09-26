import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsState & TemperatureState Default Values Zero-Trust Tests', () {
    test(
      'Default SettingsState has smart circadian, 4 sleep methods (master & brightness) and software dimming enabled',
      () {
        final settings = SettingsState();

        // Circadian master toggle
        expect(settings.isSmartCircadianEnabled, isTrue);

        // 4 Sleep methods master toggles
        expect(settings.isWindDownMasterEnabled, isTrue);
        expect(settings.isTimeShiftMasterEnabled, isTrue);
        expect(settings.isSleepPressureMasterEnabled, isTrue);
        expect(settings.isSleepDebtMasterEnabled, isTrue);

        // 4 Sleep methods brightness toggles
        expect(settings.isWindDownEnabled, isTrue);
        expect(settings.isTimeShiftEnabled, isTrue);
        expect(settings.isSleepPressureEnabled, isTrue);
        expect(settings.isSleepDebtEnabled, isTrue);

        // Software deep dimming toggle
        expect(settings.isSoftwareDimmingEnabled, isTrue);
      },
    );

    test(
      'Default TemperatureState has all sleep methods and smart circadian enabled',
      () {
        final temp = TemperatureState();

        expect(temp.isSmartCircadianEnabled, isTrue);
        expect(temp.isWindDownEnabled, isTrue);
        expect(temp.isTimeShiftEnabled, isTrue);
        expect(temp.isSleepPressureEnabled, isTrue);
        expect(temp.isSleepDebtEnabled, isTrue);
      },
    );

    test(
      'SettingsState.fromJson defaults missing keys to true for circadian and dimming',
      () {
        final emptyJson = <String, dynamic>{};
        final settings = SettingsState.fromJson(emptyJson);

        expect(settings.isSmartCircadianEnabled, isTrue);
        expect(settings.isWindDownMasterEnabled, isTrue);
        expect(settings.isTimeShiftMasterEnabled, isTrue);
        expect(settings.isSleepPressureMasterEnabled, isTrue);
        expect(settings.isSleepDebtMasterEnabled, isTrue);
        expect(settings.isWindDownEnabled, isTrue);
        expect(settings.isTimeShiftEnabled, isTrue);
        expect(settings.isSleepPressureEnabled, isTrue);
        expect(settings.isSleepDebtEnabled, isTrue);
        expect(settings.isSoftwareDimmingEnabled, isTrue);
      },
    );

    test('SettingsState.fromJson preserves explicit false values', () {
      final explicitFalseJson = <String, dynamic>{
        'isSmartCircadianEnabled': false,
        'isWindDownMasterEnabled': false,
        'isTimeShiftMasterEnabled': false,
        'isSleepPressureMasterEnabled': false,
        'isSleepDebtMasterEnabled': false,
        'isWindDownEnabled': false,
        'isTimeShiftEnabled': false,
        'isSleepPressureEnabled': false,
        'isSleepDebtEnabled': false,
        'isSoftwareDimmingEnabled': false,
      };

      final settings = SettingsState.fromJson(explicitFalseJson);

      expect(settings.isSmartCircadianEnabled, isFalse);
      expect(settings.isWindDownMasterEnabled, isFalse);
      expect(settings.isTimeShiftMasterEnabled, isFalse);
      expect(settings.isSleepPressureMasterEnabled, isFalse);
      expect(settings.isSleepDebtMasterEnabled, isFalse);
      expect(settings.isWindDownEnabled, isFalse);
      expect(settings.isTimeShiftEnabled, isFalse);
      expect(settings.isSleepPressureEnabled, isFalse);
      expect(settings.isSleepDebtEnabled, isFalse);
      expect(settings.isSoftwareDimmingEnabled, isFalse);
    });

    test('SettingsState serialization preserves values in toJson', () {
      final settings = SettingsState();
      final json = settings.toJson();

      expect(json['isSmartCircadianEnabled'], isTrue);
      expect(json['isWindDownMasterEnabled'], isTrue);
      expect(json['isTimeShiftMasterEnabled'], isTrue);
      expect(json['isSleepPressureMasterEnabled'], isTrue);
      expect(json['isSleepDebtMasterEnabled'], isTrue);
      expect(json['isWindDownEnabled'], isTrue);
      expect(json['isTimeShiftEnabled'], isTrue);
      expect(json['isSleepPressureEnabled'], isTrue);
      expect(json['isSleepDebtEnabled'], isTrue);
      expect(json['isSoftwareDimmingEnabled'], isTrue);
    });
  });
}
