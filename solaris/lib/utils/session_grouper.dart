import '../models/sleep_session.dart';
import '../models/night_group.dart';

class SessionGrouper {
  /// Groups a list of [SleepSession]s by "night".
  ///
  /// A night is defined from 12:00 PM (noon) to 11:59 AM the next day.
  /// The representative date is the day on which the night *begins*.
  static List<NightGroup> groupByNight(
    List<SleepSession> sessions, {
    int mergeThresholdMinutes = 210,
  }) {
    if (sessions.isEmpty) return [];

    // 1. Deduplicate sessions by time to prevent UI doubling (even if IDs differ)
    final Map<String, SleepSession> uniqueMap = {};
    for (final s in sessions) {
      final key =
          '${s.startTime.millisecondsSinceEpoch}_${s.endTime.millisecondsSinceEpoch}';
      uniqueMap[key] = s;
    }
    final uniqueSessions = uniqueMap.values.toList();

    // 2. Sort all sessions by start time
    final sortedSessions = List<SleepSession>.from(uniqueSessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 3. Cluster sessions by adjacency (gap < 3.5h)
    final clusters = <List<SleepSession>>[];
    if (sortedSessions.isNotEmpty) {
      var currentCluster = [sortedSessions.first];
      for (int i = 1; i < sortedSessions.length; i++) {
        final prev = sortedSessions[i - 1];
        final curr = sortedSessions[i];

        // Check the gap between previous end and current start
        if (curr.startTime.difference(prev.endTime).inMinutes <
            mergeThresholdMinutes) {
          currentCluster.add(curr);
        } else {
          clusters.add(currentCluster);
          currentCluster = [curr];
        }
      }
      clusters.add(currentCluster);
    }

    // 3. For each cluster, create a NightGroup
    final result = <NightGroup>[];
    for (final cluster in clusters) {
      // Representative date of the night cluster
      final nightDate = _getNightStart(cluster.first.startTime);

      final first = cluster.first;
      final sortedByEnd = List<SleepSession>.from(cluster)
        ..sort((a, b) => b.endTime.compareTo(a.endTime));
      final last = sortedByEnd.first;

      final aggregated = SleepSession(
        id: 'night_${nightDate.millisecondsSinceEpoch}_${first.startTime.millisecondsSinceEpoch}',
        startTime: first.startTime,
        endTime: last.endTime,
        title: 'Sleep on ${nightDate.year}-${nightDate.month}-${nightDate.day}',
      );

      result.add(
        NightGroup(
          date: nightDate,
          aggregatedSession: aggregated,
          allSessions: cluster,
        ),
      );
    }

    return result;
  }

  static DateTime _getNightStart(DateTime time) {
    if (time.hour >= 12) {
      // It's the same calendar day
      return DateTime(time.year, time.month, time.day);
    } else {
      // It belongs to the previous calendar day's night
      return DateTime(
        time.year,
        time.month,
        time.day,
      ).subtract(const Duration(days: 1));
    }
  }
}
