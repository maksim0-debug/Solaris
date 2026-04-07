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
  String get celestialMapSubtitle => 'Hold LMB on the map to set your location';

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
  String get eventZenithStart => 'Zenith Start';

  @override
  String get eventZenithEnd => 'Zenith End';

  @override
  String get eventSolarNoon => 'Solar Noon';

  @override
  String get eventGoldenHourEnd => 'Golden Hour End';

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
  String remainingUntilSleep(String time) {
    return '$time until sleep';
  }

  @override
  String get remainingUntilWakeUp => 'Until wake-up';

  @override
  String circadianImpactWithStatus(String feature, int impact, String status) {
    return '$feature $impact% brightness ($status)';
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
  String appVersion(String version) {
    return 'Solaris Version $version';
  }

  @override
  String get allMonitors => 'All Monitors';

  @override
  String get luminosityProfile => 'Luminosity Profile';

  @override
  String get sunPosition => 'Sun Position';

  @override
  String get liveLocation => 'Live Location';

  @override
  String get solarTelemetry => 'Solar Telemetry';

  @override
  String get civilTwilight => 'Civil Twilight';

  @override
  String get astronomicalNight => 'Astronomical Night';

  @override
  String get windSpeed => 'Wind Speed';

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
  String get settingsSubtitle =>
      'Configure your circadian rhythm parameters. Hold the left mouse button to drag and drop presets, or use the right mouse button to rename or delete them.';

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
  String get weatherIntensity => 'Weather Sensitivity Intensity';

  @override
  String get weatherAdjustmentIntensitySubtitle =>
      'Controls how strongly local weather affects your screen';

  @override
  String get weatherProvider => 'Weather Provider';

  @override
  String get weatherProviderAuto => 'Automatic';

  @override
  String get weatherProviderWeatherApi => 'WeatherAPI.com';

  @override
  String get weatherProviderOpenMeteo => 'Open-Meteo.com';

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

  @override
  String get sleepData => 'Sleep Data';

  @override
  String get sleepDataSubtitle =>
      'Sync with Google Fit to track your rest cycles';

  @override
  String get connectGoogleFit => 'Connect Google Fit';

  @override
  String get disconnectGoogleFit => 'Disconnect';

  @override
  String get googleFitConnected => 'Connected to Google Fit';

  @override
  String get googleFitDisconnected => 'Not Connected';

  @override
  String get lastSyncSuccess => 'Last sync successful';

  @override
  String get lastSyncFailed => 'Last sync failed';

  @override
  String get testSync => 'Test Sync';

  @override
  String get sleep => 'Sleep (Beta)';

  @override
  String get circadianRegulationBetaNote =>
      'This feature is currently in beta testing. Stable performance is not guaranteed.';

  @override
  String get sleepSubtitle => 'Analyze your sleep regimes and sync data';

  @override
  String get googleFitSync => 'Google Fit Sync';

  @override
  String get connectedStatusSmall => 'Connected';

  @override
  String get lastFetchLabel => 'Last fetch:';

  @override
  String get never => 'Never';

  @override
  String get signOut => 'Sign Out';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing...';

  @override
  String get verifyingConnection => 'Verifying connection...';

  @override
  String get connectionError => 'Connection error';

  @override
  String get hoursAbbreviation => 'h';

  @override
  String get minutesAbbreviation => 'm';

  @override
  String get sleepRegime => 'Sleep Regime';

  @override
  String get scatter => 'Scatter';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get sleepInDate => 'Sleep-in date';

  @override
  String get detectedRegimes => 'Detected Regimes';

  @override
  String get currentRegime => 'Current Regime';

  @override
  String get outdated => 'Outdated';

  @override
  String get smartCircadianTitle => 'Smart Circadian Adjustment';

  @override
  String get smartCircadianSubtitle =>
      'Dynamic correction based on Google Fit sleep data (wind-down, bio-morning, sleep debt)';

  @override
  String get circadianRegulation => 'Circadian Regulation (Beta)';

  @override
  String get featureWindDown => 'Wind-down Phase';

  @override
  String get featureWindDownSubtitle =>
      'Smooth brightness reduction and warming before sleep';

  @override
  String get featureTimeShift => 'Bio-Morning (Dynamic Anchor)';

  @override
  String get featureTimeShiftSubtitle =>
      'Shifts the schedule based on actual wake time';

  @override
  String get featureSleepPressure => 'Sleep Pressure (Wake Time)';

  @override
  String get featureSleepPressureSubtitle =>
      'Gradual dimming after long periods of wakefulness';

  @override
  String get featureSleepDebt => 'Sleep Debt Compensation';

  @override
  String get featureSleepDebtSubtitle =>
      'Reduces load after short sleep (< 6.5h)';

  @override
  String get influenceBrightness => 'Brightness';

  @override
  String get influenceTemperature => 'Temperature';

  @override
  String get featureWindDownInfo =>
      'Prepares your body for sleep by gradually reducing blue light and overall luminosity. This stimulates melatonin production and makes it easier to fall asleep.';

  @override
  String get featureTimeShiftInfo =>
      'Adapts the circadian schedule to your actual wake-up time. If you wake up earlier or later than usual, the system will smoothly shift brightness and temperature peaks to sync with your current state.';

  @override
  String get featureSleepPressureInfo =>
      'Accounts for time spent awake. If you stay awake for too long, the system starts to gently dim the screen to reduce cognitive load and signal your body it\'s time to rest.';

  @override
  String get featureSleepDebtInfo =>
      'Activates if your last sleep was shorter than 6.5 hours. During the day, the system will maintain a more comfortable, muted lighting mode to reduce strain on tired eyes and the nervous system.';

  @override
  String get intensity => 'Intensity';

  @override
  String get strength => 'Strength';

  @override
  String get brightnessIntensity => 'Brightness Intensity';

  @override
  String get temperatureIntensity => 'Temperature Intensity';

  @override
  String get shiftStrength => 'Shift Strength';

  @override
  String circadianImpact(String feature, int impact) {
    return '$feature $impact% brightness';
  }

  @override
  String get featureWindDownShort => 'Wind-down';

  @override
  String get featureTimeShiftShort => 'Bio-Morning';

  @override
  String get featureSleepPressureShort => 'Sleep Pressure';

  @override
  String get featureSleepDebtShort => 'Sleep Debt';

  @override
  String circadianImpactWithTime(
    String feature,
    int impact,
    int time,
    String unit,
  ) {
    return '$feature $impact% brightness ($time$unit)';
  }

  @override
  String get windDownDuration => 'Wind-down Duration';

  @override
  String get timeShiftDuration => 'Bio-Morning Adaptation';

  @override
  String get sleepPressureLimit => 'Wakefulness Limit';

  @override
  String get sleepDebtThreshold => 'Sleep Target (Debt threshold)';

  @override
  String get smartExclusions => 'Smart Exclusions';

  @override
  String get smartExclusionsSubtitle => 'Automatic brightness lock for games';

  @override
  String get enableGameMode => 'Enable Game Mode';

  @override
  String get enableGameModeSubtitle =>
      'Lock brightness when a game is detected';

  @override
  String get lockedBrightness => 'Locked Brightness';

  @override
  String get whitelist => 'Whitelist';

  @override
  String get whitelistSubtitle => 'Apps that always trigger game mode';

  @override
  String get blacklist => 'Blacklist';

  @override
  String get blacklistSubtitle => 'Ignore even if fullscreen';

  @override
  String get sunBase => 'Sun Base';

  @override
  String get finalValue => 'Final';

  @override
  String get brightnessReceipt => 'Brightness Receipt';

  @override
  String get sleepAnalysisSettings => 'Sleep Analysis Settings';

  @override
  String get toleranceWindow => 'Window of allowable deviations';

  @override
  String get toleranceWindowDesc =>
      'How much the sleep onset time can deviate from the \'anchor\' value before it\'s counted as an anomaly.';

  @override
  String get maxAnomalies => 'Maximum anomalies';

  @override
  String get maxAnomaliesDesc =>
      'Number of consecutive \'anomalous\' days allowed by the algorithm before the current regime is broken.';

  @override
  String get minRegimeLength => 'Minimum number of days';

  @override
  String get minRegimeLengthDesc =>
      'Minimum duration of a regime for it not to be merged with a neighbor.';

  @override
  String get anchorSize => 'Anchor window size';

  @override
  String get anchorSizeDesc =>
      'Number of first days for forming the anchor average value.';

  @override
  String get maxSpread => 'Maximum regime spread';

  @override
  String get maxSpreadDesc =>
      'Maximum difference (max - min) in the sleep onset graph in minutes. If exceeded, the regime is split.';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get russian => 'Russian';

  @override
  String get ukrainian => 'Ukrainian';

  @override
  String get globalHotkeys => 'Global Hotkeys';

  @override
  String get globalHotkeysSubtitle =>
      'Control presets and brightness from any application';

  @override
  String get nextPreset => 'Next Preset';

  @override
  String get prevPreset => 'Previous Preset';

  @override
  String get increaseBrightness => 'Increase Brightness';

  @override
  String get decreaseBrightness => 'Decrease Brightness';

  @override
  String get brightnessStep => 'Brightness Adjustment Step';

  @override
  String get brightnessStepUp => 'Step (Increase)';

  @override
  String get brightnessStepDown => 'Step (Decrease)';

  @override
  String get pressToRecord => 'Press keys to record...';

  @override
  String get hotkeyRecording => 'Recording...';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get toggleAutoBrightness => 'Toggle Auto-brightness';

  @override
  String get savePreset => 'Save Preset';

  @override
  String get presetName => 'Preset Name';

  @override
  String get namePresetHint => 'Enter name...';

  @override
  String get deletePreset => 'Delete Preset';

  @override
  String get deletePresetConfirm =>
      'Are you sure you want to delete this preset?';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String errorWithMsg(String msg) {
    return 'Error: $msg';
  }

  @override
  String sunAzimuthFormat(String value) {
    return '$value°';
  }

  @override
  String sunElevationFormat(String value) {
    return '$value°';
  }

  @override
  String sunZenithFormat(String value) {
    return '$value°';
  }

  @override
  String timeFormat(String hour, String minute) {
    return '$hour:$minute';
  }

  @override
  String percentFormat(String value) {
    return '$value%';
  }

  @override
  String temperatureFormat(String value) {
    return '$value°C';
  }

  @override
  String windSpeedFormat(String value) {
    return '$value km/h';
  }

  @override
  String spectralIntensityValue(String value) {
    return '$value W/m²';
  }

  @override
  String uvIndexValue(String value) {
    return '$value';
  }

  @override
  String latLonFormat(String lat, String lon) {
    return 'Lat: $lat, Lon: $lon';
  }

  @override
  String get detectingLocation => 'Detecting location...';

  @override
  String get coordinatesUnavailable => 'Coordinates unavailable';

  @override
  String get north => 'N';

  @override
  String get south => 'S';

  @override
  String get east => 'E';

  @override
  String get west => 'W';

  @override
  String dmsFormat(
    int latDeg,
    int latMin,
    int latSec,
    String latDir,
    int lonDeg,
    int lonMin,
    int lonSec,
    String lonDir,
  ) {
    return '$latDeg° $latMin\' $latSec\" $latDir, $lonDeg° $lonMin\' $lonSec\" $lonDir';
  }

  @override
  String chartDegreesFormat(int value) {
    return '$value°';
  }

  @override
  String chartTemperatureFormat(int value) {
    return '${value}K';
  }

  @override
  String chartPercentFormat(int value) {
    return '$value%';
  }

  @override
  String get currentPosition => 'Current Position';

  @override
  String lockedBrightnessValue(int value) {
    return '$value%';
  }

  @override
  String get gameModeHint => 'e.g. game.exe';

  @override
  String get about => 'About';

  @override
  String get legal => 'Legal Information';

  @override
  String get legalSubtitle => 'Legal & Privacy';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle =>
      'Read about how we handle your data and Google Fit integration.';

  @override
  String get disclaimerTitle => 'Disclaimer';

  @override
  String get disclaimerText =>
      'DISCLAIMER: This software is provided \'AS IS\', WITHOUT WARRANTY OF ANY KIND, express or implied, including but not limited to the warranties of merchantability and fitness for a particular purpose. The developer shall not be liable for any hardware failures, firmware issues, or physical discomfort resulting from the use of this software. By using Solaris, you acknowledge that you do so at your own risk and assume full responsibility for equipment compatibility. In no event shall the author be liable for any special, incidental, or consequential damages.';

  @override
  String get viewLicenses => 'View Licenses';

  @override
  String get close => 'Close';

  @override
  String get multiMonitorOffsets => 'Multi-monitor Offsets';

  @override
  String get multiMonitorOffsetsSubtitle =>
      'Adjust individual monitor brightness relative to global level';

  @override
  String get brightnessOffset => 'Brightness Offset';

  @override
  String get linkAndOffset => 'Link & Offset';

  @override
  String get offsetFormula => 'Final = Global + Offset';

  @override
  String get weatherAnimations => 'Weather Animations';

  @override
  String get showRain => 'Show Rain';

  @override
  String get showSnow => 'Show Snow';

  @override
  String get showThunder => 'Show Thunderstorm';

  @override
  String get showClouds => 'Show Clouds';

  @override
  String get weatherSettingsSubtitle => 'Customize animation visibility';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String lastUpdatedFormat(String time) {
    return 'Updated $time';
  }

  @override
  String get mapSettings => 'Map Settings';

  @override
  String get mapStyle => 'Map Style';

  @override
  String get mapStyleAuto => 'Automatic';

  @override
  String get mapStyleDay => 'Day';

  @override
  String get mapStyleNight => 'Night';

  @override
  String get searchPlaceholder =>
      'Search settings (e.g. \'brightness\', \'sleep\', \'hotkeys\')...';

  @override
  String noResultsFound(String query) {
    return 'No results found for \'$query\'';
  }

  @override
  String get tags_brightness =>
      'light, dark, glow, sun, backlight, screen, brightness, dim, bright, monitor, display, panel, level';

  @override
  String get tags_auto_brightness =>
      'automatic, adaptive, sensor, solar, schedule, auto, brightness, dynamic, link, sync, synchronization';

  @override
  String get tags_auto_temperature =>
      'color, warm, blue light, filter, night, evening, kelvin, temperature, auto, night shift, k, spectrum';

  @override
  String get tags_schedule =>
      'graph, sun path, cycle, morning, day, evening, night, chart, schedule, curve, plot, profile, daily';

  @override
  String get tags_sleep =>
      'google fit, rest, wake up, rhythm, sleep, analysis, data, google, fit, alarm, regime';

  @override
  String get tags_smart_circadian =>
      'smart, adaptive, biological, dynamic, sleep pressure, wind down, bio morning, sleep debt, beta, experimental, adjustment';

  @override
  String get tags_wind_down =>
      'melatonin, evening, pre-sleep, calm, dimming, warm, red, wind down, prepare';

  @override
  String get tags_game_mode =>
      'gaming, fullscreen, priority, lock, performance, exclude, game, app';

  @override
  String get tags_circadian_limits =>
      'min, max, range, boundaries, limit, brightness, range, constraints, curve, anchor, points';

  @override
  String get tags_autorun => 'boot, startup, windows, launch, autorun, startup';

  @override
  String get tags_weather =>
      'rain, cloud, sun, storm, snow, visibility, weather, reduction, atmosphere, clarity';

  @override
  String get tags_hotkeys =>
      'shortcut, keys, keyboard, command, fast, hotkeys, binding, global, shortcut';

  @override
  String get tags_language =>
      'lang, english, russian, ukrainian, dialect, translation, language, locale';

  @override
  String get tags_location =>
      'gps, map, coordinates, city, geo, position, location, latitude, longitude';

  @override
  String get tags_location_auto =>
      'gps, detect, ip, geo, auto, detect, position, automatic';

  @override
  String get tags_multi_monitor =>
      'display, screen, multi, link, offset, separate, individual, monitor';

  @override
  String get tags_weather_animations =>
      'animation, visual, rain, snow, thunder, effect, clouds, toggle, map';

  @override
  String get tags_sleep_analysis =>
      'threshold, anomalies, average, regime, spread, analysis, sleep, settings';

  @override
  String get tags_legal =>
      'legal, license, disclaimer, hardware, liability, info, about';

  @override
  String get mapIssueDetected => 'Map Issue Detected';

  @override
  String get mapboxTokenMissing => 'Mapbox access token is missing or invalid.';

  @override
  String get noInternetAccess =>
      'Could not reach Mapbox servers. Please check your internet connection.';

  @override
  String get vcRedistMissing =>
      'Visual C++ Redistributable (msvcp140.dll) is missing. This is required for maps to render correctly.';

  @override
  String get downloadVcRedist => 'Download Visual C++ Redistributable';

  @override
  String get retryDiagnostics => 'Retry Diagnosis';

  @override
  String get mapboxServers => 'Mapbox Servers';

  @override
  String get mapboxReachabilityDesc => 'Mapbox servers are unreachable.';

  @override
  String get sslIssueHint =>
      'This looks like a certificate issue. Clean Windows 10 installations often lack modern root certificates. Try running Windows Update or manual update.';

  @override
  String get missingRedistHint =>
      'Visual C++ components are missing. These are not pre-installed on clean Windows. Please install the package.';

  @override
  String get fixSslCert => 'Fix SSL Certificate';

  @override
  String get sslFixInstruction =>
      'To fix this, we need to trigger a Root Certificate update in Windows. Clicking the button below will open a secure link in your browser - simply visiting it often forces Windows to fetch the missing certificate.';

  @override
  String get trayOpen => 'Open Solaris';

  @override
  String get trayExit => 'Exit';
}
