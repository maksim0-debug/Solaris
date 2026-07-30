import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/gaming_mode_service.dart';

class ActiveProcessState {
  final String activeProcess; // e.g. "photoshop.exe" (always lower-case)
  final String windowTitle;
  final bool isGaming;
  final Set<int> suppressedPids;

  const ActiveProcessState({
    required this.activeProcess,
    required this.windowTitle,
    this.isGaming = false,
    this.suppressedPids = const {},
  });

  ActiveProcessState copyWith({
    String? activeProcess,
    String? windowTitle,
    bool? isGaming,
    Set<int>? suppressedPids,
  }) => ActiveProcessState(
    activeProcess: activeProcess ?? this.activeProcess,
    windowTitle: windowTitle ?? this.windowTitle,
    isGaming: isGaming ?? this.isGaming,
    suppressedPids: suppressedPids ?? this.suppressedPids,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveProcessState &&
          runtimeType == other.runtimeType &&
          activeProcess == other.activeProcess &&
          windowTitle == other.windowTitle &&
          isGaming == other.isGaming &&
          const SetEquality<int>().equals(suppressedPids, other.suppressedPids);

  @override
  int get hashCode =>
      activeProcess.hashCode ^
      windowTitle.hashCode ^
      isGaming.hashCode ^
      const SetEquality<int>().hash(suppressedPids);
}

class ActiveProcessService extends Notifier<ActiveProcessState> {
  static const _eventChannel = EventChannel('com.solaris.monitor/events');

  /// System shell process blacklist to prevent focus flickering
  static const Set<String> systemShellBlacklist = {
    'explorer.exe',
    'shellexperiencehost.exe',
    'searchhost.exe',
    'applicationframehost.exe',
    'sharex.exe',
    'startmenuexperiencehost.exe',
    'taskview.exe',
    'multitaskingviewframe.exe',
  };

  StreamSubscription<dynamic>? _subscription;
  Timer? _hysteresisTimer;
  Timer? _exitDelayTimer;

  String _rawProcess = '';
  String _rawTitle = '';
  String _effectiveUserProcess = '';

  @override
  ActiveProcessState build() {
    _init();

    ref.onDispose(() {
      _hysteresisTimer?.cancel();
      _exitDelayTimer?.cancel();
      _subscription?.cancel();
    });

    return const ActiveProcessState(
      activeProcess: '',
      windowTitle: '',
      isGaming: false,
    );
  }

  void _init() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        _handleNativeEvent(event);
      },
      onError: (Object error) {
        debugPrint('[ActiveProcessService] EventChannel Error: $error');
      },
    );
  }

  void _handleNativeEvent(dynamic event) {
    bool isGaming = false;
    String newProcess = '';
    String title = '';

    if (event is Map) {
      final gaming = event['is_gaming'];
      if (gaming is bool) isGaming = gaming;

      final proc = event['active_process'];
      if (proc is String) newProcess = proc.trim().toLowerCase();

      final winTitle = event['window_title'];
      if (winTitle is String) title = winTitle;
    } else if (event is bool) {
      isGaming = event;
    }

    // Proxy gaming state to GamingModeService
    ref.read(gamingModeProvider.notifier).setGamingState(isGaming);

    _rawProcess = newProcess;
    _rawTitle = title;

    // Trigger hysteresis loop (250 ms)
    _hysteresisTimer?.cancel();
    _hysteresisTimer = Timer(const Duration(milliseconds: 250), () {
      _processFocusChange(isGaming);
    });
  }

  void _processFocusChange(bool isGaming) {
    if (!ref.mounted) return;

    final incomingProcess = _rawProcess;

    // Filter system shell processes
    if (systemShellBlacklist.contains(incomingProcess)) {
      // Retain previous user application profile, but update isGaming / title
      if (state.isGaming != isGaming) {
        state = state.copyWith(isGaming: isGaming);
      }
      return;
    }

    final previousUserProcess = _effectiveUserProcess;

    // Check if incoming app has an app override rule
    final settingsAsync = ref.read(settingsProvider);
    final settingsMap = settingsAsync.value;
    final settings = settingsMap?['all'] ?? SettingsState();

    final List<AppOverrideRule> rules = settings.appOverrides;
    final hasOverrideForIncoming = rules.any(
      (r) => r.isEnabled && r.exeName == incomingProcess,
    );
    final hasOverrideForPrevious = rules.any(
      (r) => r.isEnabled && r.exeName == previousUserProcess,
    );

    if (incomingProcess == previousUserProcess) {
      _exitDelayTimer?.cancel();
      if (state.activeProcess != incomingProcess || state.isGaming != isGaming) {
        state = state.copyWith(
          activeProcess: incomingProcess,
          windowTitle: _rawTitle,
          isGaming: isGaming,
        );
      }
      return;
    }

    // Process switched to a different user application
    // Immediate Preemption or Exit Delay logic:
    if (hasOverrideForIncoming) {
      // 1. Direct switch to another profiled app: Immediate Preemption (0 ms)
      _exitDelayTimer?.cancel();
      _effectiveUserProcess = incomingProcess;
      _applyStateChange(incomingProcess, _rawTitle, isGaming, clearSuppression: true);
    } else if (hasOverrideForPrevious && incomingProcess.isNotEmpty) {
      // 2. Switch to a non-profiled neutral app: Hold previous profile for exit delay
      final delaySeconds = settings.appOverrideExitDelaySeconds;
      if (delaySeconds <= 0) {
        _effectiveUserProcess = incomingProcess;
        _applyStateChange(incomingProcess, _rawTitle, isGaming, clearSuppression: true);
      } else {
        // Retain previous override for delaySeconds
        _exitDelayTimer?.cancel();
        _exitDelayTimer = Timer(Duration(seconds: delaySeconds), () {
          if (!ref.mounted) return;
          _effectiveUserProcess = _rawProcess;
          _applyStateChange(_rawProcess, _rawTitle, isGaming, clearSuppression: false);
        });
      }
    } else {
      // 3. Normal process switch without active exit delay override
      _exitDelayTimer?.cancel();
      _effectiveUserProcess = incomingProcess;
      _applyStateChange(incomingProcess, _rawTitle, isGaming, clearSuppression: true);
    }
  }

  void _applyStateChange(
    String process,
    String title,
    bool isGaming, {
    required bool clearSuppression,
  }) {
    final newSuppressed = clearSuppression ? <int>{} : state.suppressedPids;
    state = state.copyWith(
      activeProcess: process,
      windowTitle: title,
      isGaming: isGaming,
      suppressedPids: newSuppressed,
    );
  }

  /// Temporarily suppress Per-App profile for the current process session
  void suppressActiveApp([int? pid]) {
    final targetPid = pid ?? 1; // Default session token if PID not provided
    final updated = Set<int>.from(state.suppressedPids)..add(targetPid);
    state = state.copyWith(suppressedPids: updated);
    debugPrint(
      '[ActiveProcessService] Suppressed active process: ${state.activeProcess} (token: $targetPid)',
    );
  }

  /// For testing or manual triggers
  void updateActiveProcessManually(String exeName, {bool isGaming = false, String title = ''}) {
    _rawProcess = exeName.trim().toLowerCase();
    _rawTitle = title;
    _processFocusChange(isGaming);
  }
}

final activeProcessServiceProvider =
    NotifierProvider<ActiveProcessService, ActiveProcessState>(
      ActiveProcessService.new,
    );
