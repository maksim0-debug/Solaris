import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _Settings extends SettingsNotifier {
  @override
  Future<Map<String, SettingsState>> build() async => {'all': SettingsState()};

  void replace(SettingsState settings) => state = AsyncData({'all': settings});
}

class _WeatherService extends WeatherService {
  int calls = 0;
  WeatherProvider? lastProvider;

  @override
  Future<WeatherData?> fetchCurrentWeather(
    double lat,
    double lon, {
    WeatherProvider provider = WeatherProvider.auto,
    String? customApiKey,
  }) async {
    calls++;
    lastProvider = provider;
    return null;
  }
}

Position _position(double latitude) => Position(
  latitude: latitude,
  longitude: 30.52,
  timestamp: DateTime.now(),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  late ProviderContainer container;
  late _WeatherService weather;
  late Position position;

  setUp(() async {
    weather = _WeatherService();
    position = _position(50.45);
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        weatherServiceProvider.overrideWithValue(weather),
        coordinatesAvailableProvider.overrideWithValue(true),
        effectiveLocationProvider.overrideWith((ref) => AsyncData(position)),
        effectiveTimezoneProvider.overrideWithValue(
          tz.getLocation('Europe/Kyiv'),
        ),
      ],
    );
    await container.read(settingsProvider.future);
    container.listen(solarStateStreamProvider, (_, _) {});
    await container.read(currentWeatherProvider.future);
    await container.read(solarStateStreamProvider.future);
  });
  tearDown(() => container.dispose());

  test(
    'brightness settings changes preserve solar state and do not fetch weather',
    () async {
      final initial = container.read(solarStateStreamProvider).value!;
      final emissions = <bool>[];
      final subscription = container.listen(solarStateStreamProvider, (
        _,
        next,
      ) {
        emissions.add(next.isLoading);
      });
      addTearDown(subscription.close);
      final initialCalls = weather.calls;

      for (var i = 0; i < 25; i++) {
        (container.read(settingsProvider.notifier) as _Settings).replace(
          SettingsState().copyWith(isAutoBrightnessEnabled: i.isEven),
        );
        await container.pump();
        expect(container.read(solarStateStreamProvider).value, same(initial));
      }

      expect(emissions, isEmpty);
      expect(weather.calls, initialCalls);
    },
  );

  test('weather refresh does not restart the solar stream', () async {
    final initial = container.read(solarStateStreamProvider).value!;
    final emissions = <bool>[];
    final subscription = container.listen(solarStateStreamProvider, (_, next) {
      emissions.add(next.isLoading);
    });
    addTearDown(subscription.close);
    final initialCalls = weather.calls;

    container.invalidate(currentWeatherProvider);
    await container.read(currentWeatherProvider.future);
    await container.pump();

    expect(weather.calls, initialCalls + 1);
    expect(container.read(solarStateStreamProvider).value, same(initial));
    expect(emissions, isEmpty);
  });

  test('location changes still recalculate solar phases', () async {
    final initial = container.read(solarStateStreamProvider).value!;
    position = _position(48.45);
    container.invalidate(effectiveLocationProvider);
    await container.pump();
    final updated = await container.read(solarStateStreamProvider.future);

    expect(updated, isNot(same(initial)));
    expect(updated.phases.sunrise, isNot(initial.phases.sunrise));
  });

  test(
    'weather configuration changes still fetch weather without resetting solar state',
    () async {
      final initial = container.read(solarStateStreamProvider).value!;
      final initialCalls = weather.calls;
      (container.read(settingsProvider.notifier) as _Settings).replace(
        SettingsState().copyWith(weatherProvider: WeatherProvider.openMeteo),
      );
      await container.pump();
      await container.read(currentWeatherProvider.future);

      expect(weather.calls, initialCalls + 1);
      expect(weather.lastProvider, WeatherProvider.openMeteo);
      expect(container.read(solarStateStreamProvider).value, same(initial));
    },
  );
}
