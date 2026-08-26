import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';

/// Listener for Windows OS Power events (WM_POWERBROADCAST, WM_DISPLAYCHANGE)
/// and C++ hardware I2C/DDC error events received over the system_events EventChannel.
class WindowsPowerListener {
  static const int PBT_APMSUSPEND = 0x0004;
  static const int PBT_APMRESUMESUSPEND = 0x0007;
  static const int PBT_APMRESUMEAUTOMATIC = 0x0012;

  static const EventChannel _systemEventsChannel = EventChannel(
    'com.solaris.monitor/system_events',
  );

  final Ref ref;
  StreamSubscription<dynamic>? _subscription;
  bool _isSuspended = false;
  bool _isDisposed = false;

  WindowsPowerListener(this.ref) {
    _initListener();
    ref.onDispose(() {
      dispose();
    });
  }

  bool get isSuspended => _isSuspended;

  void _initListener() {
    // Only subscribe on Windows desktop platform (or when mock channel is present in tests)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        _subscription = _systemEventsChannel.receiveBroadcastStream().listen(
          _onSystemEvent,
          onError: (Object err) {
            debugPrint('WindowsPowerListener channel error: $err');
          },
        );
        debugPrint(
          'WindowsPowerListener: Subscribed to com.solaris.monitor/system_events',
        );
      } catch (e) {
        debugPrint('WindowsPowerListener failed to subscribe to channel: $e');
      }
    }
  }

  void _onSystemEvent(dynamic rawEvent) async {
    if (_isDisposed || rawEvent is! Map) return;
    final eventMap = Map<String, dynamic>.from(rawEvent);
    final eventName = eventMap['event'] as String?;

    if (eventName == 'WM_POWERBROADCAST') {
      final wparam = eventMap['wparam'] as int?;
      if (wparam == PBT_APMSUSPEND) {
        await handleSystemSuspend();
      } else if (wparam == PBT_APMSUSPEND ||
          wparam == PBT_APMRESUMESUSPEND ||
          wparam == PBT_APMRESUMEAUTOMATIC) {
        await handleSystemResume();
      }
    } else if (eventName == 'WM_DISPLAYCHANGE') {
      await handleDisplayChange();
    } else if (eventName == 'on_hardware_error') {
      final detail =
          eventMap['detail'] as String? ?? 'Unknown DDC/CI Hardware Error';
      handleHardwareError(detail);
    }
  }

  /// System Suspend (Sleep S3/S4) Handler
  Future<void> handleSystemSuspend() async {
    if (_isDisposed || _isSuspended) return;
    _isSuspended = true;
    debugPrint(
      'WindowsPowerListener: PC entering Sleep S3/S4. Pausing subsystems...',
    );

    try {
      ref.read(webhookServiceProvider.notifier).pauseQueue();
      await ref.read(webhookServiceProvider.notifier).flushWAL();
      ref
          .read(webSocketServiceProvider)
          .closeAll(code: 1001, reason: 'PC Entering Sleep Mode');
    } catch (e) {
      debugPrint('WindowsPowerListener: Error during suspend handling: $e');
    }
  }

  /// System Resume Handler
  Future<void> handleSystemResume() async {
    if (_isDisposed || !_isSuspended) return;
    debugPrint(
      'WindowsPowerListener: PC Resumed from Sleep S3/S4. Starting recovery sequence...',
    );

    try {
      ref.read(webhookServiceProvider.notifier).resumeQueue();
      await ref.read(localIpcServiceProvider.notifier).restartServer();

      if (_isDisposed) return;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      ref.read(webhookServiceProvider.notifier).dispatch(
        WebhookEventType.onSystemResume,
        {'timestamp': nowIso, 'event': 'on_system_resume'},
      );
      ref.read(webSocketServiceProvider).broadcastEvent('on_system_resume', {
        'timestamp': nowIso,
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_isDisposed) return;

      _isSuspended = false;
      debugPrint(
        'WindowsPowerListener: DDC/CI I2C Bus Ready after power resume.',
      );
    } catch (e) {
      _isSuspended = false;
      debugPrint('WindowsPowerListener: Error during resume handling: $e');
    }
  }

  /// Display Change (WM_DISPLAYCHANGE) Handler
  Future<void> handleDisplayChange() async {
    if (_isDisposed) return;
    debugPrint(
      'WindowsPowerListener: WM_DISPLAYCHANGE received. Re-enumerating connected monitors...',
    );
    try {
      ref.invalidate(monitorListProvider);
      final monitors = await ref
          .read(monitorServiceProvider)
          .getConnectedMonitors();
      if (_isDisposed) return;
      MonitorSlugResolver.updateMonitors(monitors);
      final monitorsJson = monitors
          .map(
            (m) => {
              'id': m.id,
              'name': m.name,
              'friendly_name': m.friendlyName,
              'slug': MonitorSlugResolver.getSlugForSystemId(m.id),
              'device_id_hash': m.deviceIdHash,
              'is_primary': m.isPrimary,
            },
          )
          .toList();
      ref
          .read(webSocketServiceProvider)
          .broadcastModule('monitors', monitorsJson);
    } catch (e) {
      debugPrint('WindowsPowerListener: Error handling display change: $e');
    }
  }

  /// Hardware Error Handler
  void handleHardwareError(String detail) {
    if (_isDisposed) return;
    debugPrint('WindowsPowerListener: DDC/CI Hardware Error: $detail');
    try {
      ref.read(webhookServiceProvider.notifier).dispatch(
        WebhookEventType.onHardwareError,
        {
          'detail': detail,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      ref.read(webSocketServiceProvider).broadcastEvent('on_hardware_error', {
        'detail': detail,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('WindowsPowerListener: Error handling hardware error: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    _subscription = null;
  }
}
