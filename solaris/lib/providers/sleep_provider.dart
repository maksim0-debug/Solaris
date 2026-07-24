import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/services/sleep_service.dart';
import 'package:solaris/services/regime_analyzer.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:equatable/equatable.dart';

class SleepState extends Equatable {
  final List<SleepSession> sessions;
  final bool isLoading;
  final String? error;
  final bool isSyncing;
  final DateTime? lastFetchTime;

  const SleepState({
    required this.sessions,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastFetchTime,
  });

  SleepState copyWith({
    List<SleepSession>? sessions,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastFetchTime,
  }) {
    return SleepState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    isLoading,
    isSyncing,
    error,
    lastFetchTime,
  ];
}

class SleepNotifier extends Notifier<SleepState> {
  final SleepService _sleepService = SleepService();

  @override
  SleepState build() {
    // Attempt initial load from cache
    Future.microtask(() => loadSleepData());
    return const SleepState(sessions: [], isLoading: true);
  }

  Future<void> loadSleepData() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(forceNetwork: false);
      if (!ref.mounted) return;
      final sessions = result.sessions;

      if (sessions.isNotEmpty) {
        state = state.copyWith(
          sessions: sessions,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Error loading initial sleep data: $e');
    }

    if (!ref.mounted) return;
    final gState = ref.read(googleFitProvider);
    if (gState.status == GoogleFitStatus.connected) {
      syncWithGoogleFit(forceSync: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Checks if two sleep sessions overlap in time (with 1-hour buffer).
  bool _areSessionsOverlapping(SleepSession a, SleepSession b) {
    final aStart = a.startTime.subtract(const Duration(hours: 1));
    final aEnd = a.endTime.add(const Duration(hours: 1));
    final bStart = b.startTime;
    final bEnd = b.endTime;

    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  /// Merges existing and incoming sleep sessions, deduplicating overlapping ones.
  /// Gives absolute priority to 'local_api' source over 'google_fit'.
  List<SleepSession> _mergeAndDeduplicate(
    List<SleepSession> existing,
    List<SleepSession> incoming,
  ) {
    final merged = <String, SleepSession>{};

    for (final s in existing) {
      merged[s.id] = s;
    }

    for (final s in incoming) {
      final existingSession = merged[s.id];
      // Overwrite if it is a new ID or if new session is local_api (override google_fit)
      if (existingSession == null || s.source == 'local_api' || existingSession.source != 'local_api') {
        merged[s.id] = s;
      }
    }

    final list = merged.values.toList();
    final localSessions = list.where((s) => s.source == 'local_api').toList();
    final deduplicated = <SleepSession>[];

    for (final s in list) {
      if (s.source == 'local_api') {
        deduplicated.add(s);
      } else {
        // Discard google_fit session if it overlaps with any local_api session
        bool overlaps = false;
        for (final local in localSessions) {
          if (_areSessionsOverlapping(s, local)) {
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

  /// Updates sleep sessions with data received from the Local IPC server.
  Future<void> updateSessionsFromIpc(List<SleepSession> newSessions) async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final merged = _mergeAndDeduplicate(state.sessions, newSessions);
      await _sleepService.cacheSleepData(merged);
      if (!ref.mounted) return;

      state = state.copyWith(
        sessions: merged,
        isSyncing: false,
        lastFetchTime: DateTime.now(),
        error: null,
      );
    } catch (e) {
      debugPrint('Error updating sleep sessions from IPC: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        error: 'Failed to save IPC sleep data: ${e.toString()}',
      );
    }
  }

  Future<void> syncWithGoogleFit({bool forceSync = true}) async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(
        forceNetwork: forceSync,
      );
      if (!ref.mounted) return;
      final sessions = result.sessions;

      if (sessions.isEmpty && state.sessions.isEmpty) {
        state = state.copyWith(
          isSyncing: false,
          error: "No sleep data found.",
        );
        return;
      }

      if (result.isLive) {
        final now = DateTime.now();
        ref.read(googleFitProvider.notifier).updateLastFetchTime(now);

        final merged = _mergeAndDeduplicate(state.sessions, sessions);
        await _sleepService.cacheSleepData(merged);
        if (!ref.mounted) return;

        state = state.copyWith(
          sessions: merged,
          isSyncing: false,
          lastFetchTime: now,
          error: null,
        );
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        error: forceSync ? "Sync failed: ${e.toString()}" : null,
      );
    }
  }
}

final sleepProvider = NotifierProvider<SleepNotifier, SleepState>(
  SleepNotifier.new,
);

final sleepServiceProvider = Provider((ref) => SleepService());

/// Synchronous provider for analyzed sleep regimes.
/// This prevents "Phantom Target" dips by ensuring regimes are recalculated 
/// instantly in memory when settings change, without clearing the raw data.
final sleepRegimesProvider = Provider<List<SleepRegime>>((ref) {
  final sleepState = ref.watch(sleepProvider);
  final settingsAsync = ref.watch(settingsProvider);
  final selectedMonitors = ref.watch(selectedMonitorsProvider);
  final monitorId = selectedMonitors.firstOrNull ?? 'all';

  return settingsAsync.maybeWhen(
    data: (settingsMap) {
      final settings = settingsMap[monitorId] ?? settingsMap['all'];
      if (settings != null && sleepState.sessions.isNotEmpty) {
        return RegimeAnalyzer.analyze(
          sleepState.sessions,
          settings: RegimeSettings(
            toleranceWindow: settings.sleepToleranceWindow,
            maxAnomalies: settings.sleepMaxAnomalies,
            minRegimeLength: settings.sleepMinRegimeLength,
            anchorSize: settings.sleepAnchorSize,
            maxSpread: settings.sleepMaxSpread,
          ),
        );
      }
      return [];
    },
    orElse: () => [],
  );
});
