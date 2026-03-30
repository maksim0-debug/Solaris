class BedtimeNormalization {
  /// Converts a [DateTime]'s time to minutes from the *preceding* 12:00 PM (noon).
  /// 
  /// Noon (12:00 PM) = 0
  /// 6:00 PM = 360
  /// Midnight (12:00 AM) = 720
  /// 6:00 AM = 1080
  /// 11:59 AM = 1439
  static int minutesFromNoon(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    if (hour >= 12) {
      // From 12:00 PM to 11:59 PM
      return (hour - 12) * 60 + minute;
    } else {
      // From 12:00 AM to 11:59 AM (next calendar day)
      return (hour + 12) * 60 + minute;
    }
  }

  /// Converts "minutes from noon" back into a readable string (e.g. "23:45").
  static String minutesFromNoonToString(int totalMinutes) {
    // Normalize to 0-1439
    int normalized = totalMinutes % 1440;
    
    // Add 12 hours to shift back to midnight-based
    int hourFromMidnight = (normalized ~/ 60 + 12) % 24;
    int minute = normalized % 60;
    
    return '${hourFromMidnight.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

extension BedtimeDateTimeExtension on DateTime {
  int get minutesFromNoon => BedtimeNormalization.minutesFromNoon(this);
}
