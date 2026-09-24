import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/crash_report.dart';
import 'package:solaris/services/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('solaris_log_test_');
  });

  tearDown(() async {
    await LogService.instance.dispose();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('LogService & Crash Diagnostics Tests', () {
    test(
      'initializes cleanly in specified directory and creates app.log',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);

        expect(logService.logsDirectory?.path, equals(tempDir.path));
        expect(logService.appLogFile?.existsSync(), isTrue);
        expect(logService.recentLogs.isNotEmpty, isTrue);
        expect(
          logService.recentLogs.first,
          contains('SOLARIS SESSION STARTED'),
        );
      },
    );

    test(
      'log() appends to circular memory buffer and formats with level',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);

        logService.log('Custom operational message', level: 'DEBUG');
        expect(
          logService.recentLogs.any(
            (line) =>
                line.contains('[DEBUG]') &&
                line.contains('Custom operational message'),
          ),
          isTrue,
        );

        logService.logInfo('Informational message');
        expect(
          logService.recentLogs.any(
            (line) =>
                line.contains('[INFO]') &&
                line.contains('Informational message'),
          ),
          isTrue,
        );

        logService.logWarning('Warning notice');
        expect(
          logService.recentLogs.any(
            (line) =>
                line.contains('[WARN]') && line.contains('Warning notice'),
          ),
          isTrue,
        );

        logService.logError('Critical error occurred');
        expect(
          logService.recentLogs.any(
            (line) =>
                line.contains('[ERROR]') &&
                line.contains('Critical error occurred'),
          ),
          isTrue,
        );
      },
    );

    test(
      'circular memory buffer caps at max capacity without memory leak',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);

        for (int i = 0; i < 200; i++) {
          logService.log('Stress test record #$i');
        }

        // Buffer cap is 150 items
        expect(logService.recentLogs.length, equals(150));
        expect(logService.recentLogs.last, contains('Stress test record #199'));
        expect(
          logService.recentLogs.any(
            (line) => line.contains('Stress test record #0'),
          ),
          isFalse,
        );
      },
    );

    test(
      'logCrash captures exact exception type, message, stacktrace, and recent logs',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);

        logService.log('Pre-crash checkpoint 1');
        logService.log('Pre-crash checkpoint 2');

        try {
          throw const FormatException(
            'Corrupted monitor calibration profile payload',
          );
        } catch (e, stack) {
          final report = await logService.logCrash(
            e,
            stack,
            context: 'MonitorCalibrationUnit',
          );

          expect(report.errorType, equals('FormatException'));
          expect(
            report.message,
            contains('Corrupted monitor calibration profile payload'),
          );
          expect(report.context, equals('MonitorCalibrationUnit'));
          expect(report.stackTrace, contains('log_service_test.dart'));
          expect(
            report.recentLogs.any(
              (line) => line.contains('Pre-crash checkpoint 2'),
            ),
            isTrue,
          );

          // Verify dedicated crash.log was written synchronously
          final crashFile = File(
            '${tempDir.path}${Platform.pathSeparator}crash.log',
          );
          expect(crashFile.existsSync(), isTrue);

          final crashContent = crashFile.readAsStringSync();
          expect(
            crashContent,
            contains('=== SOLARIS UNHANDLED CRASH REPORT ==='),
          );
          expect(crashContent, contains('EXCEPTION:'));
          expect(crashContent, contains('FormatException'));
          expect(crashContent, contains('TRACEBACK / STACKTRACE:'));
          expect(crashContent, contains('RECENT LOG BUFFER'));

          // Verify latestCrashReport notifier updated
          expect(logService.latestCrashReport.value, isNotNull);
          expect(
            logService.latestCrashReport.value?.message,
            equals(report.message),
          );

          // Verify clipboard summary formatting
          final clipboardText = report.toClipboardSummary();
          expect(
            clipboardText,
            contains('[Solaris Crash] MonitorCalibrationUnit'),
          );
          expect(clipboardText, contains('Stack:'));
        }
      },
    );

    test(
      'CrashReport toFormattedReport and toClipboardSummary formatting validation',
      () {
        final report = CrashReport(
          timestamp: DateTime(2026, 9, 24, 12, 0, 0),
          errorType: 'RangeError',
          message: 'Value not in range: 100',
          stackTrace: 'package:solaris/service.dart:42:10\nmain.dart:15:3',
          context: 'BrightnessPipeline',
          osVersion: 'Windows 11 Pro 64-bit',
          dartVersion: '3.13.1',
          pid: 12345,
          recentLogs: ['[2026-09-24 11:59:59.000] [INFO] Heartbeat OK'],
          logFilePath: r'C:\Users\User\AppData\Roaming\Solaris\logs\crash.log',
        );

        final formatted = report.toFormattedReport();
        expect(formatted, contains('Timestamp:'));
        expect(formatted, contains('Context:      BrightnessPipeline'));
        expect(formatted, contains('Process ID:   12345'));
        expect(formatted, contains('OS Platform:  Windows 11 Pro 64-bit'));
        expect(formatted, contains('Dart Runtime: 3.13.1'));
        expect(
          formatted,
          contains(
            'Log File:     C:\\Users\\User\\AppData\\Roaming\\Solaris\\logs\\crash.log',
          ),
        );
        expect(formatted, contains('[RangeError] Value not in range: 100'));
        expect(formatted, contains('package:solaris/service.dart:42:10'));
        expect(formatted, contains('[INFO] Heartbeat OK'));

        final summary = report.toClipboardSummary();
        expect(
          summary,
          contains(
            '[Solaris Crash] BrightnessPipeline: [RangeError] Value not in range: 100',
          ),
        );
        expect(summary, contains('Windows 11 Pro 64-bit'));
      },
    );

    test(
      'handleCrash rate-limits rapid repeated crash notifications',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);

        // Trigger first crash
        await logService.handleCrash(
          Exception('Crash 1'),
          StackTrace.current,
          context: 'RapidTest1',
        );
        expect(
          logService.latestCrashReport.value?.message,
          contains('Crash 1'),
        );

        // Trigger immediate second crash (within 5 seconds)
        await logService.handleCrash(
          Exception('Crash 2'),
          StackTrace.current,
          context: 'RapidTest2',
        );
        // File still records the crash
        expect(
          logService.latestCrashReport.value?.message,
          contains('Crash 2'),
        );
      },
    );

    test('bracketed messages retain timestamp and log level prefix', () async {
      final logService = LogService.instance;
      await logService.init(overrideLogsDir: tempDir);

      logService.logInfo('[Tray] Icon initialized');
      logService.logError('[Database] Connection timed out');

      final trayLog = logService.recentLogs.firstWhere(
        (line) => line.contains('[Tray] Icon initialized'),
      );
      expect(trayLog, contains('[INFO]'));
      expect(RegExp(r'^\[\d{4}-\d{2}-\d{2}').hasMatch(trayLog), isTrue);

      final dbLog = logService.recentLogs.firstWhere(
        (line) => line.contains('[Database] Connection timed out'),
      );
      expect(dbLog, contains('[ERROR]'));
      expect(RegExp(r'^\[\d{4}-\d{2}-\d{2}').hasMatch(dbLog), isTrue);
    });

    test('dispose completely resets singleton state and buffers', () async {
      final logService = LogService.instance;
      await logService.init(overrideLogsDir: tempDir);

      logService.log('Sample message before dispose');
      expect(logService.recentLogs.isNotEmpty, isTrue);

      await logService.dispose();

      expect(logService.recentLogs.isEmpty, isTrue);
      expect(logService.latestCrashReport.value, isNull);
      expect(logService.appLogFile, isNull);
      expect(logService.crashLogFile, isNull);
      expect(logService.logsDirectory, isNull);
    });

    test(
      'log rotation handles pre-existing target files cleanly on Windows NTFS',
      () async {
        final logService = LogService.instance;

        // Seed directory with existing rotated files
        final existingLog1 = File(
          '${tempDir.path}${Platform.pathSeparator}app.1.log',
        );
        final existingLog2 = File(
          '${tempDir.path}${Platform.pathSeparator}app.2.log',
        );
        final oversizedAppLog = File(
          '${tempDir.path}${Platform.pathSeparator}app.log',
        );

        existingLog1.writeAsStringSync('previous app.1 log content');
        existingLog2.writeAsStringSync('previous app.2 log content');
        // Create > 5MB file
        oversizedAppLog.writeAsStringSync('A' * (5 * 1024 * 1024 + 128));

        // Initializing should safely rotate without crashing on OS Error 183
        await logService.init(overrideLogsDir: tempDir);

        expect(existingLog2.existsSync(), isTrue);
        expect(
          existingLog2.readAsStringSync(),
          equals('previous app.1 log content'),
        );

        expect(existingLog1.existsSync(), isTrue);
        expect(
          existingLog1.lengthSync(),
          greaterThanOrEqualTo(5 * 1024 * 1024),
        );

        expect(oversizedAppLog.existsSync(), isTrue);
        expect(oversizedAppLog.lengthSync(), lessThan(10 * 1024));
      },
    );

    test(
      'setupGlobalErrorHooks suppresses silent Flutter framework errors',
      () async {
        final logService = LogService.instance;
        await logService.init(overrideLogsDir: tempDir);
        logService.setupGlobalErrorHooks();

        FlutterError.onError!(
          FlutterErrorDetails(
            exception: Exception('Silent layout overflow warning'),
            silent: true,
          ),
        );

        // Verify that silent error did NOT trigger a crash report
        expect(logService.latestCrashReport.value, isNull);
        final crashLog = File(
          '${tempDir.path}${Platform.pathSeparator}crash.log',
        );
        expect(crashLog.existsSync(), isFalse);

        // Verify it was recorded as a WARN in recent logs
        expect(
          logService.recentLogs.any(
            (line) =>
                line.contains('[WARN]') &&
                line.contains('Flutter framework non-fatal notification'),
          ),
          isTrue,
        );
      },
    );

    test('rapid identical crashes throttle duplicate disk writes', () async {
      final logService = LogService.instance;
      await logService.init(overrideLogsDir: tempDir);

      final crashFile = File(
        '${tempDir.path}${Platform.pathSeparator}crash.log',
      );

      // Trigger first crash
      await logService.logCrash(
        Exception('Throttled Exception'),
        StackTrace.current,
      );
      expect(crashFile.existsSync(), isTrue);
      final sizeAfterFirst = crashFile.lengthSync();

      // Trigger identical crash immediately
      await logService.logCrash(
        Exception('Throttled Exception'),
        StackTrace.current,
      );
      final sizeAfterSecond = crashFile.lengthSync();

      // Size should remain unchanged because disk write was throttled
      expect(sizeAfterSecond, equals(sizeAfterFirst));
    });
  });
}
