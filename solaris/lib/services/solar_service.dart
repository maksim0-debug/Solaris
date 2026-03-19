import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'dart:math' as math;

class SolarData {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime goldenHourStart;
  final DateTime goldenHourEnd;
  final DateTime astronomicalDawn;
  final DateTime civilDusk;
  final double sunElevation; // in degrees
  final double sunProgress; // 0.0 at sunrise, 1.0 at sunset
  final bool isNight;

  SolarData({
    required this.sunrise,
    required this.sunset,
    required this.goldenHourStart,
    required this.goldenHourEnd,
    required this.astronomicalDawn,
    required this.civilDusk,
    required this.sunElevation,
    required this.sunProgress,
    required this.isNight,
  });
}

class SolarService {
  SolarData calculateSolarData(double lat, double lng, DateTime date) {
    final result = getSunriseSunset(lat, lng, Duration.zero, date);

    final sunrise = result.sunrise;
    final sunset = result.sunset;

    // Golden hour morning: roughly 1 hour after sunrise
    final goldenHourEnd = sunrise.add(const Duration(hours: 1));
    // Golden hour evening: roughly 1 hour before sunset
    final goldenHourStart = sunset.subtract(const Duration(hours: 1));

    // Civil Dusk: sun is 6 degrees below horizon
    // Astronomical Dawn: sun is 18 degrees below horizon
    // For simplicity with the provided package, we'll estimate or calculate them.
    // Actually, let's use the elevation calculation for everything.

    final elevation = calculateSunElevation(lat, lng, date);

    // Calculate progress (Day: 0.0 to 1.0)
    final totalDaylight = sunset.difference(sunrise).inSeconds;
    final currentProgressSeconds = date.difference(sunrise).inSeconds;

    double progress = currentProgressSeconds / totalDaylight;
    bool isNight = date.isBefore(sunrise) || date.isAfter(sunset);

    if (isNight) {
      if (date.isAfter(sunset)) {
        final nextSunrise = sunrise.add(const Duration(days: 1));
        final nightDuration = nextSunrise.difference(sunset).inSeconds;
        progress = 1.0 + (date.difference(sunset).inSeconds / nightDuration);
      } else {
        final prevSunset = sunset.subtract(const Duration(days: 1));
        final nightDuration = sunrise.difference(prevSunset).inSeconds;
        progress =
            -1.0 + (date.difference(prevSunset).inSeconds / nightDuration);
      }
    }

    return SolarData(
      sunrise: sunrise,
      sunset: sunset,
      goldenHourStart: goldenHourStart,
      goldenHourEnd: goldenHourEnd,
      astronomicalDawn: sunrise.subtract(const Duration(minutes: 90)), // Approx
      civilDusk: sunset.add(const Duration(minutes: 30)), // Approx
      sunElevation: elevation,
      sunProgress: progress,
      isNight: isNight,
    );
  }

  double calculateSunElevation(double lat, double lng, DateTime time) {
    // Standard approximation formula for solar elevation
    final phi = lat * math.pi / 180.0;

    // Julian Date calculation
    final julianDate =
        time.difference(DateTime.utc(1970, 1, 1)).inMilliseconds / 86400000.0 +
        2440587.5;
    final d = julianDate - 2451545.0; // Days since J2000

    // Solar coordinates
    final g = (357.529 + 0.98560028 * d) % 360.0;
    final q = (280.459 + 0.98564736 * d) % 360.0;
    final l =
        (q +
            1.915 * math.sin(g * math.pi / 180.0) +
            0.020 * math.sin(2 * g * math.pi / 180.0)) %
        360.0;

    final e = 23.439 - 0.00000036 * d; // Obliquity of ecliptic

    // Declination
    final delta = math.asin(
      math.sin(e * math.pi / 180.0) * math.sin(l * math.pi / 180.0),
    );

    // Local Sidereal Time
    final ut =
        time.toUtc().hour +
        time.toUtc().minute / 60.0 +
        time.toUtc().second / 3600.0;

    // Hour Angle
    final lst = (100.46 + 0.985647 * d + lng + 15 * ut) % 360.0;
    final ra =
        math.atan2(
          math.cos(e * math.pi / 180.0) * math.sin(l * math.pi / 180.0),
          math.cos(l * math.pi / 180.0),
        ) *
        180.0 /
        math.pi;
    var hAngle = (lst - ra + 360.0) % 360.0;
    if (hAngle > 180) hAngle -= 360;

    final hAngleRad = hAngle * math.pi / 180.0;

    // Elevation
    final sinH =
        math.sin(phi) * math.sin(delta) +
        math.cos(phi) * math.cos(delta) * math.cos(hAngleRad);
    final h = math.asin(sinH);

    return h * 180.0 / math.pi;
  }
}
