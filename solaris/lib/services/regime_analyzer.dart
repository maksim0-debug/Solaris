import '../models/sleep_regime.dart';
import '../models/sleep_session.dart';
import '../models/night_group.dart';
import '../models/regime_settings.dart';
import '../utils/session_grouper.dart';
import '../utils/bedtime_normalization.dart';

class RegimeAnalyzer {
  /// Analyzes a list of [SleepSession]s and groups them into [SleepRegime]s.
  /// 
  /// The algorithm uses anchor-based comparison to identify stable periods.
  static List<SleepRegime> analyze(List<SleepSession> sessions,
      {RegimeSettings settings = const RegimeSettings()}) {
    if (sessions.isEmpty) return [];

    // 1. Group sessions by night and merge close ones
    final nights = SessionGrouper.groupByNight(
      sessions,
      mergeThresholdMinutes: settings.mergeThresholdMinutes,
    );

    // 2. Filter out very short nights (total sleep < 2 hours)
    final longNights = nights.where((n) {
      final totalSleepMinutes = n.allSessions
          .fold<int>(0, (prev, s) => prev + s.duration.inMinutes);
      return totalSleepMinutes >= 120;
    }).toList();

    if (longNights.isEmpty) return [];

    // 3. Sort ascending by date (oldest first)
    final sorted = List<NightGroup>.from(longNights)
      ..sort((a, b) => a.date.compareTo(b.date));

    // 4. Build raw bedtime entries
    final entries = <_BedtimeEntry>[];
    
    // Find absolute latest bedtime for recency filtering
    int? latestBedtime;
    if (sorted.isNotEmpty) {
      latestBedtime = BedtimeNormalization.minutesFromNoon(sorted.last.aggregatedSession.startTime);
    }

    for (final night in sorted) {
      final startTime = night.aggregatedSession.startTime;
      final normalized = BedtimeNormalization.minutesFromNoon(startTime);
      
      bool isOutdated = false;
      if (latestBedtime != null) {
        int diff = (normalized - latestBedtime).abs();
        if (diff > 720) diff = 1440 - diff;
        if (diff > settings.recencyTolerance) {
          isOutdated = true;
        }
      }

      final updatedNight = NightGroup(
        date: night.date,
        aggregatedSession: night.aggregatedSession,
        allSessions: night.allSessions,
        isOutdated: isOutdated,
      );

      entries.add(_BedtimeEntry(
        date: updatedNight.date,
        normalizedMinutes: normalized,
        nightGroup: updatedNight,
        isOutdated: isOutdated,
      ));
    }

    // 5. Run the anchor-based state machine
    final rawRegimes = _findRawRegimes(entries, settings);

    // 6. Merge short regimes
    final merged = _mergeShortRegimes(rawRegimes, settings);

    // 7. Post-process: compute stats, windows, detect floating, mark current
    return _postProcess(merged, settings);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // State Machine Logic
  // ──────────────────────────────────────────────────────────────────────────

  static List<_RawRegime> _findRawRegimes(
      List<_BedtimeEntry> entries, RegimeSettings settings) {
    if (entries.isEmpty) return [];

    final regimes = <_RawRegime>[];
    var current = _RawRegime();
    int anomalyStreak = 0;
    final anomalyBuffer = <_BedtimeEntry>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (current.normalEntries.isEmpty) {
        // If the very first entry of a regime is outdated, we mark it as an anomaly instead of a regime starter?
        // Actually, if it's the start, it becomes the anchor. But if it's outdated relative to LATEST, 
        // it shouldn't be the anchor of a CURRENT regime.
        // But the state machine builds regimes forward.
        current.addEntry(entry, isAnomaly: false);
        continue;
      }

      final anchor = current.getAnchorAvg(settings);

      int rawDiff = entry.normalizedMinutes - anchor;
      while (rawDiff > 720) rawDiff -= 1440;
      while (rawDiff < -720) rawDiff += 1440;
      final diff = rawDiff.abs();

      // Check tolerance against the anchor
      // If the entry is outdated relative to the absolute latest, it MUST be an anomaly 
      // if we are trying to maintain a consistent regime that leads up to the latest.
      if (diff <= settings.toleranceWindow && !entry.isOutdated) {
        final wouldExceedSpread = _wouldExceedSpread(current, entry.normalizedMinutes, settings);

        if (wouldExceedSpread) {
          // Spread exceeded — break current regime
          regimes.add(current);
          current = _RawRegime();

          if (anomalyBuffer.isNotEmpty) {
            int resetIndex = i - anomalyBuffer.length;
            anomalyBuffer.clear();
            anomalyStreak = 0;
            i = resetIndex - 1;
          } else {
            i = i - 1;
          }
        } else {
          // Within tolerance and spread
          for (final a in anomalyBuffer) {
            current.addEntry(a, isAnomaly: true);
          }
          anomalyBuffer.clear();
          anomalyStreak = 0;
          current.addEntry(entry, isAnomaly: false);
        }
      } else {
        // Outside tolerance OR Outdated
        anomalyBuffer.add(entry);
        anomalyStreak++;

        if (anomalyStreak > settings.maxAnomalies) {
          // Break: finalize current
          regimes.add(current);
          current = _RawRegime();

          int resetIndex = i - anomalyBuffer.length + 1;
          anomalyBuffer.clear();
          anomalyStreak = 0;
          i = resetIndex - 1;
        }
      }
    }

    // Flush remaining
    for (final a in anomalyBuffer) {
      current.addEntry(a, isAnomaly: true);
    }
    if (current.normalEntries.isNotEmpty) {
      regimes.add(current);
    }

    return regimes;
  }

  static bool _wouldExceedSpread(
      _RawRegime regime, int newMinutes, RegimeSettings settings) {
    if (regime.normalEntries.isEmpty) return false;

    final currentMin = regime.normalEntries.map((e) => e.normalizedMinutes).reduce((a, b) => a < b ? a : b);
    final currentMax = regime.normalEntries.map((e) => e.normalizedMinutes).reduce((a, b) => a > b ? a : b);

    final newMin = newMinutes < currentMin ? newMinutes : currentMin;
    final newMax = newMinutes > currentMax ? newMinutes : currentMax;

    return (newMax - newMin) > settings.maxSpread;
  }

  static List<_RawRegime> _mergeShortRegimes(
      List<_RawRegime> regimes, RegimeSettings settings) {
    if (regimes.length <= 1) return regimes;

    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = 0; i < regimes.length; i++) {
        if (regimes[i].normalEntries.length < settings.minRegimeLength) {
          int? mergeTarget;
          int bestDist = 1440;

          if (i > 0) {
            int dist = (regimes[i].getAnchorAvg(settings) - regimes[i - 1].getAnchorAvg(settings)).abs();
            if (dist > 720) dist = 1440 - dist;
            if (dist < bestDist) {
              bestDist = dist;
              mergeTarget = i - 1;
            }
          }
          if (i < regimes.length - 1) {
            int dist = (regimes[i].getAnchorAvg(settings) - regimes[i + 1].getAnchorAvg(settings)).abs();
            if (dist > 720) dist = 1440 - dist;
            if (dist < bestDist) {
              bestDist = dist;
              mergeTarget = i + 1;
            }
          }

          if (mergeTarget != null) {
            regimes[mergeTarget].absorb(regimes[i]);
            regimes.removeAt(i);
            changed = true;
            break;
          }
        }
      }
    }
    return regimes;
  }

  static List<SleepRegime> _postProcess(
      List<_RawRegime> rawRegimes, RegimeSettings settings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = <SleepRegime>[];

    for (int i = 0; i < rawRegimes.length; i++) {
      final raw = rawRegimes[i];
      // Fix: Use the actual session start times for the header date range to match the UI list
      final sessionDates = raw.nightGroups.map((n) => n.aggregatedSession.startTime).toList();
      sessionDates.sort((a, b) => a.compareTo(b));
      
      final startDate = sessionDates.first;
      final endDate = sessionDates.last;
      
      // Fix: Calculate day count based on unique calendar days in the sessions
      final uniqueDays = raw.nightGroups
          .map((n) => DateTime(n.aggregatedSession.startTime.year, n.aggregatedSession.startTime.month, n.aggregatedSession.startTime.day))
          .toSet()
          .length;
      final dayCount = uniqueDays;

      // Fix: Exclude outdated sessions from average bedtime calculation
      final normalEntriesForAvg = raw.normalEntries.where((e) => !e.isOutdated).toList();
      
      // Fallback to all normal entries if all are outdated (shouldn't happen in a current regime)
      final effectiveNormalEntries = normalEntriesForAvg.isNotEmpty ? normalEntriesForAvg : raw.normalEntries;
      
      final normalMins = effectiveNormalEntries.map((e) => e.normalizedMinutes).toList();
      if (normalMins.isEmpty) continue;

      final windowStartMin = normalMins.reduce((a, b) => a < b ? a : b);
      final windowEndMin = normalMins.reduce((a, b) => a > b ? a : b);
      final avgBedtimeMin = (normalMins.reduce((a, b) => a + b) / normalMins.length).round();

      final isFloating = _isFloatingSchedule(raw, settings);

      RegimeShift? shift;
      if (i > 0) {
        final prevAvg = results[i-1].averageBedtimeNormalized; 
        int delta = avgBedtimeMin - prevAvg;
        while (delta > 720) delta -= 1440;
        while (delta < -720) delta += 1440;
        shift = RegimeShift(isLater: delta > 0, shiftDuration: Duration(minutes: delta.abs()));
      }

      final isCurrent = endDate.isAfter(today.subtract(const Duration(days: 2)));

      results.add(SleepRegime(
        id: 'regime_${startDate.millisecondsSinceEpoch}',
        startDate: startDate,
        endDate: endDate,
        averageBedtimeNormalized: avgBedtimeMin,
        averageBedtimeFormatted: BedtimeNormalization.minutesFromNoonToString(avgBedtimeMin),
        windowStart: BedtimeNormalization.minutesFromNoonToString(windowStartMin),
        windowEnd: BedtimeNormalization.minutesFromNoonToString(windowEndMin),
        anomalyDates: raw.anomalyEntries.map((e) => e.date).toList(),
        shiftFromPrevious: shift,
        isCurrent: isCurrent,
        dayCount: dayCount,
        nights: raw.nightGroups.toSet().toList().reversed.toList(),
        isFloating: isFloating,
      ));
    }

    return results.reversed.toList();
  }

  static bool _isFloatingSchedule(_RawRegime raw, RegimeSettings settings) {
    if (raw.normalEntries.length < 4) return false;
    final sorted = List<_BedtimeEntry>.from(raw.normalEntries)..sort((a, b) => a.date.compareTo(b.date));
    int totalDelta = 0;
    for (int i = 1; i < sorted.length; i++) {
        int delta = (sorted[i].normalizedMinutes - sorted[i - 1].normalizedMinutes).abs();
        if (delta > 720) delta = 1440 - delta;
        totalDelta += delta;
    }
    final avgDelta = totalDelta / (sorted.length - 1);
    return avgDelta >= settings.floatingThreshold;
  }
}

class _BedtimeEntry {
  final DateTime date;
  final int normalizedMinutes;
  final NightGroup nightGroup;
  final bool isOutdated;
  _BedtimeEntry({
    required this.date,
    required this.normalizedMinutes,
    required this.nightGroup,
    this.isOutdated = false,
  });
}

class _RawRegime {
  final List<_BedtimeEntry> normalEntries = [];
  final List<_BedtimeEntry> anomalyEntries = [];
  final List<NightGroup> nightGroups = [];

  int getAnchorAvg(RegimeSettings settings) {
    if (normalEntries.isEmpty) return 0;
    
    // Prefer non-outdated entries for the anchor to adapt to recent regime shifts
    final activeEntries = normalEntries.where((e) => !e.isOutdated).toList();
    final source = activeEntries.isNotEmpty ? activeEntries : normalEntries;

    int count = source.length < settings.anchorSize ? source.length : settings.anchorSize;
    int sum = 0;
    for (int i = 0; i < count; i++) sum += source[i].normalizedMinutes;
    return (sum / count).round();
  }

  void addEntry(_BedtimeEntry entry, {required bool isAnomaly}) {
    nightGroups.add(entry.nightGroup);
    if (isAnomaly) {
      anomalyEntries.add(entry);
    } else {
      normalEntries.add(entry);
    }
  }

  void absorb(_RawRegime other) {
    normalEntries.addAll(other.normalEntries);
    anomalyEntries.addAll(other.anomalyEntries);
    nightGroups.addAll(other.nightGroups);
  }
}
