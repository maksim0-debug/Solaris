final _trailingZeros = RegExp(r'\.?0+$');

/// Keeps brightness values and contributions consistent across explanations.
String formatBrightnessValue(num value, {bool signed = false}) {
  if (value.abs() < 0.005) return '0';
  final text = value.toStringAsFixed(2).replaceFirst(_trailingZeros, '');
  return signed && value > 0 ? '+$text' : text;
}
