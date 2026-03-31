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
  final DateTime? lastFetchTime;

  const SleepState({
    required this.sessions,
    this.regimes = const [],
    this.isLoading = false,
    this.error,
    this.lastFetchTime,
  });

  SleepState copyWith({
    List<SleepSession>? sessions,
    List<SleepRegime>? regimes,
    bool? isLoading,
    String? error,
    DateTime? lastFetchTime,
  }) {
    return SleepState(
      sessions: sessions ?? this.sessions,
      regimes: regimes ?? this.regimes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    regimes,
    isLoading,
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData();
      final sessions = result.sessions;

      if (sessions.isEmpty && state.sessions.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: "No sleep data found. Check connection or data availability.",
        );
        return;
      }

      if (result.isLive) {
        // Notify GoogleFitProvider about successful live sync
        ref
            .read(googleFitProvider.notifier)
            .updateLastFetchTime(DateTime.now());
      }

      final regimes = RegimeAnalyzer.analyze(sessions);

      state = state.copyWith(
        sessions: sessions,
        regimes: regimes,
        isLoading: false,
        lastFetchTime: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> syncWithGoogleFit() async {
    await loadSleepData();
  }
}

final sleepProvider = NotifierProvider<SleepNotifier, SleepState>(
  SleepNotifier.new,
);

final sleepServiceProvider = Provider((ref) => SleepService());
