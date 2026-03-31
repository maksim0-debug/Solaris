import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/services/sleep_service.dart';
import 'package:solaris/services/regime_analyzer.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:equatable/equatable.dart';

class SleepState extends Equatable {
  final List<SleepSession> sessions;
  final List<SleepRegime> regimes;
  final bool isLoading;
  final String? error;
  final bool isSyncing;
  final DateTime? lastFetchTime;

  const SleepState({
    required this.sessions,
    this.regimes = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastFetchTime,
  });

  SleepState copyWith({
    List<SleepSession>? sessions,
    List<SleepRegime>? regimes,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastFetchTime,
  }) {
    return SleepState(
      sessions: sessions ?? this.sessions,
      regimes: regimes ?? this.regimes,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    regimes,
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
    return const SleepState(sessions: []);
  }

  Future<void> loadSleepData() async {
    // 1. First, load from cache immediately to show something in the UI
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(forceNetwork: false);
      final sessions = result.sessions;

      if (sessions.isNotEmpty) {
        final regimes = RegimeAnalyzer.analyze(sessions);
        state = state.copyWith(
          sessions: sessions,
          regimes: regimes,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Error loading initial sleep data: $e');
    }

    // 2. Then, trigger a background sync if we are connected
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
        // Notify GoogleFitProvider about successful live sync
        ref.read(googleFitProvider.notifier).updateLastFetchTime(now);
        
        final regimes = RegimeAnalyzer.analyze(sessions);
        state = state.copyWith(
          sessions: sessions,
          regimes: regimes,
          isSyncing: false,
          lastFetchTime: now,
          error: null,
        );
      } else {
        // If not live, but we weren't forcing it, just stop syncing
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
