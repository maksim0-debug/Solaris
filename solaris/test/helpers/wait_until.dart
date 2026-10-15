import 'package:flutter_test/flutter_test.dart';

/// Waits for an observable outcome instead of assuming a wall-clock delay is enough.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed >= timeout) {
      fail(reason ?? 'Condition was not reached within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
