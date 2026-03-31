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

  /// Fetches sleep data from Google Fit for the specified number of [daysBack].
  /// Returns a record with the fetched sessions and a boolean indicating if it was a live sync.
  Future<({List<SleepSession> sessions, bool isLive})> fetchSleepData({
    int daysBack = 14,
    bool forceNetwork = false,
  }) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(days: daysBack));

    try {
      final googleFitSessions = await _googleFit.fetchSleepSessions(
        startTime: startTime,
        endTime: endTime,
      );

      if (googleFitSessions != null) {
        final sleepSessions = _mapToSleepSessions(googleFitSessions);
        await _cacheSleepData(sleepSessions);
        return (sessions: sleepSessions, isLive: true);
      } else if (forceNetwork) {
        // If forceNetwork is true, we should not fall back to cache quietly
        throw Exception('Failed to fetch data from Google Fit');
      }
    } catch (e) {
      debugPrint('Error fetching sleep data from Google Fit: $e');
      if (forceNetwork) rethrow;
    }

    // Attempt to load from cache on any failure (if not forced)
    final cachedSessions = await _loadCachedSleepData();
    return (sessions: cachedSessions, isLive: false);
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
        // Detailed segments could be fetched separately if needed,
        // using fitness/v1 response, but for base regime they are not vital.
        segments: [],
      );
    }).toList();
  }

  Future<void> _cacheSleepData(List<SleepSession> sessions) async {
    try {
      final jsonStr = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _storage.save(_cacheFilename, jsonStr);
    } catch (e) {
      debugPrint('Error caching sleep data: $e');
    }
  }

  Future<List<SleepSession>> _loadCachedSleepData() async {
    try {
      final jsonStr = await _storage.load(_cacheFilename);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .map(
                (item) => SleepSession.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached sleep data: $e');
    }
    return [];
  }
}
