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
      timeOffset = actualWakeTime.difference(astronomicalSunrise);
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

    if (useWindDown && currentRegime != null) {
      final avgBedtimeMinutes = currentRegime.averageBedtimeNormalized;
      final nowMinutes = now.hour * 60 + now.minute;
      
      int minutesUntilSleep = avgBedtimeMinutes - nowMinutes;
      if (minutesUntilSleep < -720) minutesUntilSleep += 1440;
      if (minutesUntilSleep > 720) minutesUntilSleep -= 1440;

      if (minutesUntilSleep > 0 && minutesUntilSleep <= 120) {
        isWindDownActive = true;
        final progress = (120 - minutesUntilSleep) / 120.0;
        windDownFactor = 1.0 - (progress * 0.75);
        windDownTempOffset = -(progress * 4000).toInt();
      } else if (minutesUntilSleep <= 0 && minutesUntilSleep > -120) {
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
      sleepDebtFactor: sleepDebtFactor,
      sleepPressureFactor: sleepPressureFactor,
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
