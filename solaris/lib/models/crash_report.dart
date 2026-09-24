/// Encapsulates structured diagnostics and traceback details for an unhandled crash.
class CrashReport {
  final DateTime timestamp;
  final String errorType;
  final String message;
  final String stackTrace;
  final String context;
  final String osVersion;
  final String dartVersion;
  final int pid;
  final List<String> recentLogs;
  final String? logFilePath;

  const CrashReport({
    required this.timestamp,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    required this.context,
    required this.osVersion,
    required this.dartVersion,
    required this.pid,
    required this.recentLogs,
    this.logFilePath,
  });

  /// Formats the crash report into a human-readable diagnostics text block
  /// suitable for writing to crash.log or sending to developers.
  String toFormattedReport() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('=== SOLARIS UNHANDLED CRASH REPORT ===');
    buffer.writeln(
      'Timestamp:    ${timestamp.toIso8601String()} (${timestamp.toLocal()})',
    );
    buffer.writeln('Context:      $context');
    buffer.writeln('Process ID:   $pid');
    buffer.writeln('OS Platform:  $osVersion');
    buffer.writeln('Dart Runtime: $dartVersion');
    if (logFilePath != null) {
      buffer.writeln('Log File:     $logFilePath');
    }
    buffer.writeln('-' * 80);
    buffer.writeln('EXCEPTION:');
    buffer.writeln('[$errorType] $message');
    buffer.writeln('-' * 80);
    buffer.writeln('TRACEBACK / STACKTRACE:');
    buffer.writeln(
      stackTrace.trim().isNotEmpty
          ? stackTrace.trim()
          : 'No stacktrace available.',
    );
    buffer.writeln('-' * 80);
    buffer.writeln('RECENT LOG BUFFER (LAST ${recentLogs.length} EVENTS):');
    if (recentLogs.isEmpty) {
      buffer.writeln('(No recent log records captured)');
    } else {
      for (final line in recentLogs) {
        buffer.writeln(line);
      }
    }
    buffer.writeln('=' * 80);
    return buffer.toString();
  }

  /// Compact single-string summary suitable for copying to clipboard.
  String toClipboardSummary() {
    return '''[Solaris Crash] $context: [$errorType] $message
OS: $osVersion
Time: ${timestamp.toLocal()}
Stack:
$stackTrace''';
  }
}
