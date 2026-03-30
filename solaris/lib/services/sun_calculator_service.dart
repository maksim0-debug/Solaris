import 'dart:async';
import 'package:solar_calculator/solar_calculator.dart';
import 'dart:math' as math;
import 'package:solar_calculator/src/sunriseSunsetCalculator.dart';
import '../models/solar_phase_model.dart';
import '../models/current_day_phase.dart';

/// Service for calculating solar phases based on location and time.
class SunCalculatorService {
  static final SunCalculatorService _instance =
      SunCalculatorService._internal();

  factory SunCalculatorService() => _instance;

  SunCalculatorService._internal();

  SolarPhaseModel? _cachedPhases;
  DateTime? _cacheDate;
  double? _lastLat;
  double? _lastLon;

  /// Calculates or retrieves from cache the solar phases for a given location and date.
  ///
  /// Results are converted from UTC to local time.
  Future<SolarPhaseModel> calculatePhases(
    double lat,
    double lon, [
    DateTime? date,
  ]) async {
    final targetDate = (date ?? DateTime.now()).toUtc();
    final dateOnly = DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    // Cache hit criteria: same date (day) and same location
    if (_cachedPhases != null &&
        _cacheDate == dateOnly &&
        _lastLat == lat &&
        _lastLon == lon) {
      return _cachedPhases!;
    }

    final solarCalc = SolarCalculator(
      Instant.fromDateTime(targetDate),
      lat,
      lon,
    );

    // The solar_calculator returns UTC times in Instant objects.
    // We convert them to DateTime (UTC) and then to Local time.
    // Golden Hour (morning): starts when sun is at -4 elevation (zenith 94.0)
    // and ends at +6 elevation (zenith 84.0).
    final morningGoldenStart = SunriseSunsetCalculator(
      Instant.fromDateTime(targetDate),
      lat,
      lon,
      sunZenithDistance: 94.0,
    ).calculateSunrise();

    final morningGoldenEnd = SunriseSunsetCalculator(
      Instant.fromDateTime(targetDate),
      lat,
      lon,
      sunZenithDistance: 84.0,
    ).calculateSunrise();

    // Golden Hour (evening): starts when sun is at +6 elevation (zenith 84.0)
    // and ends at -4 elevation (zenith 94.0).
    final eveningGoldenStart = SunriseSunsetCalculator(
      Instant.fromDateTime(targetDate),
      lat,
      lon,
      sunZenithDistance: 84.0,
    ).calculateSunset();

    final eveningGoldenEnd = SunriseSunsetCalculator(
      Instant.fromDateTime(targetDate),
      lat,
      lon,
      sunZenithDistance: 94.0,
    ).calculateSunset();

    final model = SolarPhaseModel(
      sunrise: solarCalc.sunriseTime.toUtcDateTime().toLocal(),
      sunset: solarCalc.sunsetTime.toUtcDateTime().toLocal(),
      goldenHourMorning: morningGoldenStart.toUtcDateTime().toLocal(),
      goldenHourMorningEnd: morningGoldenEnd.toUtcDateTime().toLocal(),
      goldenHourEvening: eveningGoldenStart.toUtcDateTime().toLocal(),
      goldenHourEveningEnd: eveningGoldenEnd.toUtcDateTime().toLocal(),
      civilTwilightBegin: solarCalc.morningCivilTwilight.begining
          .toUtcDateTime()
          .toLocal(),
      civilTwilightEnd: solarCalc.eveningCivilTwilight.ending
          .toUtcDateTime()
          .toLocal(),
      astronomicalDawn: solarCalc.morningAstronomicalTwilight.begining
          .toUtcDateTime()
          .toLocal(),
      civilDusk: solarCalc.eveningCivilTwilight.ending
          .toUtcDateTime()
          .toLocal(),
      solarNoon: solarCalc.sunTransitTime.toUtcDateTime().toLocal(),
      astronomicalDusk: solarCalc.eveningAstronomicalTwilight.ending
          .toUtcDateTime()
          .toLocal(),
    );

    // Update cache
    _cachedPhases = model;
    _cacheDate = dateOnly;
    _lastLat = lat;
    _lastLon = lon;

    return model;
  }

  /// Invalidates the current cache to force recalculation on next call.
  void updateLocation() {
    _cachedPhases = null;
    _lastLat = null;
    _lastLon = null;
  }

  /// Determines the current solar phase based on time.
  CurrentDayPhase getCurrentPhase(
    SolarPhaseModel phases,
    DateTime currentTime,
  ) {
    if (currentTime.isBefore(phases.civilTwilightBegin) ||
        currentTime.isAfter(phases.civilTwilightEnd)) {
      return CurrentDayPhase.deepNight;
    }

    // Golden Hour zones (Morning and Evening)
    // Morning Golden Hour: -4 to +6 elevation
    if (currentTime.isAfter(phases.goldenHourMorning) &&
        currentTime.isBefore(phases.goldenHourMorningEnd)) {
      return CurrentDayPhase.goldenHour;
    }

    if (currentTime.isAfter(phases.goldenHourEvening) &&
        currentTime.isBefore(phases.goldenHourEveningEnd)) {
      return CurrentDayPhase.goldenHour;
    }

    // Twilight zones (Civil)
    if (currentTime.isAfter(phases.civilTwilightBegin) &&
        currentTime.isBefore(phases.sunrise)) {
      return CurrentDayPhase.dawn;
    }

    if (currentTime.isAfter(phases.sunset) &&
        currentTime.isBefore(phases.civilTwilightEnd)) {
      return CurrentDayPhase.twilight;
    }

    // Zenith zone (2 hours around solar noon)
    final zenithStart = phases.solarNoon.subtract(const Duration(hours: 1));
    final zenithEnd = phases.solarNoon.add(const Duration(hours: 1));

    if (currentTime.isAfter(zenithStart) && currentTime.isBefore(zenithEnd)) {
      return CurrentDayPhase.zenith;
    }

    // Morning Spike (between morning golden hour and zenith)
    if (currentTime.isAfter(phases.goldenHourMorningEnd) &&
        currentTime.isBefore(zenithStart)) {
      return CurrentDayPhase.morningSpike;
    }

    // Default to zenith if it's broad daylight and none of the above
    return CurrentDayPhase.zenith;
  }

  /// Calculates current sun elevation in degrees.
  double getSunElevation(double lat, double lon, DateTime time) {
    final solarCalc = SolarCalculator(Instant.fromDateTime(time), lat, lon);
    return solarCalc.sunHorizontalPosition.elevation;
  }

  /// Calculates current sun azimuth in degrees.
  double getSunAzimuth(double lat, double lon, DateTime time) {
    final solarCalc = SolarCalculator(Instant.fromDateTime(time), lat, lon);
    return solarCalc.sunHorizontalPosition.azimuth;
  }

  /// Calculates current sun zenith distance in degrees.
  double getSunZenith(double lat, double lon, DateTime time) {
    final solarCalc = SolarCalculator(Instant.fromDateTime(time), lat, lon);
    return 90.0 - solarCalc.sunHorizontalPosition.elevation;
  }

  /// Calculates sun progress:
  /// 0.0 at sunrise, 0.5 at solar noon, 1.0 at sunset.
  /// Values < 0.0 or > 1.0 represent night.
  double getSunProgress(SolarPhaseModel phases, DateTime currentTime) {
    if (currentTime.isBefore(phases.sunrise)) {
      // Pre-sunrise (night)
      final prevSunset = phases.sunset.subtract(const Duration(days: 1));
      final nightDuration = phases.sunrise.difference(prevSunset).inSeconds;
      if (nightDuration == 0) return 0.0;
      return (currentTime.difference(prevSunset).inSeconds / nightDuration) -
          1.0;
    } else if (currentTime.isAfter(phases.sunset)) {
      // Post-sunset (night)
      final nextSunrise = phases.sunrise.add(const Duration(days: 1));
      final nightDuration = nextSunrise.difference(phases.sunset).inSeconds;
      if (nightDuration == 0) return 1.0;
      return 1.0 +
          (currentTime.difference(phases.sunset).inSeconds / nightDuration);
    } else {
      // Daylight
      final dayDuration = phases.sunset.difference(phases.sunrise).inSeconds;
      if (dayDuration == 0) return 0.5;
      return currentTime.difference(phases.sunrise).inSeconds / dayDuration;
    }
  }

  /// Calculates the duration until the next solar event.
  Duration getTimeUntilNextEvent(SolarPhaseModel phases, DateTime currentTime) {
    // Collect all significant transition points
    final events = [
      phases.civilTwilightBegin,
      phases.sunrise,
      phases.goldenHourMorning,
      phases.goldenHourMorningEnd,
      phases.solarNoon.subtract(const Duration(hours: 1)), // Zenith Start
      phases.solarNoon,
      phases.solarNoon.add(const Duration(hours: 1)), // Zenith End
      phases.goldenHourEvening,
      phases.goldenHourEveningEnd,
      phases.sunset,
      phases.civilTwilightEnd,
    ]..sort();

    for (final event in events) {
      if (event.isAfter(currentTime)) {
        return event.difference(currentTime);
      }
    }

    // If all events passed today, calculate time until next day's first event (civil twilight begin)
    final nextDayDawn = phases.civilTwilightBegin.add(const Duration(days: 1));
    return nextDayDawn.difference(currentTime);
  }

  /// Estimates clear-sky UV Index based on sun elevation using empirical approximations.
  double getUVIndex(double elevation) {
    if (elevation <= 0) return 0.0;
    // An empirical formula for clear-sky UVI: UVI is roughly proportional to (cos(zenith))^2.42
    // Zenith angle = 90 - elevation. cos(zenith) = sin(elevation).
    // Maximum UVI at the equator at sea level is roughly 11.5 - 12.5.
    final elevationRad = elevation * math.pi / 180.0;
    return 12.0 * math.pow(math.sin(elevationRad), 2.42);
  }

  /// Estimates clear-sky Spectral Intensity / Global Horizontal Irradiance (W/m2).
  double getSpectralIntensity(double elevation) {
    if (elevation <= 0) return 0.0;
    // Meinel & Meinel clear sky approximation model.
    final elevationRad = elevation * math.pi / 180.0;
    // Approximated optical air mass (AM) using simple formula
    final am =
        1.0 /
        (math.sin(elevationRad) + 0.15 * math.pow(elevation + 3.885, -1.253));
    // Solar constant roughly 1353 W/m2, attenuated by atmosphere (0.7 transmit factor)
    return 1353.0 * math.pow(0.7, math.pow(am, 0.678)) * math.sin(elevationRad);
  }

  /// Реалистичный расчет температуры поверхности (например, темного асфальта или почвы).
  /// Учитывает реальную температуру воздуха и приток солнечной радиации.
  double getEstimatedSurfaceTemp(
    double elevation,
    double airTemp, {
    double? realIrradiance,
  }) {
    if (elevation <= 0 && (realIrradiance == null || realIrradiance <= 0)) {
      // Ночью за счет радиационного выхолаживания открытая поверхность холоднее воздуха
      return airTemp - 2.5;
    }

    final irradiance = realIrradiance ?? getSpectralIntensity(elevation);

    // Более точная физическая модель: каждые 100 Вт/м2 нагревают среднестатистическую темную
    // поверхность (асфальт/грунт) примерно на 2.5-3.0 градуса выше температуры воздуха в безветренную погоду.
    final heatingFactor = (irradiance / 100.0) * 2.8;

    return airTemp + heatingFactor;
  }
}
