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
    final List<SleepSession> uniqueSessions = uniqueMap.values.toList();

    // 2. Remove nested sessions (sessions entirely contained within another)
    // To ensure we don't have redundant data.
    final List<SleepSession> deduplicated = [];
    uniqueSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    for (int i = 0; i < uniqueSessions.length; i++) {
       bool isNested = false;
       for (int j = 0; j < uniqueSessions.length; j++) {
         if (i == j) continue;
         final s1 = uniqueSessions[i];
         final s2 = uniqueSessions[j];
         // Case: s1 is inside s2
         if (s1.startTime.isAtSameMomentAs(s2.startTime) || s1.startTime.isAfter(s2.startTime)) {
            if (s1.endTime.isAtSameMomentAs(s2.endTime) || s1.endTime.isBefore(s2.endTime)) {
              if (s1.id != s2.id || i > j) { // Prefer larger or earlier-index
                isNested = true;
                break;
              }
            }
         }
       }
       if (!isNested) deduplicated.add(uniqueSessions[i]);
    }

    // 3. Sort all sessions by start time
    final sortedSessions = List<SleepSession>.from(deduplicated)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 4. Cluster sessions by adjacency (gap < 3.5h) using maxEndTime of cluster
    final clusters = <List<SleepSession>>[];
    if (sortedSessions.isNotEmpty) {
      var currentCluster = [sortedSessions.first];
      var maxEndTime = sortedSessions.first.endTime;

      for (int i = 1; i < sortedSessions.length; i++) {
        final curr = sortedSessions[i];

        // Check the gap between the cluster's latest end and current start
        if (curr.startTime.difference(maxEndTime).inMinutes <
            mergeThresholdMinutes) {
          currentCluster.add(curr);
          if (curr.endTime.isAfter(maxEndTime)) {
            maxEndTime = curr.endTime;
          }
        } else {
          clusters.add(currentCluster);
          currentCluster = [curr];
          maxEndTime = curr.endTime;
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
