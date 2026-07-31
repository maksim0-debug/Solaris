import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/ssrf_safe_http_client.dart';

enum TransactionStatus { pending, retrying, completed, failed }

class PendingWebhookTransaction {
  final String deliveryId;
  final String webhookId;
  final String url;
  final String eventName;
  final String payloadJson;
  final int attemptCount;
  final DateTime createdAt;
  final TransactionStatus status;
  final String? lastError;

  PendingWebhookTransaction({
    required this.deliveryId,
    required this.webhookId,
    required this.url,
    required this.eventName,
    required this.payloadJson,
    this.attemptCount = 0,
    DateTime? createdAt,
    this.status = TransactionStatus.pending,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  PendingWebhookTransaction copyWith({
    int? attemptCount,
    TransactionStatus? status,
    Object? lastError = _sentinel,
  }) {
    return PendingWebhookTransaction(
      deliveryId: deliveryId,
      webhookId: webhookId,
      url: url,
      eventName: eventName,
      payloadJson: payloadJson,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      status: status ?? this.status,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'deliveryId': deliveryId,
    'webhookId': webhookId,
    'url': url,
    'eventName': eventName,
    'payloadJson': payloadJson,
    'attemptCount': attemptCount,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'lastError': lastError,
  };

  factory PendingWebhookTransaction.fromJson(Map<String, dynamic> json) {
    return PendingWebhookTransaction(
      deliveryId: json['deliveryId'] as String,
      webhookId: json['webhookId'] as String,
      url: json['url'] as String,
      eventName: json['eventName'] as String,
      payloadJson: json['payloadJson'] as String,
      attemptCount: json['attemptCount'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      lastError: json['lastError'] as String?,
    );
  }
}

class WebhookServiceState {
  final bool isProcessing;
  final int pendingCount;
  final int dlqCount;
  final List<PendingWebhookTransaction> activeQueue;

  const WebhookServiceState({
    this.isProcessing = false,
    this.pendingCount = 0,
    this.dlqCount = 0,
    this.activeQueue = const [],
  });

  WebhookServiceState copyWith({
    bool? isProcessing,
    int? pendingCount,
    int? dlqCount,
    List<PendingWebhookTransaction>? activeQueue,
  }) {
    return WebhookServiceState(
      isProcessing: isProcessing ?? this.isProcessing,
      pendingCount: pendingCount ?? this.pendingCount,
      dlqCount: dlqCount ?? this.dlqCount,
      activeQueue: activeQueue ?? this.activeQueue,
    );
  }
}

class WebhookService extends Notifier<WebhookServiceState> {
  static const int maxConcurrentDeliveries = 5;
  static const int maxDlqEntries = 100;

  File? _walFile;
  IOSink? _walSink;
  File? _dlqFile;

  bool _isCompacting = false;
  final List<PendingWebhookTransaction> _compactionPendingBuffer = [];
  final List<PendingWebhookTransaction> _inMemoryQueue = [];
  bool _isQueuePaused = false;
  int _activeWorkerCount = 0;

  @override
  WebhookServiceState build() {
    state = const WebhookServiceState();
    _initStorageAndListeners();
    return state;
  }

  Future<void> _initStorageAndListeners() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final solarisDir = Directory('${appDir.path}\\Solaris');
      if (!await solarisDir.exists()) {
        await solarisDir.create(recursive: true);
      }

      _walFile = File('${solarisDir.path}\\webhook_queue.jsonl');
      _dlqFile = File('${solarisDir.path}\\webhook_dlq.jsonl');

      await _recoverOrphanedWALFiles(_walFile!);
      await _loadTransactionsFromWAL();
      if (!ref.mounted) return;
      _openWALSink();

      _setupProviderListeners();
      _processQueue();
    } catch (e) {
      debugPrint('WebhookService initialization error: $e');
    }
  }

  void _setupProviderListeners() {
    // 1. Solar State Listener
    ref.listen(solarStateStreamProvider, (prev, next) {
      next.whenData((solar) {
        if (prev?.value != null) {
          final p = prev!.value!;
          // Sunrise
          if (p.sunElevation < 0 && solar.sunElevation >= 0) {
            dispatch(WebhookEventType.onSunrise, {
              'sun_elevation': solar.sunElevation,
              'sun_azimuth': solar.sunAzimuth,
            });
          }
          // Sunset
          if (p.sunElevation >= 0 && solar.sunElevation < 0) {
            dispatch(WebhookEventType.onSunset, {
              'sun_elevation': solar.sunElevation,
              'sun_azimuth': solar.sunAzimuth,
            });
          }
          // Day Phase Changed
          if (p.currentPhase != solar.currentPhase) {
            dispatch(WebhookEventType.onDayPhaseChanged, {
              'previous_phase': p.currentPhase.name,
              'current_phase': solar.currentPhase.name,
              'sun_elevation': solar.sunElevation,
            });
          }
        }
      });
    });

    // 2. Gaming Mode Listener
    ref.listen(gamingModeProvider, (prev, next) {
      if (prev != next) {
        if (next == true) {
          dispatch(WebhookEventType.onGameModeActivated, {
            'is_game_mode': true,
          });
        } else {
          dispatch(WebhookEventType.onGameModeDeactivated, {
            'is_game_mode': false,
          });
        }
      }
    });

    // 3. Auto-Brightness Listener
    ref.listen(autoBrightnessAdjustmentProvider, (prev, next) {
      if (prev != next) {
        dispatch(WebhookEventType.onAutoBrightnessToggled, {'enabled': next});
      }
    });
  }

  /// Recover orphaned .tmp or .old WAL files resulting from abrupt power loss during compaction.
  static Future<void> _recoverOrphanedWALFiles(File mainFile) async {
    final tmpFile = File('${mainFile.path}.tmp');
    final oldFile = File('${mainFile.path}.old');

    if (!await mainFile.exists()) {
      if (await tmpFile.exists()) {
        await tmpFile.rename(mainFile.path);
      } else if (await oldFile.exists()) {
        await oldFile.rename(mainFile.path);
      }
    } else {
      if (await tmpFile.exists()) await tmpFile.delete();
      if (await oldFile.exists()) await oldFile.delete();
    }
  }

  Future<void> _loadTransactionsFromWAL() async {
    if (_walFile == null || !await _walFile!.exists()) return;
    try {
      final lines = await _walFile!.readAsLines();
      _inMemoryQueue.clear();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final jsonMap = jsonDecode(line) as Map<String, dynamic>;
          final tx = PendingWebhookTransaction.fromJson(jsonMap);
          if (tx.status != TransactionStatus.completed) {
            _inMemoryQueue.add(tx);
          }
        } catch (_) {}
      }
      if (!ref.mounted) return;
      _updateStateQueue();
    } catch (e) {
      debugPrint('Failed to load WAL queue: $e');
    }
  }

  void _openWALSink() {
    if (_walFile == null) return;
    _walSink = _walFile!.openWrite(mode: FileMode.append);
  }

  /// Dispatches an event payload to all subscribed and enabled webhooks.
  void dispatch(
    WebhookEventType event,
    Map<String, dynamic> rawData, {
    StateChangeSource source = StateChangeSource.system,
    String? originClientId,
  }) {
    final settingsAsync = ref.read(settingsProvider);
    final settingsMap = settingsAsync.value;
    if (settingsMap == null) return;

    final settings = settingsMap['all'];
    if (settings == null) return;

    final activeWebhooks = settings.webhooks
        .where((w) => w.isEnabled && w.events.contains(event))
        .toList();

    if (activeWebhooks.isEmpty) return;

    // Privacy-First Data Sanitization
    Map<String, dynamic> sanitizedData = Map<String, dynamic>.from(rawData);
    if (event == WebhookEventType.onWeatherUpdated) {
      // Omit exact GPS coordinates or city names
      sanitizedData.remove('lat');
      sanitizedData.remove('latitude');
      sanitizedData.remove('lon');
      sanitizedData.remove('longitude');
      sanitizedData.remove('city');
    } else if (event == WebhookEventType.onLocationChanged) {
      // Signal-Only
      sanitizedData = {'signal_only': true};
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();

    for (final webhook in activeWebhooks) {
      final deliveryId = _generateDeliveryId();
      final bodyMap = {
        'event': event.wireName,
        'timestamp': timestamp,
        'delivery_id': deliveryId,
        'data': sanitizedData,
      };

      final payloadJson = jsonEncode(bodyMap);

      final tx = PendingWebhookTransaction(
        deliveryId: deliveryId,
        webhookId: webhook.id,
        url: webhook.url,
        eventName: event.wireName,
        payloadJson: payloadJson,
      );

      _enqueueTransaction(tx);
    }
  }

  void _enqueueTransaction(PendingWebhookTransaction tx) {
    if (_isCompacting) {
      _compactionPendingBuffer.add(tx);
    } else {
      _inMemoryQueue.add(tx);
      _walSink?.writeln(jsonEncode(tx.toJson()));
      _walSink?.flush();
    }
    _updateStateQueue();
    _processQueue();
  }

  void _updateStateQueue() {
    state = state.copyWith(
      pendingCount: _inMemoryQueue.length,
      activeQueue: List.unmodifiable(_inMemoryQueue),
    );
  }

  Future<void> _processQueue() async {
    if (_isQueuePaused ||
        _inMemoryQueue.isEmpty ||
        _activeWorkerCount >= maxConcurrentDeliveries) {
      return;
    }

    state = state.copyWith(isProcessing: true);

    while (_inMemoryQueue.isNotEmpty &&
        _activeWorkerCount < maxConcurrentDeliveries &&
        !_isQueuePaused) {
      final txIndex = _inMemoryQueue.indexWhere(
        (t) => t.status == TransactionStatus.pending,
      );
      if (txIndex == -1) break;

      final tx = _inMemoryQueue[txIndex];
      _inMemoryQueue[txIndex] = tx.copyWith(status: TransactionStatus.retrying);
      _activeWorkerCount++;

      _deliverTransaction(tx).then((_) {
        _activeWorkerCount--;
        _processQueue();
      });
    }

    if (_activeWorkerCount == 0 && _inMemoryQueue.isEmpty) {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> _deliverTransaction(PendingWebhookTransaction tx) async {
    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.value?['all'];
    WebhookConfig? webhookConfig;

    if (settings != null) {
      try {
        webhookConfig = settings.webhooks.firstWhere(
          (w) => w.id == tx.webhookId,
        );
      } catch (_) {}
    }

    if (webhookConfig == null || !webhookConfig.isEnabled) {
      _removeTransactionFromMemory(tx.deliveryId);
      return;
    }

    int attempt = tx.attemptCount + 1;
    bool success = false;
    String? errorMessage;

    try {
      final response = await SsrfSafeHttpClient.postJson(
        Uri.parse(tx.url),
        tx.payloadJson,
        webhookConfig: webhookConfig,
        deliveryId: tx.deliveryId,
        eventName: tx.eventName,
      );

      if (response.isSuccess) {
        success = true;
      } else {
        errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    if (success) {
      // Successful delivery
      _removeTransactionFromMemory(tx.deliveryId);
      _resetWebhookFailureCount(webhookConfig.id);
      if (_inMemoryQueue.length > 500) {
        compactWAL();
      }
    } else {
      debugPrint(
        'Webhook Delivery failed (Attempt $attempt/3) for ${tx.url}: $errorMessage',
      );
      _incrementWebhookFailureCount(webhookConfig.id);

      if (attempt < 3) {
        // Exponential backoff: 1s, 2s, 4s
        final delaySeconds = 1 << (attempt - 1);
        await Future<void>.delayed(Duration(seconds: delaySeconds));

        final updatedTx = tx.copyWith(
          attemptCount: attempt,
          status: TransactionStatus.pending,
          lastError: errorMessage,
        );

        final idx = _inMemoryQueue.indexWhere(
          (t) => t.deliveryId == tx.deliveryId,
        );
        if (idx != -1) {
          _inMemoryQueue[idx] = updatedTx;
        }
      } else {
        // Retries exhausted -> Record to DLQ and remove from WAL queue
        await _recordToDLQ(
          tx.copyWith(attemptCount: attempt, lastError: errorMessage),
        );
        _removeTransactionFromMemory(tx.deliveryId);
      }
    }
  }

  void _removeTransactionFromMemory(String deliveryId) {
    _inMemoryQueue.removeWhere((t) => t.deliveryId == deliveryId);
    _updateStateQueue();
  }

  void _incrementWebhookFailureCount(String webhookId) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final settingsMap = ref.read(settingsProvider).value;
    if (settingsMap == null) return;
    final settings = settingsMap['all'];
    if (settings == null) return;

    final updatedWebhooks = settings.webhooks.map((w) {
      if (w.id == webhookId) {
        final newCount = w.failureCount + 1;
        // Auto-disable if 10 consecutive failures
        return w.copyWith(
          failureCount: newCount,
          isEnabled: newCount >= 10 ? false : w.isEnabled,
        );
      }
      return w;
    }).toList();

    settingsNotifier.setWebhooks(updatedWebhooks);
  }

  void _resetWebhookFailureCount(String webhookId) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final settingsMap = ref.read(settingsProvider).value;
    if (settingsMap == null) return;
    final settings = settingsMap['all'];
    if (settings == null) return;

    final updatedWebhooks = settings.webhooks.map((w) {
      if (w.id == webhookId && w.failureCount > 0) {
        return w.copyWith(
          failureCount: 0,
          lastTriggeredAt: DateTime.now().toUtc(),
        );
      }
      return w;
    }).toList();

    settingsNotifier.setWebhooks(updatedWebhooks);
  }

  Future<void> _recordToDLQ(PendingWebhookTransaction tx) async {
    if (_dlqFile == null) return;
    try {
      final sink = _dlqFile!.openWrite(mode: FileMode.append);
      sink.writeln(jsonEncode(tx.toJson()));
      await sink.flush();
      await sink.close();

      // Read lines and enforce max DLQ size
      final lines = await _dlqFile!.readAsLines();
      if (lines.length > maxDlqEntries) {
        final trimmedLines = lines.sublist(lines.length - maxDlqEntries);
        await _dlqFile!.writeAsString(trimmedLines.join('\n') + '\n');
      }
      state = state.copyWith(
        dlqCount: lines.length > maxDlqEntries ? maxDlqEntries : lines.length,
      );
    } catch (e) {
      debugPrint('Failed to record DLQ: $e');
    }
  }

  Future<List<PendingWebhookTransaction>> getDLQEntries() async {
    if (_dlqFile == null || !await _dlqFile!.exists()) return [];
    try {
      final lines = await _dlqFile!.readAsLines();
      final list = <PendingWebhookTransaction>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          list.add(
            PendingWebhookTransaction.fromJson(
              jsonDecode(line) as Map<String, dynamic>,
            ),
          );
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearDLQ([String? webhookId]) async {
    if (_dlqFile != null && await _dlqFile!.exists()) {
      if (webhookId == null || webhookId.isEmpty) {
        await _dlqFile!.writeAsString('');
        state = state.copyWith(dlqCount: 0);
      } else {
        final lines = await _dlqFile!.readAsLines();
        final kept = <String>[];
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final jsonMap = jsonDecode(line) as Map<String, dynamic>;
            final tx = PendingWebhookTransaction.fromJson(jsonMap);
            if (tx.webhookId != webhookId) {
              kept.add(line);
            }
          } catch (_) {}
        }
        await _dlqFile!.writeAsString(
          kept.isEmpty ? '' : '${kept.join('\n')}\n',
        );
        state = state.copyWith(dlqCount: kept.length);
      }
    }
  }

  /// Retries pending DLQ transactions by moving them back into active WAL queue
  Future<int> retryDLQTransactions([String? webhookId]) async {
    final entries = await getDLQEntries();
    if (entries.isEmpty) return 0;

    final toRetry = <PendingWebhookTransaction>[];
    final toKeep = <PendingWebhookTransaction>[];

    for (final tx in entries) {
      if (webhookId == null || webhookId.isEmpty || tx.webhookId == webhookId) {
        toRetry.add(
          tx.copyWith(
            attemptCount: 0,
            status: TransactionStatus.pending,
            lastError: null,
          ),
        );
      } else {
        toKeep.add(tx);
      }
    }

    if (toRetry.isEmpty) return 0;

    // Rewrite DLQ file with remaining items
    if (_dlqFile != null) {
      if (toKeep.isEmpty) {
        await _dlqFile!.writeAsString('');
        state = state.copyWith(dlqCount: 0);
      } else {
        final lines = toKeep.map((t) => jsonEncode(t.toJson())).join('\n');
        await _dlqFile!.writeAsString('$lines\n');
        state = state.copyWith(dlqCount: toKeep.length);
      }
    }

    // Re-enqueue transactions into active WAL queue
    for (final tx in toRetry) {
      _enqueueTransaction(tx);
    }

    return toRetry.length;
  }

  Future<bool> sendTestPing(String webhookId) async {
    final settingsMap = ref.read(settingsProvider).value;
    if (settingsMap == null) return false;
    final settings = settingsMap['all'];
    if (settings == null) return false;

    WebhookConfig webhook;
    try {
      webhook = settings.webhooks.firstWhere((w) => w.id == webhookId);
    } catch (_) {
      return false;
    }

    final deliveryId = _generateDeliveryId();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final bodyMap = {
      'event': 'test_ping',
      'timestamp': timestamp,
      'delivery_id': deliveryId,
      'data': {
        'message': 'Solaris Control API Webhook Test Ping',
        'app': 'Solaris',
        'version': '1.1.0',
      },
    };

    final payloadJson = jsonEncode(bodyMap);

    try {
      final response = await SsrfSafeHttpClient.postJson(
        Uri.parse(webhook.url),
        payloadJson,
        webhookConfig: webhook,
        deliveryId: deliveryId,
        eventName: 'test_ping',
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Send Test Ping failed: $e');
      return false;
    }
  }

  /// Atomic WAL compaction with 5-attempt retry loop for NTFS OS Error 32.
  Future<void> compactWAL() async {
    if (_walFile == null || _isCompacting) return;
    _isCompacting = true;

    try {
      await _walSink?.flush();
      await _walSink?.close();
      _walSink = null;

      final tempFile = File('${_walFile!.path}.tmp');
      final sink = tempFile.openWrite(mode: FileMode.write);
      for (final tx in _inMemoryQueue) {
        if (tx.status != TransactionStatus.completed) {
          sink.writeln(jsonEncode(tx.toJson()));
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.exists()) {
        final replaced = await _safeAtomicReplace(tempFile, _walFile!);
        if (!replaced) {
          final backupFile = File('${_walFile!.path}.old');
          if (await _walFile!.exists()) {
            if (await backupFile.exists()) await backupFile.delete();
            await _walFile!.rename(backupFile.path);
          }
          await tempFile.rename(_walFile!.path);
          if (await backupFile.exists()) await backupFile.delete();
        }
      }

      _openWALSink();

      for (final pendingTx in _compactionPendingBuffer) {
        _inMemoryQueue.add(pendingTx);
        _walSink?.writeln(jsonEncode(pendingTx.toJson()));
      }
      await _walSink?.flush();
      _compactionPendingBuffer.clear();
    } catch (e) {
      debugPrint('WAL Compaction error: $e');
    } finally {
      _isCompacting = false;
      _updateStateQueue();
    }
  }

  static Future<bool> _safeAtomicReplace(File tempFile, File targetFile) async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetFile.path);
        return true;
      } catch (e) {
        if (attempt == 4) return false;
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
    return false;
  }

  void pauseQueue() {
    _isQueuePaused = true;
  }

  void resumeQueue() {
    _isQueuePaused = false;
    _processQueue();
  }

  Future<void> flushWAL() async {
    await _walSink?.flush();
  }

  String _generateDeliveryId() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode('deliv_$now');
    final hash = base64Url.encode(bytes).replaceAll('=', '');
    return 'deliv-${hash.substring(0, hash.length > 24 ? 24 : hash.length)}';
  }
}
