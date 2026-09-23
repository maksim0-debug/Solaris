class BedtimeNormalization {
  /// Converts a [DateTime]'s time to minutes from the *preceding* 12:00 PM (noon).
  ///
  /// Noon (12:00 PM) = 0
  /// 6:00 PM = 360
  /// Midnight (12:00 AM) = 720
  /// 6:00 AM = 1080
  /// 11:59 AM = 1439
  static int minutesFromNoon(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute;

    if (hour >= 12) {
      // From 12:00 PM to 11:59 PM
      return (hour - 12) * 60 + minute;
    } else {
      // From 12:00 AM to 11:59 AM (next calendar day)
      return (hour + 12) * 60 + minute;
    }
  }

  /// Decomposes "minutes from noon" into 24-hour [hour] and [minute] components.
  static ({int hour, int minute}) minutesFromNoonToHourMinute(
    int minutesFromNoon,
  ) {
    // Normalize to 0-1439 handling any negative offset
    final normalized = (minutesFromNoon % 1440 + 1440) % 1440;
    final hourFromMidnight = (normalized ~/ 60 + 12) % 24;
    final minute = normalized % 60;
    return (hour: hourFromMidnight, minute: minute);
  }

  /// Converts "minutes from noon" back into a readable string (e.g. "23:45").
  static String minutesFromNoonToString(int totalMinutes) {
    final (:hour, :minute) = minutesFromNoonToHourMinute(totalMinutes);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

extension BedtimeDateTimeExtension on DateTime {
  int get minutesFromNoon => BedtimeNormalization.minutesFromNoon(this);
}
