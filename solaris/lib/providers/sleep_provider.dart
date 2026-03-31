import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/services/sleep_service.dart';
import 'package:solaris/services/regime_analyzer.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:solaris/models/settings_state.dart';
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
    // Watch settings to re-trigger analysis when they change
    final settingsAsync = ref.watch(settingsProvider);
    final selectedMonitors = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedMonitors.firstOrNull ?? 'all';

    settingsAsync.whenData((settingsMap) {
      final settings = settingsMap[monitorId] ?? settingsMap['all'];
      if (settings != null && state.sessions.isNotEmpty) {
        final newRegimes = RegimeAnalyzer.analyze(
          state.sessions,
          settings: RegimeSettings(
            toleranceWindow: settings.sleepToleranceWindow,
            maxAnomalies: settings.sleepMaxAnomalies,
            minRegimeLength: settings.sleepMinRegimeLength,
            anchorSize: settings.sleepAnchorSize,
            maxSpread: settings.sleepMaxSpread,
          ),
        );
        // Only update if regimes actually changed to avoid cycles (though analysis is deterministic)
        if (newRegimes != state.regimes) {
          state = state.copyWith(regimes: newRegimes);
        }
      }
    });

    // Attempt initial load from cache
    Future.microtask(() => loadSleepData());
    return const SleepState(sessions: []);
  }

  Future<void> loadSleepData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sleepService.fetchSleepData(forceNetwork: false);
      final sessions = result.sessions;

      if (sessions.isNotEmpty) {
        final settings = _getCurrentRegimeSettings();
        final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
        state = state.copyWith(
          sessions: sessions,
          regimes: regimes,
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

        final settings = _getCurrentRegimeSettings();
        final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
        state = state.copyWith(
          sessions: sessions,
          regimes: regimes,
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

  RegimeSettings _getCurrentRegimeSettings() {
    final settingsAsync = ref.read(settingsProvider);
    final selectedMonitors = ref.read(selectedMonitorsProvider);
    final monitorId = selectedMonitors.firstOrNull ?? 'all';

    return settingsAsync.maybeWhen(
      data: (map) {
        final s = map[monitorId] ?? map['all'] ?? SettingsState();
        return RegimeSettings(
          toleranceWindow: s.sleepToleranceWindow,
          maxAnomalies: s.sleepMaxAnomalies,
          minRegimeLength: s.sleepMinRegimeLength,
          anchorSize: s.sleepAnchorSize,
          maxSpread: s.sleepMaxSpread,
        );
      },
      orElse: () => const RegimeSettings(),
    );
  }
}

final sleepProvider = NotifierProvider<SleepNotifier, SleepState>(
  SleepNotifier.new,
);

final sleepServiceProvider = Provider((ref) => SleepService());
