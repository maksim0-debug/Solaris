import 'package:solaris/models/solar_phase_model.dart';

class CircadianService {
  /// Base limits as requested: 100% max, 15% min.
  static const double maxBrightness = 100.0;
  static const double minBrightness = 15.0;

  /// Calculates the target brightness based on the 5-phase circadian curve.
  double calculateTargetBrightness(
    SolarPhaseModel phases,
    double elevation,
    DateTime now,
  ) {
    // 1. Morning Spike (Astronomical Dawn to sunrise + 1h)
    if (now.isBefore(phases.sunrise.add(const Duration(hours: 1))) &&
        now.isAfter(phases.astronomicalDawn)) {
      // Transition from 15% to 90%
      // Range: -18 to 6 (approx 24 degrees)
      final progress = (elevation + 18) / 24.0;
      final clampedProgress = progress.clamp(0.0, 1.0);
      // Ease-Out
      final easedProgress = 1 - (1 - clampedProgress) * (1 - clampedProgress);
      return minBrightness + (90.0 - minBrightness) * easedProgress;
    }

    // 2. Solar Zenith (Day plateau)
    // Between Morning end and Evening start
    if (now.isAfter(phases.sunrise.add(const Duration(hours: 1))) &&
        now.isBefore(phases.sunset.subtract(const Duration(hours: 1)))) {
      return maxBrightness;
    }

    // 3. Golden Hour Downward (1 hour before sunset)
    if (now.isAfter(phases.sunset.subtract(const Duration(hours: 1))) &&
        now.isBefore(phases.sunset)) {
      // Transition from 100% to 60%
      final progress =
          (phases.sunset.difference(now).inSeconds) / 3600.0; // 1.0 to 0.0
      final clampedProgress = progress.clamp(0.0, 1.0);
      // Ease-In-Out
      final easedProgress = clampedProgress < 0.5
          ? 2 * clampedProgress * clampedProgress
          : 1 - (-2 * clampedProgress + 2) * (-2 * clampedProgress + 2) / 2;

      return 60.0 + (maxBrightness - 60.0) * easedProgress;
    }

    // 4. Civil Twilight (Sunset to Civil Dusk -6 degrees)
    if (now.isAfter(phases.sunset) && now.isBefore(phases.civilDusk)) {
      // Transition from 60% to 25%
      // Elevation from 0 to -6
      final progress = elevation / -6.0;
      final clampedProgress = progress.clamp(0.0, 1.0);
      return 60.0 - (60.0 - 25.0) * clampedProgress;
    }

    // 5. Deep Night (Full darkness)
    return minBrightness;
  }
}
