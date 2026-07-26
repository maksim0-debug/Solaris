import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/services/google_fit_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:googleapis/fitness/v1.dart';

class SleepService {
  static final SleepService _instance = SleepService._internal();
  factory SleepService() => _instance;
  SleepService._internal();

  final _storage = StorageService();
  final _googleFit = GoogleFitService();
  final _cacheFilename = 'sleep_data_cache.json';
  final _ignoredFilename = 'ignored_sleep_sessions.json';

  /// Returns the set of session IDs that the user has marked as ignored/blacklisted.
  Future<Set<String>> loadIgnoredSessionIds() async {
    try {
      final jsonStr = await _storage.load(_ignoredFilename);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .where((e) => e != null)
              .map((e) => e.toString())
              .toSet();
        }
      }
    } catch (e) {
      debugPrint('Error loading ignored sleep session IDs: $e');
    }
    return {};
  }

  /// Adds [ids] to the set of ignored session IDs.
  Future<void> addIgnoredSessionIds(List<String> ids) async {
    try {
      final current = await loadIgnoredSessionIds();
      current.addAll(ids);
      await _storage.save(_ignoredFilename, jsonEncode(current.toList()));
    } catch (e) {
      debugPrint('Error saving ignored sleep session IDs: $e');
    }
  }

  /// Checks if a session source has high priority (e.g. user-created or API-pushed).
  static bool isHighPrioritySource(String source) =>
      source == 'local_api' || source == 'manual';

  /// Checks if two sleep sessions overlap in time (with 1-hour buffer).
  static bool _areSessionsOverlapping(SleepSession a, SleepSession b) {
    final aStart = a.startTime.subtract(const Duration(hours: 1));
    final aEnd = a.endTime.add(const Duration(hours: 1));
    final bStart = b.startTime;
    final bEnd = b.endTime;

    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  /// Merges existing and incoming sleep sessions, deduplicating overlapping ones.
  /// Gives absolute priority to 'local_api' and 'manual' sources over 'google_fit'.
  static List<SleepSession> mergeAndDeduplicate(
    List<SleepSession> existing,
    List<SleepSession> incoming,
  ) {
    final merged = <String, SleepSession>{};

    for (final s in existing) {
      merged[s.id] = s;
    }

    for (final s in incoming) {
      final existingSession = merged[s.id];
      if (existingSession == null ||
          isHighPrioritySource(s.source) ||
          !isHighPrioritySource(existingSession.source)) {
        merged[s.id] = s;
      }
    }

    final list = merged.values.toList();
    final highPrioritySessions =
        list.where((s) => isHighPrioritySource(s.source)).toList();
    final deduplicated = <SleepSession>[];

    for (final s in list) {
      if (isHighPrioritySource(s.source)) {
        deduplicated.add(s);
      } else {
        bool overlaps = false;
        for (final hp in highPrioritySessions) {
          if (_areSessionsOverlapping(s, hp)) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) {
          deduplicated.add(s);
        }
      }
    }

    deduplicated.sort((a, b) => b.startTime.compareTo(a.startTime));
    return deduplicated;
  }

  /// Fetches sleep data from Google Fit for the specified number of [daysBack].
  /// Returns a record with the fetched sessions and a boolean indicating if it was a live sync.
  Future<({List<SleepSession> sessions, bool isLive})> fetchSleepData({
    int daysBack = 14,
    bool forceNetwork = false,
  }) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(days: daysBack));
    final ignored = await loadIgnoredSessionIds();

    try {
      final googleFitSessions = await _googleFit.fetchSleepSessions(
        startTime: startTime,
        endTime: endTime,
      );

      if (googleFitSessions != null) {
        final sleepSessions = _mapToSleepSessions(googleFitSessions)
            .where((s) => !ignored.contains(s.id))
            .toList();
        final existingCached = await loadCachedSleepData();
        final merged = mergeAndDeduplicate(existingCached, sleepSessions);
        await cacheSleepData(merged);
        return (sessions: merged, isLive: true);
      } else if (forceNetwork) {
        // If forceNetwork is true, we should not fall back to cache quietly
        throw Exception('Failed to fetch data from Google Fit');
      }
    } catch (e) {
      debugPrint('Error fetching sleep data from Google Fit: $e');
      if (forceNetwork) rethrow;
    }

    // Attempt to load from cache on any failure (if not forced)
    final cachedSessions = await loadCachedSleepData();
    final filteredCached = cachedSessions
        .where((s) => !ignored.contains(s.id))
        .toList();
    return (sessions: filteredCached, isLive: false);
  }

  List<SleepSession> _mapToSleepSessions(List<Session> sessions) {
    return sessions.map((s) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(s.startTimeMillis ?? '0') ?? 0,
      );
      final endTime = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(s.endTimeMillis ?? '0') ?? 0,
      );

      return SleepSession(
        id: s.id ?? '',
        startTime: startTime,
        endTime: endTime,
        title: s.name,
        description: s.description,
        segments: [],
      );
    }).toList();
  }

  Future<void> cacheSleepData(List<SleepSession> sessions) async {
    try {
      final jsonStr = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _storage.save(_cacheFilename, jsonStr);
    } catch (e) {
      debugPrint('Error caching sleep data: $e');
    }
  }

  Future<List<SleepSession>> loadCachedSleepData() async {
    try {
      final jsonStr = await _storage.load(_cacheFilename);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final ignored = await loadIgnoredSessionIds();
          return decoded
              .map(
                (item) => SleepSession.fromJson(item as Map<String, dynamic>),
              )
              .where((s) => !ignored.contains(s.id))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached sleep data: $e');
    }
    return [];
  }

}

