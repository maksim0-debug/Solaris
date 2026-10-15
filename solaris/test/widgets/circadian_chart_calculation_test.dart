import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/widgets/circadian_chart.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../helpers/brightness_fixtures.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.settings);
  final SettingsState settings;
  @override
  Future<Map<String, SettingsState>> build() async => {'all': settings};
}

class _Weather extends WeatherNotifier {
  _Weather(this.weather);
  final WeatherData? weather;
  @override
  Future<WeatherData?> build() async => weather;
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  Future<ProviderContainer> render(
    WidgetTester tester, {
    WeatherData? weather,
    bool weatherEnabled = false,
    bool solarReady = true,
    DateTime? now,
    List<FlSpot> points = const [
      FlSpot(-20, 40),
      FlSpot(30, 24),
      FlSpot(90, 20),
    ],
  }) async {
    final settings = SettingsState(
      circadianMode: CircadianMode.normalizedCurve,
      activePreset: PresetType.custom,
      isSmartCircadianEnabled: false,
      isWeatherAdjustmentEnabled: weatherEnabled,
      curvesMap: {
        ...PresetConstants.getAllDefaults(),
        PresetType.custom: points,
      },
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => _Settings(settings)),
        currentWeatherProvider.overrideWith(() => _Weather(weather)),
        solarStateStreamProvider.overrideWith(
          (ref) => solarReady
              ? Stream.value(brightnessTestSolar())
              : const Stream.empty(),
        ),
        minuteTimeProvider.overrideWith(
          (ref) => Stream.value(now ?? brightnessTestNoon),
        ),
        effectiveTimezoneProvider.overrideWithValue(
          tz.getLocation('Europe/Kyiv'),
        ),
        effectiveLocationProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    await container.read(currentWeatherProvider.future);
    container.listen(solarStateStreamProvider, (_, _) {});
    if (solarReady) await container.read(solarStateStreamProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 760, child: CircadianChartWidget()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'curve, marker and automatic calculation use the same interpolation',
    (tester) async {
      await render(tester);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData.first.isCurved, isFalse);
      expect(data.lineBarsData.first.spots, const [
        FlSpot(-20, 40),
        FlSpot(30, 24),
        FlSpot(90, 20),
      ]);
      for (final bar in data.lineBarsData.skip(1)) {
        expect(bar.spots.single, const FlSpot(30, 24));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weather marker uses the full curve minimum rather than the night point',
    (tester) async {
      await render(
        tester,
        weather: brightnessTestWeather(),
        weatherEnabled: true,
      );
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData.last.spots.single, const FlSpot(30, 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weather marker obeys the same active time window as control', (
    tester,
  ) async {
    await render(
      tester,
      weather: brightnessTestWeather(),
      weatherEnabled: true,
      now: brightnessTestPhases().astronomicalDusk,
    );
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData.length, 4);
    expect(data.lineBarsData.last.spots.single, const FlSpot(30, 24));
  });

  testWidgets('loading solar data does not invent a horizon marker', (
    tester,
  ) async {
    await render(tester, solarReady: false);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty preset does not crash the editor', (tester) async {
    await render(tester, points: const []);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Calculation unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
