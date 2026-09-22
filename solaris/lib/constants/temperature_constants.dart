/// Centralized color temperature constants for the Solaris application.
abstract final class TemperatureConstants {
  /// Standard minimum color temperature in Kelvin (candlelight / ultra warm zone).
  static const int min = 1000;

  /// Standard maximum daylight color temperature in Kelvin.
  static const int max = 6500;

  /// Floating point representations for slider ranges and animations.
  static const double minDouble = 1000.0;
  static const double maxDouble = 6500.0;
}
