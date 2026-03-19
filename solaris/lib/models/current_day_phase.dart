/// Represents the current phase of the day based on solar position.
enum CurrentDayPhase {
  /// Middle of the night.
  deepNight,

  /// Morning rise (dawn to sunrise).
  morningSpike,

  /// Full daylight / Zenith.
  zenith,

  /// Golden hour (morning and evening).
  goldenHour,

  /// Twilight (civil twilight).
  twilight,
}
