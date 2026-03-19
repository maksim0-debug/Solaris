import 'dart:async';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class TimeService {
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    String timeZoneName = 'UTC';
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = tzInfo is String ? tzInfo : (tzInfo.identifier as String);
    } catch (_) {
      // Default to UTC if we can't get local timezone
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      if (timeZoneName == 'Europe/Kiev') {
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Kyiv'));
          return;
        } catch (_) {}
      }
      // Final fallback to UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Stream<DateTime> getTimeStream() {
    return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  String formatCountdown(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
