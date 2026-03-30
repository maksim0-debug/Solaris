// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Solaris';

  @override
  String get celestialControl => 'CELESTIAL CONTROL';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get schedule => 'Schedule';

  @override
  String get settings => 'Settings';

  @override
  String get location => 'Location';

  @override
  String get locationAutomation => 'Location & Automation';

  @override
  String get locationSubtitle =>
      'Sync your environment with your geographical position. Let the solar cycles dictate your workflow fluidity.';

  @override
  String get celestialMap => 'Celestial Map';

  @override
  String autoDetect(String status) {
    return 'AUTO-DETECT: $status';
  }

  @override
  String get manualCoordinateEntry => 'Manual Coordinate Entry';

  @override
  String get latitude => 'LATITUDE';

  @override
  String get longitude => 'LONGITUDE';

  @override
  String get updatePosition => 'Update Position';

  @override
  String get precisionGps => 'Precision GPS';

  @override
  String get gpsSubtitle =>
      'High-precision location services for solar-tracking hardware integration.';

  @override
  String get statusConnected => 'Status: Connected';

  @override
  String get currentAnchor => 'CURRENT ANCHOR';

  @override
  String get reset => 'Reset';

  @override
  String get localTime => 'LOCAL TIME';

  @override
  String get goldenHour => 'Golden Hour';

  @override
  String get goldenHourMorning => 'Golden Hour (Morning)';

  @override
  String get goldenHourEvening => 'Golden Hour (Evening)';

  @override
  String get calculating => 'CALCULATING...';

  @override
  String comingIn(String time) {
    return 'COMING IN $time';
  }

  @override
  String get goldenHourActive => 'GOLDEN HOUR ACTIVE';

  @override
  String remaining(String time) {
    return '$time REMAINING';
  }

  @override
  String get night => 'NIGHT';

  @override
  String get finished => 'FINISHED';

  @override
  String get brightness => 'BRIGHTNESS';

  @override
  String remainingLower(String time) {
    return '$time Remaining';
  }

  @override
  String activeLower(String time) {
    return '$time Active';
  }

  @override
  String get sunSet => 'Sun set';

  @override
  String get calculatingLower => 'Calculating...';

  @override
  String transitionNotice(int hours) {
    return 'System will transition to warm spectrum 2700K in approximately $hours hours.';
  }

  @override
  String get goldenHourNotice =>
      'System is currently in Golden Hour. Spectrum is shifted to warm 2700K.';

  @override
  String get solarCycleEnded =>
      'Solar cycle for today has ended. System is in manual night mode.';

  @override
  String get updatingSolarData =>
      'Updating solar data based on your location...';

  @override
  String get autoAdapt => 'Auto-Adapt';

  @override
  String get autoBrightness => 'Auto Brightness';

  @override
  String get autoTemperature => 'Auto Temperature';

  @override
  String get active => 'Active';

  @override
  String get nightShift => 'Night Shift';

  @override
  String get disabled => 'Disabled';

  @override
  String get statusAdaptive => 'Adaptive Control';

  @override
  String get statusManual => 'Manual Mode';

  @override
  String get phaseDeepNight => 'DEEP NIGHT';

  @override
  String get phaseDawn => 'DAWN';

  @override
  String get phaseMorningSpike => 'MORNING SPIKE';

  @override
  String get phaseZenith => 'ZENITH';

  @override
  String get phaseGoldenHour => 'GOLDEN HOUR';

  @override
  String get phaseTwilight => 'TWILIGHT';

  @override
  String get descDeepNightAuto =>
      'Night cycle. Adaptive control maintains minimum brightness.';

  @override
  String get descDeepNightManual =>
      'Deep night. System is in manual mode waiting for sunrise.';

  @override
  String get descDawnAuto => 'Civil twilight. Smooth transition to day mode.';

  @override
  String get descDawnManual =>
      'Dawn. System is in manual mode waiting for sunrise.';

  @override
  String get descMorningSpikeAuto =>
      'Pre-dawn spike. Brightness is gradually rising towards sunrise.';

  @override
  String get descMorningSpikeManual =>
      'Pre-dawn rise. Manual brightness control is active.';

  @override
  String get descZenithAuto =>
      'Zenith. Maximum light efficiency according to schedule.';

  @override
  String get descZenithManual =>
      'Full day. You are using manual brightness settings.';

  @override
  String get descGoldenHourAuto =>
      'Golden Hour. Spectrum shifted to warm 2700K for comfort.';

  @override
  String get descGoldenHourManual =>
      'Golden Hour. Color correction is currently paused.';

  @override
  String get descTwilightAuto =>
      'Civil Twilight. Smooth transition to night mode.';

  @override
  String get descTwilightManual =>
      'Twilight. System is in manual mode with reduced intensity.';

  @override
  String get panelTemperature => 'Panel Temperature';

  @override
  String get efficiencyRate => 'Efficiency Rate';

  @override
  String get atmosphericClarity => 'Atmospheric Clarity';

  @override
  String get high => 'High';

  @override
  String get sunriseLabel => 'Sunrise';

  @override
  String get sunsetLabel => 'Sunset';

  @override
  String engineVersion(String version) {
    return 'Solaris Engine v$version';
  }

  @override
  String get allMonitors => 'All Monitors';

  @override
  String get luminosityProfile => 'Luminosity Profile';

  @override
  String get sunPosition => 'Sun Position';

  @override
  String get liveLocation => 'LIVE LOCATION';

  @override
  String get solarTelemetry => 'Solar Telemetry';

  @override
  String get civilTwilight => 'Civil Twilight';

  @override
  String get astronomicalNight => 'Astronomical Night';

  @override
  String get surfaceTemp => 'Surface Temp';

  @override
  String get spectralIntensity => 'Spectral Intensity';

  @override
  String get uvIndex => 'UV Index';

  @override
  String get extreme => 'Extreme';

  @override
  String get azimuth => 'AZIMUTH';

  @override
  String get elevation => 'ELEVATION';

  @override
  String get zenith => 'ZENITH';

  @override
  String get constant => 'Constant';

  @override
  String get humidity => 'Humidity';

  @override
  String get airTemp => 'Air Temp';

  @override
  String get settingsSubtitle => 'Configure your circadian rhythm parameters';

  @override
  String get circadianLimits => 'Circadian Limits';

  @override
  String get circadianLimitsSubtitle =>
      'Define the boundaries for auto-brightness';

  @override
  String get minBrightness => 'Minimum Brightness';

  @override
  String get minBrightnessSubtitle =>
      'The lowest brightness level during the night';

  @override
  String get maxBrightness => 'Maximum Brightness';

  @override
  String get maxBrightnessSubtitle =>
      'The peak brightness reached during solar zenith';

  @override
  String get transBrightness => 'Transition Brightness';

  @override
  String get transBrightnessSubtitle =>
      'The target level during Golden Hour and Civil Twilight transitions';

  @override
  String get realtimeApplyNotice =>
      'Changes are applied in real-time. Use the dashboard to toggle between manual and automatic adjustment.';

  @override
  String get autorun => 'Autorun at Startup';

  @override
  String get autorunSubtitle =>
      'Automatically start the application when you log into Windows';

  @override
  String get weatherAdjustmentTitle => 'Weather-based Adjustment';

  @override
  String get weatherAdjustmentSubtitle =>
      'Reduce brightness in cloudy or rainy weather';

  @override
  String weatherBrightnessReduction(int percent) {
    return 'Weather: brightness reduced by $percent%';
  }

  @override
  String get selectMonitor => 'Select Monitor';

  @override
  String get presetBrightest => 'Brightest';

  @override
  String get presetBright => 'Bright';

  @override
  String get presetDim => 'Dim';

  @override
  String get presetDimmest => 'Dimmest';

  @override
  String get presetCustom => 'Custom';

  @override
  String get tempCoolest => 'Coolest';

  @override
  String get tempCool => 'Cool';

  @override
  String get tempWarm => 'Warm';

  @override
  String get tempWarmest => 'Warmest';

  @override
  String get tempCustom => 'Custom';

  @override
  String get blueLightFilter => 'Color Temperature (Blue Light Filter)';

  @override
  String get blueLightFilterSubtitle =>
      'Automatically warm screen colors at night to reduce eye strain';

  @override
  String get chartModeBrightness => 'Brightness';

  @override
  String get chartModeTemperature => 'Temperature';

  @override
  String get disabledInSettings => 'Disabled in settings';

  @override
  String get enable => 'Enable';
}
