import 'dart:math' as math;
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';

class SmartCircadianService {
  /// Calculates all biometric adjustments based on sleep data.
  SmartCircadianData calculateSmartAdjustments({
    required SleepState sleepState,
    required DateTime now,
    required DateTime astronomicalSunrise,
    bool useSleepDebt = true,
    bool useSleepPressure = true,
    bool useTimeShift = true,
    bool useWindDown = true,
  }) {
    if (sleepState.sessions.isEmpty) return const SmartCircadianData.neutral();

    // 1. Get Latest Data
    final lastSession = _getLatestSession(sleepState.sessions);
    final currentRegime = _getCurrentRegime(sleepState.regimes);
    
    if (lastSession == null) return const SmartCircadianData.neutral();

    // 2. Bio-Morning Shift (Time Offset)
    Duration timeOffset = Duration.zero;
    if (useTimeShift) {
      final actualWakeTime = lastSession.endTime;
      
      // Calculate only if the session is recent (ended within last 24h)
      // This supports completely irregular/broken schedules.
      final timeSinceWake = now.difference(actualWakeTime);
      
      if (timeSinceWake.inHours < 24) {
        // Normalize wake time to the same day as sunrise for comparison of "clock time"
        final normalizedWake = DateTime(
          astronomicalSunrise.year,
          astronomicalSunrise.month,
          astronomicalSunrise.day,
          actualWakeTime.hour,
          actualWakeTime.minute,
        );
        
        var diffMinutes = normalizedWake.difference(astronomicalSunrise).inMinutes;
        
        // Handle day wraps (e.g. wake up at 1 AM, sunrise at 6 AM -> -5h offset, not +19h)
        if (diffMinutes > 720) diffMinutes -= 1440;
        if (diffMinutes < -720) diffMinutes += 1440;

        // Cap the offset to 12 hours (half a day)
        // This allows for inverted schedules (night shifts).
        if (diffMinutes.abs() <= 720) {
          timeOffset = Duration(minutes: diffMinutes);
        }
      }
    }

    // 3. Sleep Debt Compensation
    double sleepDebtFactor = 1.0;
    int sleepDebtTempOffset = 0;
    if (useSleepDebt && lastSession.duration.inMinutes < 390) { // 6.5 hours
      sleepDebtFactor = 0.8;
      sleepDebtTempOffset = -500;
    }

    // 4. Sleep Pressure (Time since wake)
    double sleepPressureFactor = 1.0;
    if (useSleepPressure) {
      final actualWakeTime = lastSession.endTime;
      final timeSinceWake = now.difference(actualWakeTime);
      if (timeSinceWake.inHours >= 16) {
        final hoursOver = timeSinceWake.inMinutes / 60.0 - 16.0;
        sleepPressureFactor = math.pow(0.95, hoursOver).toDouble();
      }
    }

    // 5. Wind-down Phase
    double windDownFactor = 1.0;
    int windDownTempOffset = 0;
    bool isWindDownActive = false;
    int? minutesUntilSleep;

    if (useWindDown && currentRegime != null) {
      final avgBedtimeMinutes = currentRegime.averageBedtimeNormalized;
      final nowMinutes = now.hour * 60 + now.minute;
      
      int minsLeft = avgBedtimeMinutes - nowMinutes;
      if (minsLeft < -720) minsLeft += 1440;
      if (minsLeft > 720) minsLeft -= 1440;

      minutesUntilSleep = minsLeft;

      if (minsLeft > 0 && minsLeft <= 120) {
        isWindDownActive = true;
        final progress = (120 - minsLeft) / 120.0;
        windDownFactor = 1.0 - (progress * 0.75);
        windDownTempOffset = -(progress * 4000).toInt();
      } else if (minsLeft <= 0 && minsLeft > -120) {
        isWindDownActive = true;
        windDownFactor = 0.25;
        windDownTempOffset = -4000;
      }
    }

    // 6. Combine
    return SmartCircadianData(
      brightnessMultiplier: (sleepDebtFactor * sleepPressureFactor * windDownFactor).clamp(0.1, 1.0),
      temperatureOffset: sleepDebtTempOffset + windDownTempOffset,
      timeOffset: timeOffset,
      isWindDownActive: isWindDownActive,
      isSleepPressureActive: sleepPressureFactor < 0.99,
      isSleepDebtActive: sleepDebtFactor < 0.99,
      isTimeShiftActive: timeOffset.inMinutes.abs() > 5,
      sleepDebtFactor: sleepDebtFactor,
      sleepPressureFactor: sleepPressureFactor,
      minutesUntilSleep: minutesUntilSleep,
    );

  }

  SleepSession? _getLatestSession(List<SleepSession> sessions) {
    if (sessions.isEmpty) return null;
    return sessions.reduce((a, b) => a.endTime.isAfter(b.endTime) ? a : b);
  }

  SleepRegime? _getCurrentRegime(List<SleepRegime> regimes) {
    if (regimes.isEmpty) return null;
    try {
      return regimes.firstWhere((r) => r.isCurrent);
    } catch (_) {
      return regimes.first;
    }
  }
}
