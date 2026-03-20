import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class TerminatorService {
  /// Calculates the sun's declination and equation of time for a given [time] (UTC).
  /// Returns a Map with 'declination' (radians) and 'eqTime' (minutes).
  Map<String, double> _calculateSunPosition(DateTime time) {
    final dayOfYear = _getDayOfYear(time);
    final hour = time.hour + time.minute / 60.0 + time.second / 3600.0;

    // Fractional year in radians
    final gamma = (2 * math.pi / 365.0) * (dayOfYear - 1 + (hour - 12) / 24.0);

    // Equation of time in minutes
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    // Declination in radians
    final declination = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    return {'declination': declination, 'eqTime': eqTime};
  }

  int _getDayOfYear(DateTime time) {
    final diff = time.difference(DateTime.utc(time.year, 1, 1));
    return diff.inDays + 1;
  }

  /// Calculates the subsolar point (latitude, longitude) for a given [time] (UTC).
  LatLng getSubsolarPoint(DateTime time) {
    final pos = _calculateSunPosition(time);
    final declination = pos['declination']!;
    final eqTime = pos['eqTime']!;

    final lat = declination * 180.0 / math.pi;

    // Universal Time in minutes
    final utMinutes = time.hour * 60.0 + time.minute + time.second / 60.0;
    
    // Solar longitude
    var lon = 180.0 - (utMinutes + eqTime) / 4.0;
    
    // Normalize to [-180, 180]
    while (lon > 180) lon -= 360;
    while (lon < -180) lon += 360;

    return LatLng(lat, lon);
  }

  /// Generates a list of coordinates for the night side polygon.
  /// Uses a more robust approach for 2D maps by calculating latitude for each longitude.
  List<LatLng> getTerminatorPoints(DateTime time) {
    final subsolar = getSubsolarPoint(time);
    final sunLat = subsolar.latitude * math.pi / 180.0;
    final sunLon = subsolar.longitude * math.pi / 180.0;

    final points = <LatLng>[];

    // We calculate the terminator latitude for each longitude from -180 to 180
    // formula: tan(lat) = -cos(lon - sunLon) / tan(sunLat)
    for (var lonDeg = -180; lonDeg <= 180; lonDeg += 2) {
      final lonRad = lonDeg * math.pi / 180.0;
      final latRad = math.atan(-math.cos(lonRad - sunLon) / math.tan(sunLat));
      points.add(LatLng(latRad * 180.0 / math.pi, lonDeg.toDouble()));
    }

    // Now we need to close the polygon to cover the night side.
    // If sun is in Northern hemisphere (sunLat > 0), the South pole is in night.
    // If sun is in Southern hemisphere (sunLat < 0), the North pole is in night.
    if (sunLat > 0) {
      // South pole is in night
      points.add(LatLng(-90, 180));
      points.add(LatLng(-90, -180));
    } else {
      // North pole is in night
      points.add(LatLng(90, 180));
      points.add(LatLng(90, -180));
    }

    return points;
  }
}
