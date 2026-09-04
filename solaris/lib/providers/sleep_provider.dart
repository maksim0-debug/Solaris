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

const _pushedIsSleepingSentinel = Object();

class SleepState extends Equatable {
  final List<SleepSession> sessions;
  final bool isLoading;
  final String? error;
  final bool isSyncing;
  final DateTime? lastFetchTime;
  final bool? pushedIsSleeping;

  const SleepState({
    required this.sessions,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastFetchTime,
    this.pushedIsSleeping,
  });

  bool get isCurrentlySleeping {
    if (pushedIsSleeping != null) return pushedIsSleeping!;
    if (sessions.isEmpty) return false;
    final latest = sessions.first;
    final now = DateTime.now();
    return (now.isAfter(latest.startTime) ||
            now.isAtSameMomentAs(latest.startTime)) &&
        now.isBefore(latest.endTime);
  }

  DateTime? get lastSessionEnd {
    if (sessions.isEmpty) return null;
    return sessions.first.endTime;
  }

  SleepState copyWith({
    List<SleepSession>? sessions,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastFetchTime,
    Object? pushedIsSleeping = _pushedIsSleepingSentinel,
  }) {
    return SleepState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      pushedIsSleeping: pushedIsSleeping == _pushedIsSleepingSentinel
          ? this.pushedIsSleeping
          : (pushedIsSleeping as bool?),
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    isLoading,
    isSyncing,
    error,
    lastFetchTime,
    pushedIsSleeping,
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
        state = state.copyWith(sessions: sessions, isLoading: false);
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

  /// Merges existing and incoming sleep sessions, deduplicating overlapping ones.
  /// Gives absolute priority to 'local_api' and 'manual' sources over 'google_fit'.
  List<SleepSession> _mergeAndDeduplicate(
    List<SleepSession> existing,
    List<SleepSession> incoming,
  ) {
    return SleepService.mergeAndDeduplicate(existing, incoming);
  }

  /// Updates the real-time pushed sleep status from external IPC/API clients.
  void updatePushedSleepStatus(bool isSleeping) {
    state = state.copyWith(pushedIsSleeping: isSleeping);
  }

  /// Updates sleep sessions with data received from the Local IPC server.
  Future<void> updateSessionsFromIpc(List<SleepSession> newSessions) async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final ignored = await _sleepService.loadIgnoredSessionIds();
      final filteredNew = newSessions
          .where((s) => !ignored.contains(s.id))
          .toList();
      final filteredExisting = state.sessions
          .where((s) => !ignored.contains(s.id))
          .toList();
      final merged = _mergeAndDeduplicate(filteredExisting, filteredNew);
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

  /// Adds a manually created sleep session.
  Future<void> addManualSession(SleepSession session) async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final ignored = await _sleepService.loadIgnoredSessionIds();
      final filteredExisting = state.sessions
          .where((s) => !ignored.contains(s.id))
          .toList();
      final merged = _mergeAndDeduplicate(filteredExisting, [session]);
      await _sleepService.cacheSleepData(merged);
      if (!ref.mounted) return;

      state = state.copyWith(
        sessions: merged,
        isSyncing: false,
        lastFetchTime: DateTime.now(),
        error: null,
      );
    } catch (e) {
      debugPrint('Error adding manual sleep session: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        error: 'Failed to add sleep session: ${e.toString()}',
      );
    }
  }

  /// Deletes a single sleep session by ID.
  Future<void> deleteSession(String sessionId, {bool doNotSync = true}) async {
    await deleteSessions([sessionId], doNotSync: doNotSync);
  }

  /// Deletes multiple sleep sessions by ID list.
  Future<void> deleteSessions(
    List<String> sessionIds, {
    bool doNotSync = true,
  }) async {
    if (sessionIds.isEmpty) return;
    if (doNotSync) {
      await _sleepService.addIgnoredSessionIds(sessionIds);
    }
    final idsSet = sessionIds.toSet();
    final updated = state.sessions
        .where((s) => !idsSet.contains(s.id))
        .toList();
    await _sleepService.cacheSleepData(updated);
    if (!ref.mounted) return;
    state = state.copyWith(sessions: updated);
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
        state = state.copyWith(isSyncing: false, error: 'No sleep data found.');
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
        error: forceSync ? 'Sync failed: ${e.toString()}' : null,
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
