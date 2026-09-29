import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/monitor_service.dart';

class ExpandedGammaNotifier extends AsyncNotifier<ExpandedGammaStatus> {
  @override
  Future<ExpandedGammaStatus> build() async {
    // Dynamically refresh status when app returns to visible state
    ref.listen<AppVisibilityState>(appLifecycleProvider, (previous, next) {
      if (next == AppVisibilityState.visible) {
        refresh();
      }
    });

    final monitorService = ref.read(monitorServiceProvider);
    try {
      return await monitorService.getExpandedGammaStatus();
    } catch (e, st) {
      debugPrint(
        '⚠️ [ExpandedGammaNotifier] Failed to query status in build: $e\n$st',
      );
      return ExpandedGammaStatus.disabled;
    }
  }

  Future<void> refresh() async {
    // Quiet background update preserving existing state to prevent UI flicker
    final monitorService = ref.read(monitorServiceProvider);
    try {
      final status = await monitorService.getExpandedGammaStatus();
      if (!state.hasValue || state.value != status) {
        state = AsyncData(status);
      }
    } catch (e, st) {
      debugPrint(
        '⚠️ [ExpandedGammaNotifier] Failed to refresh status: $e\n$st',
      );
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  bool _isUnlocking = false;

  Future<bool> unlock() async {
    if (_isUnlocking) return false;
    _isUnlocking = true;
    try {
      final monitorService = ref.read(monitorServiceProvider);
      final success = await monitorService.unlockExpandedGamma();
      if (success) {
        await refresh();
      }
      return success;
    } catch (e, st) {
      debugPrint('❌ [ExpandedGammaNotifier] Exception in unlock: $e\n$st');
      return false;
    } finally {
      _isUnlocking = false;
    }
  }

  Future<bool> restartComputer() async {
    try {
      final monitorService = ref.read(monitorServiceProvider);
      return await monitorService.restartComputer();
    } catch (e, st) {
      debugPrint(
        '❌ [ExpandedGammaNotifier] Exception in restartComputer: $e\n$st',
      );
      return false;
    }
  }
}

final expandedGammaProvider =
    AsyncNotifierProvider<ExpandedGammaNotifier, ExpandedGammaStatus>(
      ExpandedGammaNotifier.new,
    );
