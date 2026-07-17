import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData getWeatherIcon(int? code) {
  if (code == null) return LucideIcons.cloud;
  if (code == 0) return LucideIcons.sun;
  if (code >= 1 && code <= 2) return LucideIcons.cloudSun;
  if (code == 3) return LucideIcons.cloud;
  if (code == 45 || code == 48) return LucideIcons.cloudFog;
  if (code >= 51 && code <= 55) return LucideIcons.cloudDrizzle;
  if (code >= 56 && code <= 57) return LucideIcons.snowflake;
  if (code >= 61 && code <= 63) return LucideIcons.cloudRain;
  if (code == 65) return LucideIcons.cloudRainWind;
  if (code >= 66 && code <= 67) return LucideIcons.cloudRain;
  if (code >= 71 && code <= 77) return LucideIcons.snowflake;
  if (code >= 80 && code <= 81) return LucideIcons.cloudRain;
  if (code == 82) return LucideIcons.cloudRainWind;
  if (code >= 85 && code <= 86) return LucideIcons.snowflake;
  if (code >= 95 && code <= 99) return LucideIcons.cloudLightning;
  return LucideIcons.cloud;
}
