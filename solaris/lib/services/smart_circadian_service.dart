import 'dart:math' as math;
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/utils/bedtime_normalization.dart';

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
    int? windDownDurationMinutes = 120,
    int? timeShiftDurationMinutes = 360,
    double? sleepPressureWakeLimitHours = 16.0,
    int? sleepDebtThresholdMinutes = 390,
  }) {
    final int windDownDur = windDownDurationMinutes ?? 120;
    final int timeShiftDur = timeShiftDurationMinutes ?? 360;
    final double sleepPressureLimit = sleepPressureWakeLimitHours ?? 16.0;
    final int sleepDebtThreshold = sleepDebtThresholdMinutes ?? 390;

    if (sleepState.regimes.isEmpty) return const SmartCircadianData.neutral();

    // 1. Get Quality Data from NightGroups
    final currentRegime = _getCurrentRegime(sleepState.regimes);
    if (currentRegime == null || currentRegime.nights.isEmpty)
      return const SmartCircadianData.neutral();

    // Key Sleep Metric: The most recent "Night" (aggregated sessions)
    final NightGroup lastNight = currentRegime
        .nights
        .first; // Reordered to show newest first in analysis
    final SleepSession lastAggSession = lastNight.aggregatedSession;

    // 2. Dynamic Bedtime Anchor (Override for tonight)
    int effectiveBedtimeMinutes = currentRegime.averageBedtimeNormalized;

    // If the last bedtime deviated by more than 1.5 hours, shift tonight's target halfway
    // to accommodate "weekend mode" or schedule shifts without breaking the regime.
    final lastBedtimeMinutes = BedtimeNormalization.minutesFromNoon(
      lastAggSession.startTime,
    );
    int bedtimeDev =
        lastBedtimeMinutes - currentRegime.averageBedtimeNormalized;
    while (bedtimeDev > 720) bedtimeDev -= 1440;
    while (bedtimeDev < -720) bedtimeDev += 1440;

    if (bedtimeDev.abs() > 90) {
      effectiveBedtimeMinutes += (bedtimeDev * 0.5).toInt();
    }

    // 3. Bio-Morning Shift (Time Offset)
    Duration timeOffset = Duration.zero;
    int? timeShiftMinutesRemaining;

    if (useTimeShift) {
      final actualWakeTime = lastAggSession.endTime;
      final timeSinceWake = now.difference(actualWakeTime);

      // Only shift if awake for less than 24h
      if (timeSinceWake.inHours < 24) {
        // Shift relative to average wake time, not sunset
        final avgWakeMin = currentRegime.averageWakeTimeNormalized;
        final actualWakeMin = BedtimeNormalization.minutesFromNoon(
          actualWakeTime,
        );

        int diffMinutes = actualWakeMin - avgWakeMin;
        while (diffMinutes > 720) diffMinutes -= 1440;
        while (diffMinutes < -720) diffMinutes += 1440;

        // Apply intensity and cap (max 3 hours shift)
        final double maxBioShift = 180.0;
        final double effectiveDiff = diffMinutes
            .clamp(-maxBioShift, maxBioShift)
            .toDouble();

        // FADEOUT: Gradually reduce time shift over X minutes
        double fadeFactor = 1.0;
        if (timeSinceWake.inMinutes < timeShiftDur) {
          fadeFactor =
              1.0 -
              (timeSinceWake.inMinutes /
                  (timeShiftDur > 0 ? timeShiftDur.toDouble() : 1.0));
          timeShiftMinutesRemaining = timeShiftDur - timeSinceWake.inMinutes;
        } else {
          fadeFactor = 0.0;
        }

        final double adjustedIntensity = math
            .pow(timeShiftIntensity, 2.0)
            .toDouble();
        timeOffset = Duration(
          minutes: (effectiveDiff * adjustedIntensity * fadeFactor).toInt(),
        );
      }
    }

    // 4. Sleep Debt Compensation
    double sleepDebtFactor = 1.0;
    int sleepDebtTempOffset = 0;
    // Use aggregated duration to avoid false alarms from fragmented sleep
    if (useSleepDebt &&
        lastAggSession.duration.inMinutes < sleepDebtThreshold) {
      final double adjBrightnessIntensity = math
          .pow(sleepDebtBrightnessIntensity, 1.5)
          .toDouble();
      final double adjTemperatureIntensity = math
          .pow(sleepDebtTemperatureIntensity, 1.5)
          .toDouble();

      sleepDebtFactor = 1.0 - (0.2 * adjBrightnessIntensity);
      sleepDebtTempOffset = (-500 * adjTemperatureIntensity).toInt();
    }

    // 5. Sleep Pressure (Time since wake)
    double sleepPressureFactor = 1.0;
    if (useSleepPressure) {
      final actualWakeTime = lastAggSession.endTime;
      final timeSinceWake = now.difference(actualWakeTime);

      // Ignore very short sleep sessions/naps for reset
      final isRealSleep = lastAggSession.duration.inMinutes >= 120;

      if (isRealSleep && timeSinceWake.inHours >= sleepPressureLimit) {
        final hoursOver = timeSinceWake.inMinutes / 60.0 - sleepPressureLimit;
        final baseFactor = math.pow(0.95, hoursOver).toDouble();
        final double adjIntensity = math
            .pow(sleepPressureBrightnessIntensity, 1.5)
            .toDouble();

        sleepPressureFactor = 1.0 - (1.0 - baseFactor) * adjIntensity;
      }
    }

    // 6. Wind-down Phase (Safe logic)
    double windDownFactor = 1.0;
    int windDownTempOffset = 0;
    bool isWindDownActive = false;
    int? minutesUntilSleep;

    if (useWindDown) {
      final nowMinutes = BedtimeNormalization.minutesFromNoon(now);

      int minsLeft = effectiveBedtimeMinutes - nowMinutes;
      // Handle noon-based wrap
      while (minsLeft > 720) minsLeft -= 1440;
      while (minsLeft < -720) minsLeft += 1440;

      minutesUntilSleep = minsLeft;

      // Wind-down starts X minutes before bedtime
      if (minsLeft > 0 && minsLeft <= windDownDur) {
        isWindDownActive = true;
        final progress =
            (windDownDur - minsLeft) /
            (windDownDur > 0 ? windDownDur.toDouble() : 1.0);

        final double adjBrightnessIntensity = math
            .pow(windDownBrightnessIntensity, 1.5)
            .toDouble();
        final double adjTemperatureIntensity = math
            .pow(windDownTemperatureIntensity, 1.5)
            .toDouble();

        windDownFactor = 1.0 - (progress * 0.75 * adjBrightnessIntensity);
        windDownTempOffset = -(progress * 4000 * adjTemperatureIntensity)
            .toInt();
      }
      // After bedtime: NO MORE SHARP CUTOFF
      // Stay in deep night mode until 4 AM (or 2 hours before avg wake)
      else if (minsLeft <= 0) {
        final avgWakeMinutes = currentRegime.averageWakeTimeNormalized;
        int minsUntilMorning = avgWakeMinutes - nowMinutes;
        while (minsUntilMorning > 720) minsUntilMorning -= 1440;
        while (minsUntilMorning < -720) minsUntilMorning += 1440;

        // Morning transition (fade out deep night over 60 mins before expected wake)
        if (minsUntilMorning > 0 && minsUntilMorning <= 60) {
          isWindDownActive = true;
          final morningProgress = 1.0 - (60 - minsUntilMorning) / 60.0;

          final double adjBrightnessIntensity = math
              .pow(windDownBrightnessIntensity, 1.5)
              .toDouble();
          final double adjTemperatureIntensity = math
              .pow(windDownTemperatureIntensity, 1.5)
              .toDouble();

          windDownFactor =
              1.0 - (morningProgress * 0.75 * adjBrightnessIntensity);
          windDownTempOffset =
              -(morningProgress * 4000 * adjTemperatureIntensity).toInt();
        }
        // If we're between bedtime and the morning transition, stay at max factor
        else if (minsUntilMorning > 60) {
          isWindDownActive = true;
          final double adjBrightnessIntensity = math
              .pow(windDownBrightnessIntensity, 1.5)
              .toDouble();
          final double adjTemperatureIntensity = math
              .pow(windDownTemperatureIntensity, 1.5)
              .toDouble();

          windDownFactor = 1.0 - (0.75 * adjBrightnessIntensity);
          windDownTempOffset = -(4000 * adjTemperatureIntensity).toInt();
        }
      }
    }

    int? windDownMinutesRemaining;
    int? minutesUntilWakeUpValue;
    if (isWindDownActive) {
      if (minutesUntilSleep != null && minutesUntilSleep > 0) {
        windDownMinutesRemaining = minutesUntilSleep;
      } else {
        // We're past bedtime, calculate minutes until the expected wake-up
        final nowMinutes = BedtimeNormalization.minutesFromNoon(now);
        final avgWakeMinutes = currentRegime.averageWakeTimeNormalized;
        int minsUntilMorning = avgWakeMinutes - nowMinutes;
        while (minsUntilMorning > 720) minsUntilMorning -= 1440;
        while (minsUntilMorning < -720) minsUntilMorning += 1440;

        if (minsUntilMorning > 0) {
          minutesUntilWakeUpValue = minsUntilMorning;
        }
      }
    }

    // 7. Temperature Logic Scaling
    // Instead of raw subtraction, let's keep it capped to prevent weird colors
    // and ideally factor in the base temperature if it's already low.

    // 8. Combine
    return SmartCircadianData(
      brightnessMultiplier:
          (sleepDebtFactor * sleepPressureFactor * windDownFactor).clamp(
            0.1,
            1.0,
          ),
      temperatureOffset: sleepDebtTempOffset + windDownTempOffset,
      timeOffset: timeOffset,
      isWindDownActive: isWindDownActive,
      isSleepPressureActive: sleepPressureFactor < 0.99,
      isSleepDebtActive: sleepDebtFactor < 0.99,
      isTimeShiftActive:
          timeOffset.inMinutes.abs() > 5 &&
          (timeShiftMinutesRemaining ?? 0) > 0,
      sleepDebtFactor: sleepDebtFactor,
      sleepPressureFactor: sleepPressureFactor,
      windDownFactor: windDownFactor,
      timeShiftMinutesRemaining: timeShiftMinutesRemaining,
      windDownMinutesRemaining: windDownMinutesRemaining,
      minutesUntilSleep: minutesUntilSleep,
      minutesUntilWakeUp: minutesUntilWakeUpValue,
    );
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
