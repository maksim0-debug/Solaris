/// Represents the current phase of the day based on solar position.
enum CurrentDayPhase {
  /// Middle of the night.
  deepNight,

  /// Dawn (civil twilight before sunrise).
  dawn,

  /// Morning daylight between the golden hour and zenith.
  morningSpike,

  /// The two-hour interval around solar noon.
  zenith,

  /// Daylight after zenith and before the evening golden hour.
  day,

  /// Golden hour (morning and evening).
  goldenHour,

  /// Evening twilight until astronomical dusk.
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
  astronomicalDusk,
}
