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
    double sleepDebtBrightnessIntensity = 1.0,
    double sleepDebtTemperatureIntensity = 1.0,
    double sleepPressureBrightnessIntensity = 1.0,
    double timeShiftIntensity = 1.0,
    double windDownBrightnessIntensity = 1.0,
    double windDownTemperatureIntensity = 1.0,
  }) {
    if (sleepState.sessions.isEmpty) return const SmartCircadianData.neutral();

    // 1. Get Latest Data
    final lastSession = _getLatestSession(sleepState.sessions);
    final currentRegime = _getCurrentRegime(sleepState.regimes);
    
    if (lastSession == null) return const SmartCircadianData.neutral();

    // 2. Bio-Morning Shift (Time Offset)
    Duration timeOffset = Duration.zero;
    int? timeShiftMinutesRemaining;

    if (useTimeShift) {
      final actualWakeTime = lastSession.endTime;
      
      // Calculate only if the session is recent (ended within last 24h)
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

        // Apply intensity and cap
        if (diffMinutes.abs() <= 720) {
          // --- SMART ADJUSTMENT ---
          // 1. Cap the 'effective' difference to 3 hours (180 mins) to prevent huge jumps
          // 2. Apply power function to intensity to make the slider feel more linear 
          //    on the non-linear solar curve.
          final double maxBioShift = 180.0;
          final double effectiveDiff = diffMinutes.clamp(-maxBioShift, maxBioShift).toDouble();
          final double adjustedIntensity = math.pow(timeShiftIntensity, 2.0).toDouble();
          
          timeOffset = Duration(minutes: (effectiveDiff * adjustedIntensity).toInt());

          // Bio-Morning remains active for 6 hours (360 mins) after wake-up
          final remaining = 360 - timeSinceWake.inMinutes;
          if (remaining > 0) {
            timeShiftMinutesRemaining = remaining;
          } else {
            // After 6 hours, we start gradually reducing the shift or just disable it
            // For now, let's just mark it as not "Active" in terms of showing a countdown
            // but keep the offset for the rest of the 24h cycle if needed, 
            // OR we can cap the active status. 
            // The user wants a countdown, so we only show it while 'remaining' > 0.
          }
        }
      }
    }

    // 3. Sleep Debt Compensation
    double sleepDebtFactor = 1.0;
    int sleepDebtTempOffset = 0;
    if (useSleepDebt && lastSession.duration.inMinutes < 390) { // 6.5 hours
      final double adjBrightnessIntensity = math.pow(sleepDebtBrightnessIntensity, 1.5).toDouble();
      final double adjTemperatureIntensity = math.pow(sleepDebtTemperatureIntensity, 1.5).toDouble();
      
      sleepDebtFactor = 1.0 - (0.2 * adjBrightnessIntensity);
      sleepDebtTempOffset = (-500 * adjTemperatureIntensity).toInt();
    }

    // 4. Sleep Pressure (Time since wake)
    double sleepPressureFactor = 1.0;
    if (useSleepPressure) {
      final actualWakeTime = lastSession.endTime;
      final timeSinceWake = now.difference(actualWakeTime);
      if (timeSinceWake.inHours >= 16) {
        final hoursOver = timeSinceWake.inMinutes / 60.0 - 16.0;
        final baseFactor = math.pow(0.95, hoursOver).toDouble();
        final double adjIntensity = math.pow(sleepPressureBrightnessIntensity, 1.5).toDouble();
        
        sleepPressureFactor = 1.0 - (1.0 - baseFactor) * adjIntensity;
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
        
        final double adjBrightnessIntensity = math.pow(windDownBrightnessIntensity, 1.5).toDouble();
        final double adjTemperatureIntensity = math.pow(windDownTemperatureIntensity, 1.5).toDouble();
        
        windDownFactor = 1.0 - (progress * 0.75 * adjBrightnessIntensity);
        windDownTempOffset = -(progress * 4000 * adjTemperatureIntensity).toInt();
      } else if (minsLeft <= 0 && minsLeft > -120) {
        isWindDownActive = true;
        
        final double adjBrightnessIntensity = math.pow(windDownBrightnessIntensity, 1.5).toDouble();
        final double adjTemperatureIntensity = math.pow(windDownTemperatureIntensity, 1.5).toDouble();
        
        windDownFactor = 1.0 - (0.75 * adjBrightnessIntensity);
        windDownTempOffset = -(4000 * adjTemperatureIntensity).toInt();
      }
    }

    int? windDownMinutesRemaining;
    if (isWindDownActive && minutesUntilSleep != null) {
      if (minutesUntilSleep > 0) {
        windDownMinutesRemaining = minutesUntilSleep;
      } else {
        // If we're past bedtime but within the 2h grace period
        windDownMinutesRemaining = 120 + minutesUntilSleep; // e.g. 120 + (-10) = 110 mins left of "sleep state"
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
      isTimeShiftActive: timeOffset.inMinutes.abs() > 5 && (timeShiftMinutesRemaining ?? 0) > 0,
      sleepDebtFactor: sleepDebtFactor,
      sleepPressureFactor: sleepPressureFactor,
      windDownFactor: windDownFactor,
      timeShiftMinutesRemaining: timeShiftMinutesRemaining,
      windDownMinutesRemaining: windDownMinutesRemaining,
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
