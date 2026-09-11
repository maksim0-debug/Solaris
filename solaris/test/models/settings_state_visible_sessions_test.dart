import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsState sleepVisibleSessionsCount Tests', () {
    test('Default constructor sets default sleepVisibleSessionsCount to 5', () {
      final state = SettingsState();
      expect(state.sleepVisibleSessionsCount, equals(5));
    });

    test(
      'Backwards compatibility: fromJson without sleepVisibleSessionsCount defaults to 5',
      () {
        final oldJson = <String, dynamic>{
          'sleepToleranceWindow': 90,
          'sleepMaxAnomalies': 3,
        };

        final state = SettingsState.fromJson(oldJson);
        expect(state.sleepVisibleSessionsCount, equals(5));
      },
    );

    test('fromJson correctly parses custom sleepVisibleSessionsCount', () {
      final json = <String, dynamic>{'sleepVisibleSessionsCount': 10};

      final state = SettingsState.fromJson(json);
      expect(state.sleepVisibleSessionsCount, equals(10));
    });

    test('toJson correctly serializes sleepVisibleSessionsCount', () {
      final state = SettingsState(sleepVisibleSessionsCount: 7);

      final json = state.toJson();
      expect(json['sleepVisibleSessionsCount'], equals(7));
    });

    test(
      'copyWith updates sleepVisibleSessionsCount while preserving other fields',
      () {
        final state = SettingsState();
        final updated = state.copyWith(sleepVisibleSessionsCount: 3);

        expect(updated.sleepVisibleSessionsCount, equals(3));
        expect(
          state.sleepVisibleSessionsCount,
          equals(5),
        ); // Immutability check
      },
    );
  });
}
