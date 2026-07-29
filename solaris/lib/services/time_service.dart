import 'dart:async';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class TimeService {
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    String timeZoneName = 'Etc/UTC';
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = tzInfo is String ? tzInfo : (tzInfo.identifier as String);
    } catch (_) {
      // Default to UTC if we can't get local timezone
    }

    final location = _resolveLocation(timeZoneName);
    tz.setLocalLocation(location);
  }

  static String formatTimezoneDisplayName(tz.Location location) {
    final name = location.name;
    if (name.startsWith('Etc/GMT') || name.startsWith('Etc/UTC')) {
      final offset = tz.TZDateTime.now(location).timeZoneOffset;
      final hours = offset.inHours;
      final minutes = (offset.inMinutes % 60).abs();
      final sign = hours >= 0 ? '+' : '-';
      final hStr = hours.abs().toString().padLeft(2, '0');
      final mStr = minutes.toString().padLeft(2, '0');
      return 'UTC$sign$hStr:$mStr';
    }
    return name;
  }

  static tz.Location _resolveLocation(String rawTzName) {
    // 1. Direct IANA lookup
    if (rawTzName == 'UTC' || rawTzName == 'Etc/UTC') {
      return tz.UTC;
    }
    try {
      return tz.getLocation(rawTzName);
    } catch (_) {}

    if (rawTzName == 'Europe/Kiev') {
      try {
        return tz.getLocation('Europe/Kyiv');
      } catch (_) {}
    }

    // 2. Windows Time Zone Name to IANA Mapping
    final windowsToIana = <String, String>{
      'UTC-12': 'Etc/GMT+12',
      'UTC-11': 'Etc/GMT+11',
      'UTC-10': 'Etc/GMT+10',
      'UTC-09': 'Etc/GMT+9',
      'UTC-08': 'Etc/GMT+8',
      'UTC-07': 'Etc/GMT+7',
      'UTC-06': 'Etc/GMT+6',
      'UTC-05': 'Etc/GMT+5',
      'UTC-04': 'Etc/GMT+4',
      'UTC-03': 'Etc/GMT+3',
      'UTC-02': 'Etc/GMT+2',
      'UTC-01': 'Etc/GMT+1',
      'UTC+01': 'Etc/GMT-1',
      'UTC+02': 'Etc/GMT-2',
      'UTC+03': 'Etc/GMT-3',
      'UTC+04': 'Etc/GMT-4',
      'UTC+05': 'Etc/GMT-5',
      'UTC+06': 'Etc/GMT-6',
      'UTC+07': 'Etc/GMT-7',
      'UTC+08': 'Etc/GMT-8',
      'UTC+09': 'Etc/GMT-9',
      'UTC+10': 'Etc/GMT-10',
      'UTC+11': 'Etc/GMT-11',
      'UTC+12': 'Etc/GMT-12',
      'Dateline Standard Time': 'Etc/GMT+12',
      'UTC-11 Standard Time': 'Etc/GMT+11',
      'Hawaiian Standard Time': 'Pacific/Honolulu',
      'Alaskan Standard Time': 'America/Anchorage',
      'Pacific Standard Time': 'America/Los_Angeles',
      'Mountain Standard Time': 'America/Denver',
      'Central Standard Time': 'America/Chicago',
      'Eastern Standard Time': 'America/New_York',
      'US Eastern Standard Time': 'America/Indianapolis',
      'Nepal Standard Time': 'Asia/Kathmandu',
      'N. Central Asia Standard Time': 'Asia/Almaty',
      'FLE Standard Time': 'Europe/Kyiv',
      'GTB Standard Time': 'Europe/Bucharest',
      'GMT Standard Time': 'Europe/London',
      'Greenwich Standard Time': 'Atlantic/Reykjavik',
      'W. Europe Standard Time': 'Europe/Berlin',
      'Romance Standard Time': 'Europe/Paris',
      'Central Europe Standard Time': 'Europe/Warsaw',
      'E. Europe Standard Time': 'Europe/Chisinau',
      'Tokyo Standard Time': 'Asia/Tokyo',
      'China Standard Time': 'Asia/Shanghai',
      'India Standard Time': 'Asia/Kolkata',
      'Singapore Standard Time': 'Asia/Singapore',
      'SE Asia Standard Time': 'Asia/Bangkok',
      'Arab Standard Time': 'Asia/Riyadh',
      'Arabian Standard Time': 'Asia/Dubai',
      'Iran Standard Time': 'Asia/Tehran',
      'AUS Eastern Standard Time': 'Australia/Sydney',
      'AUS Central Standard Time': 'Australia/Darwin',
      'Cen. Australia Standard Time': 'Australia/Adelaide',
      'E. South America Standard Time': 'America/Sao_Paulo',
      'Argentina Standard Time': 'America/Buenos_Aires',
      'Egypt Standard Time': 'Africa/Cairo',
      'South Africa Standard Time': 'Africa/Johannesburg',
    };

    final mappedName = windowsToIana[rawTzName];
    if (mappedName != null) {
      try {
        return tz.getLocation(mappedName);
      } catch (_) {}
    }

    // 3. Match IANA location by system UTC offset
    final now = DateTime.now();
    final systemOffset = now.timeZoneOffset;

    for (final loc in tz.timeZoneDatabase.locations.values) {
      final tzNow = tz.TZDateTime.now(loc);
      if (tzNow.timeZoneOffset == systemOffset) {
        return loc;
      }
    }

    // 4. Final fallback to UTC
    return tz.UTC;
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
