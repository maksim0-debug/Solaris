import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/services/weather_service.dart';

final brightnessTestNoon = DateTime(2026, 10, 15, 13);

SolarPhaseModel brightnessTestPhases() {
  DateTime hour(int value) => DateTime(2026, 10, 15, value);
  return SolarPhaseModel(
    sunrise: hour(7),
    sunset: hour(18),
    goldenHourMorning: hour(6),
    goldenHourMorningEnd: hour(8),
    goldenHourEvening: hour(17),
    goldenHourEveningEnd: hour(19),
    civilTwilightBegin: hour(6),
    nextDayCivilTwilightBegin: hour(6).add(const Duration(days: 1)),
    civilTwilightEnd: hour(19),
    astronomicalDawn: hour(5),
    civilDusk: hour(19),
    solarNoon: hour(13),
    astronomicalDusk: hour(20),
  );
}

SolarState brightnessTestSolar({double elevation = 30}) => SolarState(
  phases: brightnessTestPhases(),
  currentPhase: CurrentDayPhase.zenith,
  timeUntilNextEvent: const Duration(hours: 4),
  nextEventType: SolarEventType.goldenHourEvening,
  sunElevation: elevation,
  sunAzimuth: 180,
  sunZenith: 90 - elevation,
  sunProgress: 0.5,
  uvIndex: 0,
  spectralIntensity: 0,
  azimuthTrend: '',
  elevationTrend: '',
  zenithTrend: '',
  maxElevation: 90,
  minElevation: -20,
);

WeatherData brightnessTestWeather({int code = 95}) => WeatherData(
  temperature: 18,
  humidity: 60,
  uvIndex: 4,
  directRadiation: 300,
  diffuseRadiation: 120,
  cloudCover: 95,
  windSpeed: 25,
  weatherCode: code,
  lastUpdated: brightnessTestNoon,
);
