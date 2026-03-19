import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';

class CircadianService {
  /// Calculates the target brightness based on the 5-phase circadian curve.
  double calculateTargetBrightness(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    required double minBrightness,
    required double maxBrightness,
    required double transBrightness,
    double curveSharpness = 1.0,
    List<FlSpot>? curvePoints,
  }) {
    if (curvePoints != null && curvePoints.isNotEmpty) {
      final hour = now.hour + now.minute / 60.0 + now.second / 3600.0;
      return _calculateFromPoints(curvePoints, hour);
    }
    // 1. Morning Spike (Astronomical Dawn to sunrise + 1h)
    if (now.isBefore(phases.sunrise.add(const Duration(hours: 1))) &&
        now.isAfter(phases.astronomicalDawn)) {
      // Transition from minBrightness to transBrightness * 1.5 (max 90)
      final targetSpike = (transBrightness * 1.5).clamp(minBrightness, 90.0);
      
      // Range: -18 to 6 (approx 24 degrees)
      final progress = (elevation + 18) / 24.0;
      final clampedProgress = progress.clamp(0.0, 1.0);
      
      // Custom Easing based on sharpness: 1 - pow(1 - progress, sharpness)
      final double finalEased = 1.0 - _applySharpness(1.0 - clampedProgress, curveSharpness);
      
      return minBrightness + (targetSpike - minBrightness) * finalEased;
    }

    // 2. Solar Zenith (Day plateau)
    if (now.isAfter(phases.sunrise.add(const Duration(hours: 1))) &&
        now.isBefore(phases.sunset.subtract(const Duration(hours: 1)))) {
      return maxBrightness;
    }

    // 3. Golden Hour Downward (1 hour before sunset)
    if (now.isAfter(phases.sunset.subtract(const Duration(hours: 1))) &&
        now.isBefore(phases.sunset)) {
      final progress =
          (phases.sunset.difference(now).inSeconds) / 3600.0; // 1.0 to 0.0
      final clampedProgress = progress.clamp(0.0, 1.0);
      
      // Golden Hour easing
      final easedProgress = _applySharpness(clampedProgress, curveSharpness);

      return transBrightness + (maxBrightness - transBrightness) * easedProgress;
    }

    // 4. Civil Twilight (Sunset to Civil Dusk -6 degrees)
    if (now.isAfter(phases.sunset) && now.isBefore(phases.civilDusk)) {
      final progress = elevation / -6.0;
      final clampedProgress = progress.clamp(0.0, 1.0);
      
      // Evening transition
      final easedProgress = _applySharpness(clampedProgress, curveSharpness);
      
      return transBrightness - (transBrightness - minBrightness) * easedProgress;
    }

    return minBrightness;
  }

  double _calculateFromPoints(List<FlSpot> points, double hour) {
    if (points.isEmpty) return 15.0;

    // Ensure we handle wrapping for 24h
    final searchHour = hour % 24;

    for (int i = 0; i < points.length - 1; i++) {
      if (searchHour >= points[i].x && searchHour <= points[i + 1].x) {
        final p1 = points[i];
        final p2 = points[i + 1];
        if (p2.x == p1.x) return p1.y;
        final t = (searchHour - p1.x) / (p2.x - p1.x);
        return p1.y + (p2.y - p1.y) * t;
      }
    }
    
    return points.last.y;
  }

  double _applySharpness(double progress, double sharpness) {
    if (sharpness == 1.0) return progress;
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    
    return pow(progress, sharpness).toDouble();
  }
}
