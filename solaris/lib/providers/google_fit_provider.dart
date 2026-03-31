import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/services/google_fit_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:googleapis/fitness/v1.dart';

enum GoogleFitStatus { initial, connecting, connected, disconnected, error }

class GoogleFitState extends Equatable {
  final GoogleFitStatus status;
  final String? errorMessage;
  final DateTime? lastFetchTime;
  final bool? lastFetchSuccess;
  final List<Session>? sessions;
  final bool isExpanded;

  const GoogleFitState({
    required this.status,
    this.errorMessage,
    this.lastFetchTime,
    this.lastFetchSuccess,
    this.sessions,
    this.isExpanded = false,
  });

  GoogleFitState copyWith({
    GoogleFitStatus? status,
    String? errorMessage,
    DateTime? lastFetchTime,
    bool? lastFetchSuccess,
    List<Session>? sessions,
    bool? isExpanded,
  }) {
    return GoogleFitState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      lastFetchSuccess: lastFetchSuccess ?? this.lastFetchSuccess,
      sessions: sessions ?? this.sessions,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    lastFetchTime,
    lastFetchSuccess,
    sessions,
    isExpanded,
  ];
}

class GoogleFitNotifier extends Notifier<GoogleFitState> {
  final _storage = StorageService();
  static const _lastSyncFilename = 'google_fit_last_sync.txt';

  @override
  GoogleFitState build() {
    // We can't do async work in build directly, but we can trigger it
    Future.microtask(() => _initialize());
    return const GoogleFitState(status: GoogleFitStatus.initial);
  }

  Future<void> _initialize() async {
    state = state.copyWith(status: GoogleFitStatus.connecting);
    final service = ref.read(googleFitServiceProvider);

    // Load last sync time from storage
    DateTime? lastSync;
    final lastSyncStr = await _storage.load(_lastSyncFilename);
    if (lastSyncStr != null) {
      lastSync = DateTime.tryParse(lastSyncStr);
    }

    try {
      final connected = await service.initialize();
      if (connected) {
        state = state.copyWith(
          status: GoogleFitStatus.connected,
          lastFetchTime: lastSync,
        );
      } else {
        // If not connected, but there was a token, it might be an error or expired without refresh token
        state = state.copyWith(
          status: GoogleFitStatus.disconnected,
          lastFetchTime: lastSync,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: GoogleFitStatus.error,
        errorMessage: e.toString(),
        lastFetchTime: lastSync,
      );
    }
  }

  Future<void> signIn() async {
    state = state.copyWith(status: GoogleFitStatus.connecting);
    final service = ref.read(googleFitServiceProvider);
    final success = await service.signIn();
    if (success) {
      state = state.copyWith(
        status: GoogleFitStatus.connected,
        errorMessage: null,
      );
      // Trigger a sync after successful sign-in
      ref.read(sleepProvider.notifier).syncWithGoogleFit(forceSync: true);
    } else {
      state = state.copyWith(
        status: GoogleFitStatus.error,
        errorMessage: 'Failed to connect to Google Fit',
      );
    }
  }

  Future<void> signOut() async {
    final service = ref.read(googleFitServiceProvider);
    await service.signOut();
    state = state.copyWith(
      status: GoogleFitStatus.disconnected,
      sessions: null,
      isExpanded: false,
    );
  }

  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  Future<void> updateLastFetchTime(DateTime time) async {
    await _storage.save(_lastSyncFilename, time.toIso8601String());
    state = state.copyWith(lastFetchTime: time);
  }

  Future<void> testSync() async {
    final service = ref.read(googleFitServiceProvider);
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final sessions = await service.fetchSleepSessions(
      startTime: sevenDaysAgo,
      endTime: now,
    );

    if (sessions != null) {
      await updateLastFetchTime(now);
    }

    state = state.copyWith(
      lastFetchSuccess: sessions != null,
      sessions: sessions,
    );
  }
}

final googleFitServiceProvider = Provider((ref) => GoogleFitService());

final googleFitProvider = NotifierProvider<GoogleFitNotifier, GoogleFitState>(
  GoogleFitNotifier.new,
);
