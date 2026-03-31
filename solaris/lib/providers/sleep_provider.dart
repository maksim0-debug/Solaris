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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(forceNetwork: false);
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

    final gState = ref.read(googleFitProvider);
    if (gState.status == GoogleFitStatus.connected) {
      syncWithGoogleFit(forceSync: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> syncWithGoogleFit({bool forceSync = true}) async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(
        forceNetwork: forceSync,
      );
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

        state = state.copyWith(
          sessions: sessions,
          isSyncing: false,
          lastFetchTime: now,
          error: null,
        );
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (e) {
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
