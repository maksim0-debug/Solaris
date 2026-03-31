/// Represents the current phase of the day based on solar position.
enum CurrentDayPhase {
  /// Middle of the night.
  deepNight,

  /// Dawn (civil twilight before sunrise).
  dawn,

  /// Morning rise (dawn to sunrise).
  morningSpike,

  /// Full daylight / Zenith.
  zenith,

  /// Golden hour (morning and evening).
  goldenHour,

  /// Twilight (civil twilight).
  twilight,
}

/// Specific solar transition points for the "Next Event" indicator.
enum SolarEventType {
  civilTwilightBegin,
  sunrise,
  goldenHourMorning,
  goldenHourMorningEnd,
  zenithStart,
  solarNoon,
  zenithEnd,
  goldenHourEvening,
  goldenHourEveningEnd,
  sunset,
  civilTwilightEnd,
}
