import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart' as win32;
import 'package:window_manager/window_manager.dart';
import 'package:solaris/models/crash_report.dart';
import 'package:solaris/widgets/crash_dialog.dart';

/// Centralized, high-performance diagnostic logging and crash recovery engine.
///
/// Designed with zero-overhead async I/O in release mode, circular memory buffering,
/// automated log rotation with Windows NTFS handle safety, in-flight rotation queue,
/// and native Win32 crash dialog fallbacks.
class LogService {
  static final LogService _instance = LogService._internal();
  static LogService get instance => _instance;

  LogService._internal();

  static const int _maxRecentLogs = 150;
  static const int _maxLogFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int _logCheckInterval = 200; // Check file size every 200 logs

  static final RegExp _timestampPrefixRegex = RegExp(
    r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}',
  );

  final ListQueue<String> _recentLogs = ListQueue<String>();
  final List<String> _pendingRotationLogs = <String>[];
  final ValueNotifier<CrashReport?> latestCrashReport =
      ValueNotifier<CrashReport?>(null);

  Directory? _logsDirectory;
  File? _appLogFile;
  File? _crashLogFile;
  IOSink? _appLogSink;
  int _logCounter = 0;
  bool _isInitialized = false;
  bool _isRotating = false;
  bool _isLoggingInternal = false;

  // Rate-limiting & anti-stacking guards for crash notifications
  bool _isCrashDialogActive = false;
  bool _hasShownNativeDialog = false;
  DateTime? _lastCrashNotificationTime;
  DateTime? _lastCrashDiskWriteTime;
  String? _lastCrashDiskSignature;
  GlobalKey<NavigatorState>? _rootNavigatorKey;

  /// Returns the active logs directory.
  Directory? get logsDirectory => _logsDirectory;

  /// Returns the current app log file.
  File? get appLogFile => _appLogFile;

  /// Returns the dedicated crash log file.
  File? get crashLogFile => _crashLogFile;

  /// Returns an unmodifiable snapshot of recent in-memory log entries.
  List<String> get recentLogs => List.unmodifiable(_recentLogs);

  /// Returns a user-friendly OS description, accurately recognizing Windows 11
  /// (NT builds >= 22000) which the underlying Windows kernel/Dart runtime reports as "Windows 10".
  static String get friendlyOperatingSystemVersion {
    final raw = Platform.operatingSystemVersion;
    if (Platform.isWindows) {
      final match = RegExp(r'Build (\d+)').firstMatch(raw);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (buildNumber >= 22000) {
          return raw.replaceFirst('Windows 10', 'Windows 11');
        }
      }
    }
    return raw;
  }

  /// Safely outputs diagnostic errors from within LogService itself without triggering
  /// ZoneSpecification.print loops or causing StackOverflow recursions.
  void _safeInternalPrint(String message) {
    try {
      if (kDebugMode) {
        stderr.writeln(message);
      }
    } catch (_) {}
  }

  /// Initializes the logging directory, rotates existing logs if needed,
  /// and opens an asynchronous file stream.
  Future<void> init({Directory? overrideLogsDir}) async {
    if (_isInitialized) return;

    try {
      if (overrideLogsDir != null) {
        _logsDirectory = overrideLogsDir;
      } else {
        _logsDirectory = await _resolveDefaultLogsDirectory();
      }

      if (_logsDirectory != null && !await _logsDirectory!.exists()) {
        await _logsDirectory!.create(recursive: true);
      }

      if (_logsDirectory != null) {
        _appLogFile = File(
          '${_logsDirectory!.path}${Platform.pathSeparator}app.log',
        );
        _crashLogFile = File(
          '${_logsDirectory!.path}${Platform.pathSeparator}crash.log',
        );

        await _rotateIfNecessary();
        if (_appLogSink == null) {
          await _openAppLogSink();
        }
      }

      _isInitialized = true;

      // Session start header
      final now = DateTime.now().toLocal();
      log(
        '=== SOLARIS SESSION STARTED: $now (PID: $pid, OS: $friendlyOperatingSystemVersion) ===',
        level: 'INIT',
      );
    } catch (e, stack) {
      _safeInternalPrint('LogService initialization failed: $e\n$stack');
    }
  }

  /// Resolves the optimal logs directory for the current platform.
  Future<Directory> _resolveDefaultLogsDirectory() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      return Directory('${appSupport.path}${Platform.pathSeparator}logs');
    } catch (_) {
      // Robust fallback on Windows if path_provider plugin is not yet registered
      if (Platform.isWindows) {
        final appData =
            Platform.environment['APPDATA'] ??
            Platform.environment['LOCALAPPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return Directory(
            '$appData${Platform.pathSeparator}Solaris${Platform.pathSeparator}logs',
          );
        }
      }
      return Directory('.${Platform.pathSeparator}logs');
    }
  }

  /// Opens the app.log file in append mode with an error listener on the background stream.
  /// Flushes any pending logs that arrived while rotation or initialization was taking place.
  Future<void> _openAppLogSink() async {
    try {
      if (_appLogSink != null) {
        try {
          await _appLogSink!.flush();
          await _appLogSink!.close();
        } catch (_) {}
        _appLogSink = null;
      }

      if (_appLogFile != null) {
        _appLogSink = _appLogFile!.openWrite(mode: FileMode.append);
        // Catch async background disk stream errors to prevent unhandled zone crashes
        unawaited(
          _appLogSink!.done.catchError((Object error, StackTrace stack) {
            _safeInternalPrint(
              'LogService: Background IOSink stream error: $error\n$stack',
            );
          }),
        );

        // Drain in-flight pending logs accumulated during rotation
        if (_pendingRotationLogs.isNotEmpty) {
          for (final pending in _pendingRotationLogs) {
            _appLogSink!.writeln(pending);
          }
          _pendingRotationLogs.clear();
        }
      }
    } catch (e) {
      _safeInternalPrint('Failed to open app.log sink: $e');
    }
  }

  /// Dispatches asynchronous log rotation if file size limit is reached.
  void _scheduleRotationIfNeeded() {
    if (_isRotating) return;
    unawaited(_rotateIfNecessary());
  }

  /// Rotates log files asynchronously with proper native handle closure for Windows NTFS:
  /// app.2.log (deleted) <- app.1.log <- app.log.
  Future<void> _rotateIfNecessary() async {
    if (_isRotating) return;
    _isRotating = true;

    try {
      if (_appLogFile == null || !await _appLogFile!.exists()) return;

      final length = await _appLogFile!.length();
      if (length < _maxLogFileSizeBytes) return;

      // Close the sink and await completion to release the OS file lock on Windows
      if (_appLogSink != null) {
        try {
          await _appLogSink!.flush();
          await _appLogSink!.close();
        } catch (e) {
          _safeInternalPrint(
            'LogService: Error closing sink during rotation: $e',
          );
        }
        _appLogSink = null;
      }

      final parentPath = _logsDirectory!.path;
      final log2 = File('$parentPath${Platform.pathSeparator}app.2.log');
      final log1 = File('$parentPath${Platform.pathSeparator}app.1.log');

      if (await log2.exists()) {
        try {
          await log2.delete();
        } catch (e) {
          _safeInternalPrint('LogService: Error deleting app.2.log: $e');
        }
      }

      if (await log1.exists()) {
        try {
          if (await log2.exists()) {
            await log2.delete();
          }
          await log1.rename(log2.path);
        } catch (e) {
          _safeInternalPrint(
            'LogService: Error renaming app.1.log to app.2.log: $e',
          );
        }
      }

      try {
        if (await log1.exists()) {
          await log1.delete();
        }
        await _appLogFile!.rename(log1.path);
      } catch (e) {
        _safeInternalPrint(
          'LogService: Error renaming app.log to app.1.log: $e',
        );
      }

      _appLogFile = File('$parentPath${Platform.pathSeparator}app.log');
      await _openAppLogSink();
    } catch (e) {
      _safeInternalPrint('LogService log rotation error: $e');
    } finally {
      _isRotating = false;
    }
  }

  /// Appends a message to the in-memory ring buffer and non-blocking file sink.
  void log(String message, {String level = 'INFO'}) {
    final now = DateTime.now();
    final timeStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';

    final String formatted;
    if (_timestampPrefixRegex.hasMatch(message)) {
      formatted = message;
    } else {
      formatted = '[$timeStr] [$level] $message';
    }

    // 1. Maintain lightweight circular in-memory buffer
    _recentLogs.add(formatted);
    if (_recentLogs.length > _maxRecentLogs) {
      _recentLogs.removeFirst();
    }

    // 2. Non-blocking disk write or queue during active rotation
    if (_isRotating || _appLogSink == null) {
      _pendingRotationLogs.add(formatted);
      if (_pendingRotationLogs.length > _maxRecentLogs) {
        _pendingRotationLogs.removeAt(0);
      }
    } else {
      if (!_isLoggingInternal) {
        _isLoggingInternal = true;
        try {
          _appLogSink?.writeln(formatted);
        } catch (e) {
          _safeInternalPrint('LogService: Failed writing log line: $e');
        } finally {
          _isLoggingInternal = false;
        }
      }
    }

    // 3. Periodic rotation check
    _logCounter++;
    if (_logCounter >= _logCheckInterval) {
      _logCounter = 0;
      _scheduleRotationIfNeeded();
    }
  }

  void logInfo(String message) => log(message, level: 'INFO');
  void logWarning(String message) => log(message, level: 'WARN');
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    final errorBuffer = StringBuffer(message);
    if (error != null) {
      errorBuffer.write(' | Exception: $error');
    }
    if (stackTrace != null) {
      errorBuffer.write('\n$stackTrace');
    }
    log(errorBuffer.toString(), level: 'ERROR');
  }

  /// Captures an unhandled fatal error, writes a structured crash report to crash.log,
  /// flushes all buffers to disk, and updates [latestCrashReport].
  Future<CrashReport> logCrash(
    Object error,
    StackTrace? stack, {
    String context = 'Unhandled Exception',
    FlutterErrorDetails? details,
  }) async {
    final effectiveStack = stack ?? (details?.stack) ?? StackTrace.current;
    final report = CrashReport(
      timestamp: DateTime.now(),
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      stackTrace: effectiveStack.toString(),
      context: context,
      osVersion: friendlyOperatingSystemVersion,
      dartVersion: Platform.version,
      pid: Platform.isWindows ? pid : 0,
      recentLogs: _recentLogs.toList(),
      logFilePath: _crashLogFile?.path ?? _appLogFile?.path,
    );

    final formattedReport = report.toFormattedReport();

    final errorTypeStr = error.runtimeType.toString();
    final errorMsgStr = error.toString();
    final crashSignature = '$errorTypeStr::$errorMsgStr';
    final now = DateTime.now();

    final shouldWriteDisk =
        _lastCrashDiskSignature != crashSignature ||
        _lastCrashDiskWriteTime == null ||
        now.difference(_lastCrashDiskWriteTime!) >=
            const Duration(milliseconds: 1500);

    if (shouldWriteDisk) {
      _lastCrashDiskSignature = crashSignature;
      _lastCrashDiskWriteTime = now;

      // 1. Immediate write to dedicated crash.log in append mode to preserve crash history
      try {
        if (_crashLogFile != null) {
          _crashLogFile!.writeAsStringSync(
            '$formattedReport\n\n',
            mode: FileMode.append,
            flush: true,
          );
        }
      } catch (e) {
        _safeInternalPrint('Failed to write crash.log: $e');
      }

      // 2. Flush to app.log as well
      try {
        _appLogSink?.writeln(formattedReport);
        await _appLogSink?.flush();
      } catch (e) {
        _safeInternalPrint('Failed to flush app.log during crash: $e');
      }
    } else {
      _safeInternalPrint(
        'LogService: Suppressed rapid identical crash disk write ($crashSignature)',
      );
    }

    latestCrashReport.value = report;
    return report;
  }

  /// Whether native Win32 dialogs and process launching are enabled.
  /// Automatically disabled in unit/widget test environments.
  bool enableNativeDialog = !Platform.environment.containsKey('FLUTTER_TEST');

  /// Unified crash handling entry point: logs report, enforces rate limits,
  /// displays [CrashDialog] when UI context is available, or triggers a native
  /// Win32 message box fallback during early boot.
  Future<void> handleCrash(
    Object error,
    StackTrace? stack, {
    required String context,
    GlobalKey<NavigatorState>? rootNavigatorKey,
    FlutterErrorDetails? details,
  }) async {
    try {
      final report = await logCrash(
        error,
        stack,
        context: context,
        details: details,
      );

      final now = DateTime.now();
      // Rate limit dialog presentations to avoid rapid stacking
      if (_lastCrashNotificationTime != null &&
          now.difference(_lastCrashNotificationTime!) <
              const Duration(seconds: 5)) {
        return;
      }
      _lastCrashNotificationTime = now;

      final navContext =
          (rootNavigatorKey ?? _rootNavigatorKey)?.currentContext;
      if (navContext != null && navContext.mounted) {
        if (!_isCrashDialogActive) {
          _isCrashDialogActive = true;
          try {
            if (Platform.isWindows) {
              try {
                final isVisible = await windowManager.isVisible();
                if (!isVisible) {
                  await windowManager.show();
                  // Do not call windowManager.focus() when app is un-minimized to avoid stealing focus from games
                }
              } catch (_) {}
            }
            if (!navContext.mounted) return;
            await showDialog<void>(
              context: navContext,
              barrierDismissible: true,
              builder: (_) => CrashDialog(report: report),
            );
          } catch (e) {
            _safeInternalPrint('LogService: Failed presenting CrashDialog: $e');
          } finally {
            _isCrashDialogActive = false;
          }
        }
      } else if (enableNativeDialog) {
        // Single modal message box fallback to avoid blocking cascade loops
        if (!_hasShownNativeDialog) {
          _hasShownNativeDialog = true;
          showNativeCrashDialog(
            title: 'Solaris — Unexpected Error',
            message:
                'Solaris encountered an unhandled error:\n\n'
                '${report.errorType}: ${report.message}\n\n'
                'A detailed traceback has been recorded to:\n'
                '${report.logFilePath ?? "logs folder"}\n\n'
                'Click OK to open the logs location.',
          );
          await openCrashLog();
        }
      }
    } catch (e, st) {
      _safeInternalPrint(
        'LogService: Critical failure in handleCrash: $e\n$st',
      );
    }
  }

  /// Opens the logs directory in Windows File Explorer.
  Future<bool> openLogsFolder() async {
    try {
      _logsDirectory ??= await _resolveDefaultLogsDirectory();
      if (!await _logsDirectory!.exists()) {
        await _logsDirectory!.create(recursive: true);
      }
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
      if (Platform.isWindows) {
        final normalizedPath = _logsDirectory!.path.replaceAll('/', r'\');
        await Process.run('explorer.exe', [normalizedPath]);
        return true;
      }
    } catch (e) {
      _safeInternalPrint('Error opening logs directory: $e');
    }
    return false;
  }

  /// Opens Windows File Explorer with the crash.log or app.log file highlighted.
  /// Uses separate arguments `['/select,', path]` to ensure Explorer parses correctly on Windows.
  /// Forward slashes are normalized to backslashes for native Windows Explorer command line parsing.
  Future<bool> openCrashLog() async {
    try {
      final targetFile = (_crashLogFile != null && _crashLogFile!.existsSync())
          ? _crashLogFile!
          : _appLogFile;

      if (targetFile == null || !targetFile.existsSync()) {
        return await openLogsFolder();
      }

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }

      if (Platform.isWindows) {
        // Separate /select, argument ensures Windows Explorer properly selects the file even with spaces
        final normalizedPath = targetFile.path.replaceAll('/', r'\');
        await Process.run('explorer.exe', ['/select,', normalizedPath]);
        return true;
      }
    } catch (e) {
      _safeInternalPrint('Error highlighting crash log: $e');
    }
    return false;
  }

  /// Shows a native Windows message box via Win32 API.
  /// Used as a zero-trust fallback if Flutter engine or window fails during startup.
  void showNativeCrashDialog({
    String title = 'Solaris — Fatal Error',
    required String message,
  }) {
    if (!enableNativeDialog || !Platform.isWindows) return;
    final lpText = message.toNativeUtf16();
    final lpCaption = title.toNativeUtf16();
    try {
      win32.MessageBox(
        win32.NULL,
        lpText,
        lpCaption,
        win32.MB_OK | win32.MB_ICONERROR | win32.MB_SYSTEMMODAL,
      );
    } catch (e) {
      _safeInternalPrint('Win32 MessageBox failed: $e');
    } finally {
      calloc.free(lpText);
      calloc.free(lpCaption);
    }
  }

  /// Configures global Flutter framework, Dart runtime dispatcher, and UI fallback traps.
  void setupGlobalErrorHooks({GlobalKey<NavigatorState>? rootNavigatorKey}) {
    if (rootNavigatorKey != null) {
      _rootNavigatorKey = rootNavigatorKey;
    }
    // 1. Flutter framework layout & rendering errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.silent) {
        logWarning(
          'Flutter framework non-fatal notification: ${details.exception}',
        );
        return;
      }
      handleCrash(
        details.exception,
        details.stack,
        context: 'Flutter Framework',
        rootNavigatorKey: rootNavigatorKey,
        details: details,
      );
      FlutterError.presentError(details);
    };

    // 2. Unhandled Dart asynchronous zone / isolate errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      handleCrash(
        error,
        stack,
        context: 'Asynchronous Dispatcher',
        rootNavigatorKey: rootNavigatorKey,
      );
      return true; // Mark as handled to suppress unhandled native termination
    };

    // 3. UI widget build crash fallback
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.5),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Component Display Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details.exception.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => LogService.instance.openCrashLog(),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open Logs'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }

  /// Flushes and closes resources on shutdown.
  Future<void> dispose() async {
    try {
      await _appLogSink?.flush();
      await _appLogSink?.close();
      _appLogSink = null;
      _recentLogs.clear();
      _pendingRotationLogs.clear();
      latestCrashReport.value = null;
      _logsDirectory = null;
      _appLogFile = null;
      _crashLogFile = null;
      _isInitialized = false;
      _isRotating = false;
      _isLoggingInternal = false;
      _isCrashDialogActive = false;
      _hasShownNativeDialog = false;
      _lastCrashNotificationTime = null;
      _lastCrashDiskWriteTime = null;
      _lastCrashDiskSignature = null;
      _rootNavigatorKey = null;
      _logCounter = 0;
    } catch (e) {
      _safeInternalPrint('LogService: Error during dispose: $e');
    }
  }
}
