import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsState Game Mode Temperature Tests', () {
    test('Default constructor sets default game mode temperature values', () {
      final state = SettingsState();
      expect(state.isGameModeTemperatureEnabled, isTrue);
      expect(state.gameModeTemperature, equals(6500.0));
    });

    test('Backwards compatibility: fromJson with old JSON sets default values', () {
      final oldJson = <String, dynamic>{
        'isGameModeEnabled': true,
        'gameModeBrightness': 80.0,
        'gameModeExitDelaySeconds': 30,
      };

      final state = SettingsState.fromJson(oldJson);
      expect(state.isGameModeTemperatureEnabled, isTrue);
      expect(state.gameModeTemperature, equals(6500.0));
    });

    test('fromJson correctly parses custom game mode temperature settings', () {
      final json = <String, dynamic>{
        'isGameModeEnabled': true,
        'isGameModeTemperatureEnabled': false,
        'gameModeBrightness': 90.0,
        'gameModeTemperature': 4500.0,
        'gameModeExitDelaySeconds': 60,
      };

      final state = SettingsState.fromJson(json);
      expect(state.isGameModeTemperatureEnabled, isFalse);
      expect(state.gameModeTemperature, equals(4500.0));
    });

    test('toJson correctly serializes game mode temperature settings', () {
      final state = SettingsState(
        isGameModeTemperatureEnabled: true,
        gameModeTemperature: 5000.0,
      );

      final json = state.toJson();
      expect(json['isGameModeTemperatureEnabled'], isTrue);
      expect(json['gameModeTemperature'], equals(5000.0));
    });

    test('copyWith updates game mode temperature settings', () {
      final state = SettingsState();
      final updated = state.copyWith(
        isGameModeTemperatureEnabled: false,
        gameModeTemperature: 3500.0,
      );

      expect(updated.isGameModeTemperatureEnabled, isFalse);
      expect(updated.gameModeTemperature, equals(3500.0));
      expect(state.isGameModeTemperatureEnabled, isTrue); // Immutability check
    });
  });
}
