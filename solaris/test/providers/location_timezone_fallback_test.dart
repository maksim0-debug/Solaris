import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/location_settings.dart' as model;
import 'package:solaris/providers.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('LocationResolutionStatus Provider Tests', () {
    test('resolves to manual when useManual is true and coordinates are set', () async {
      final container = ProviderContainer(
        overrides: [
          locationSettingsProvider.overrideWith(
            () => _FakeLocationSettingsNotifier(
              const model.LocationSettings(
                useManual: true,
                manualLatitude: 50.45,
                manualLongitude: 30.52,
              ),
            ),
          ),
          locationStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSettingsProvider.future);

      final status = container.read(locationResolutionStatusProvider);
      final coordsAvailable = container.read(coordinatesAvailableProvider);

      expect(status, equals(LocationResolutionStatus.manual));
      expect(coordsAvailable, isTrue);
    });

    test('resolves to autoSuccess when useManual is false and stream emits position', () async {
      final mockPos = Position(
        latitude: 49.80,
        longitude: 30.12,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      final container = ProviderContainer(
        overrides: [
          locationSettingsProvider.overrideWith(
            () => _FakeLocationSettingsNotifier(
              const model.LocationSettings(useManual: false),
            ),
          ),
          locationStreamProvider.overrideWith(
            (ref) => Stream.value(mockPos),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSettingsProvider.future);
      final sub = container.listen(locationStreamProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final status = container.read(locationResolutionStatusProvider);
      final coordsAvailable = container.read(coordinatesAvailableProvider);

      expect(status, equals(LocationResolutionStatus.autoSuccess));
      expect(coordsAvailable, isTrue);
      sub.close();
    });

    test('resolves to autoFailedTimezone when useManual is true but coordinates are null', () async {
      final container = ProviderContainer(
        overrides: [
          locationSettingsProvider.overrideWith(
            () => _FakeLocationSettingsNotifier(
              const model.LocationSettings(
                useManual: true,
                manualLatitude: null,
                manualLongitude: null,
              ),
            ),
          ),
          locationStreamProvider.overrideWith(
            (ref) => Stream.value(
              Position(
                latitude: 49.80,
                longitude: 30.12,
                timestamp: DateTime.now(),
                accuracy: 10,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSettingsProvider.future);

      final status = container.read(locationResolutionStatusProvider);
      expect(status, equals(LocationResolutionStatus.autoFailedTimezone));
    });

    test('resolves to autoFailedTimezone when useManual is false and stream is empty', () async {
      final container = ProviderContainer(
        overrides: [
          locationSettingsProvider.overrideWith(
            () => _FakeLocationSettingsNotifier(
              const model.LocationSettings(useManual: false),
            ),
          ),
          locationStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSettingsProvider.future);

      final status = container.read(locationResolutionStatusProvider);
      final coordsAvailable = container.read(coordinatesAvailableProvider);

      expect(status, equals(LocationResolutionStatus.autoFailedTimezone));
      expect(coordsAvailable, isFalse);
    });

    test('getTimezoneFallbackCoordinates returns representative coordinates for major timezones', () {
      final nyTz = tz.getLocation('America/New_York');
      final tokyoTz = tz.getLocation('Asia/Tokyo');
      final londonTz = tz.getLocation('Europe/London');
      final kyivTz = tz.getLocation('Europe/Kyiv');

      final nyPos = getTimezoneFallbackCoordinates(nyTz);
      final tokyoPos = getTimezoneFallbackCoordinates(tokyoTz);
      final londonPos = getTimezoneFallbackCoordinates(londonTz);
      final kyivPos = getTimezoneFallbackCoordinates(kyivTz);

      expect(nyPos.latitude, closeTo(40.71, 0.1));
      expect(nyPos.longitude, closeTo(-74.00, 0.1));

      expect(tokyoPos.latitude, closeTo(35.67, 0.1));
      expect(tokyoPos.longitude, closeTo(139.65, 0.1));

      expect(londonPos.latitude, closeTo(51.50, 0.1));
      expect(londonPos.longitude, closeTo(-0.12, 0.1));

      expect(kyivPos.latitude, closeTo(50.45, 0.1));
      expect(kyivPos.longitude, closeTo(30.52, 0.1));
    });

    test('currentWeatherProvider returns null when coordinates are unavailable', () async {
      final container = ProviderContainer(
        overrides: [
          locationSettingsProvider.overrideWith(
            () => _FakeLocationSettingsNotifier(
              const model.LocationSettings(useManual: false),
            ),
          ),
          locationStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(locationSettingsProvider.future);

      final weatherAsync = container.read(currentWeatherProvider);
      expect(weatherAsync.value, isNull);
    });
  });
}

class _FakeLocationSettingsNotifier extends LocationSettingsNotifier {
  final model.LocationSettings _initial;
  _FakeLocationSettingsNotifier(this._initial);

  @override
  Future<model.LocationSettings> build() async => _initial;
}
