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
  String get autoDetectSubtitle =>
      'Automatically detect location via system services or IP';

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
    return 'System will transition to warm spectrum in approximately $hours hours.';
  }

  @override
  String get goldenHourNotice =>
      'System is currently in Golden Hour. Soft warm spectrum is active.';

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
      'Night cycle. Gentle backlighting protects your eyes in the dark.';

  @override
  String get descDeepNightManual =>
      'Deep night. Auto-regulation is resting, waiting for the first rays of dawn.';

  @override
  String get descDawnAuto =>
      'Dawn is breaking. The screen is gently waking up and transitioning to day mode.';

  @override
  String get descDawnManual =>
      'The sky is brightening. You are controlling the brightness manually while waiting for sunrise.';

  @override
  String get descMorningSpikeAuto =>
      'First rays of sun. Brightness is gradually rising to help you wake up.';

  @override
  String get descMorningSpikeManual =>
      'Pre-dawn rise. Manual brightness control is active.';

  @override
  String get descZenithAuto =>
      'Sun is at its zenith. Optimal brightness is set for daytime work.';

  @override
  String get descZenithManual =>
      'Middle of the day. Auto-adjust is disabled, brightness set manually.';

  @override
  String get descGoldenHourMorningBothAuto =>
      'Morning golden hour. Soft warm light and brightness are adjusted for a gentle start to your day.';

  @override
  String get descGoldenHourMorningTempOnly =>
      'Morning golden hour. The screen is shifted to a warm spectrum for your eyes\' comfort.';

  @override
  String get descGoldenHourMorningBrightOnly =>
      'Morning golden hour. Brightness adapts to the soft light of early morning.';

  @override
  String get descGoldenHourMorningManual =>
      'Morning golden hour. Auto-regulation is resting, parameters are set manually.';

  @override
  String get descGoldenHourEveningBothAuto =>
      'Evening golden hour. Soft warm light and brightness are adjusted for a cozy evening.';

  @override
  String get descGoldenHourEveningTempOnly =>
      'Evening golden hour. The screen transitions to a warm spectrum, reducing strain before sleep.';

  @override
  String get descGoldenHourEveningBrightOnly =>
      'Evening golden hour. Brightness gradually decreases to match the setting sun.';

  @override
  String get descGoldenHourEveningManual =>
      'Evening golden hour. Auto-regulation is resting, parameters are set manually.';

  @override
  String get descTwilightAuto =>
      'Twilight is gathering. The screen is smoothly transitioning to a cozy night mode.';

  @override
  String get descTwilightManual =>
      'It\'s twilight. Auto-adjust is disabled, brightness set manually.';

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
  String get startupMode => 'Startup Mode';

  @override
  String get startupModeTray => 'Tray';

  @override
  String get startupModeMinimized => 'Minimized';

  @override
  String get weatherAdjustmentTitle => 'Weather-based Adjustment';

  @override
  String get weatherAdjustmentSubtitle =>
      'Automatic screen adjustment based on local weather conditions';

  @override
  String get weatherBrightnessAdjustmentTitle =>
      'Weather Brightness Adjustment';

  @override
  String get weatherBrightnessAdjustmentSubtitle =>
      'Reduce brightness in cloudy or rainy weather for eye comfort';

  @override
  String get weatherTemperatureAdjustmentTitle =>
      'Weather Temperature Adjustment';

  @override
  String get weatherTemperatureAdjustmentSubtitle =>
      'Reduce color temperature in cloudy or rainy weather to ease eye strain';

  @override
  String get temperatureRegulationTitle => 'Temperature Regulation';

  @override
  String get temperatureBreakdownBase => 'Base curve temperature';

  @override
  String get temperatureBreakdownWeather => 'Weather (reduction)';

  @override
  String get temperatureBreakdownSleepPressure => 'Sleep Pressure';

  @override
  String get temperatureBreakdownWindDown => 'Wind-down Phase';

  @override
  String get temperatureBreakdownSleepDebt => 'Sleep Debt Compensation';

  @override
  String get temperatureBreakdownFinal => 'Final Temperature';

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
  String get circadianRegulation => 'Brightness Regulation';

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
      'Prepares your body for sleep by gradually reducing blue light and overall luminosity. This helps maintain natural melatonin levels and makes it easier to fall asleep.';

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
  String get sunBase => 'Base curve brightness';

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
  String get offlineReasonMissingToken =>
      'Mapbox API token is not configured. Falling back to timezone name.';

  @override
  String get offlineReasonApiError =>
      'Failed to fetch city name from API. Falling back to timezone name.';

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
      'DISCLAIMER: This software is provided \'AS IS\', WITHOUT WARRANTY OF ANY KIND, express or implied, including but not limited to the warranties of merchantability and fitness for a particular purpose. Under no circumstances shall the author or developer be liable for any hardware failures, firmware issues, physical discomfort, data loss, security breaches, unauthorized access, or leakage of custom API keys and credentials. By using Solaris, you acknowledge that you do so at your own sole risk and assume full responsibility for equipment compatibility, storage of keys, and any financial liabilities, costs, or expenses incurred as a result of key leakage, API quota overuses, or system compromise. In no event shall the author be liable for any special, incidental, direct, indirect, or consequential damages.';

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
  String get tags_google_fit =>
      'google fit, cloud, sync, account, authorize, oauth, google, fit, sleep tracker, rest, data';

  @override
  String get tags_time_shift =>
      'bio morning, bio-morning, wake up, shift, schedule, dynamic, anchor, awake, circadian';

  @override
  String get tags_sleep_pressure =>
      'sleep pressure, dimming, wake time, duration, limit, hours, fatigue, tiredness';

  @override
  String get tags_sleep_debt =>
      'sleep debt, compensation, short sleep, rest deficit, recovery, muted mode, eyes strain';

  @override
  String get tags_local_sleep_integration =>
      'local sleep integration, ipc server, http server, api, localhost, port, sleep sync';

  @override
  String get tags_weather_brightness =>
      'weather brightness, overcast, clouds, rain, storm, sun, light adjustment';

  @override
  String get tags_weather_temperature =>
      'weather temperature, warm, cool, blue light, overcast, storm, color adjustment';

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

  @override
  String get sleepIntegrationTitle => 'Sleep Integration (Local API)';

  @override
  String get sleepIntegrationSubtitle =>
      'Connection with external sleep trackers and APIs';

  @override
  String get enableLocalIpcServer => 'Enable local API server';

  @override
  String get enableLocalIpcServerSubtitle =>
      'Allows receiving sleep sessions on localhost port';

  @override
  String get serverPort => 'Server Port';

  @override
  String get serverPortSubtitle =>
      'Server will restart automatically when changed';

  @override
  String serverRunningStatus(int port) {
    return 'Server is running on port $port';
  }

  @override
  String get serverStoppedStatus => 'Server stopped or port in use';

  @override
  String serverPortBusyAlertTitle(int port) {
    return 'Port $port is busy or unavailable';
  }

  @override
  String serverPortBusyAlertExplanation(int port) {
    return 'Solaris could not start the local API server because port $port is currently in use by another application or service on your computer.';
  }

  @override
  String serverPortBusyAlertSolution(Object port) {
    return 'To resolve this, you can enter a different port number in the field above (e.g., 45322), or close the application that is using port $port.';
  }

  @override
  String get sleepIntegrationHelpTitle => 'Sleep Integration Guide';

  @override
  String get sleepIntegrationHelpIntro =>
      'This integration allows third-party desktop sleep trackers, smart alarms, or automation scripts to send sleep data directly to this app over a secure local network connection.';

  @override
  String get sleepIntegrationHelpSectionWhat => 'What is it?';

  @override
  String get sleepIntegrationHelpSectionWhatText =>
      'Solaris can adjust your monitor\'s brightness and color temperature dynamically based on your circadian rhythm. To do this, it needs accurate sleep data. While Google Fit provides cloud sync, this local API server allows immediate, offline synchronization from apps running on your PC.';

  @override
  String get sleepIntegrationHelpSectionHow => 'How it works';

  @override
  String get sleepIntegrationHelpSectionHowText =>
      '1. When enabled, the app starts a mini HTTP web server on your computer, listening only to local requests (127.0.0.1).\n2. External apps send sleep sessions (JSON format) or real-time status (sleeping / awake) to the server.\n3. The app automatically merges this data and applies it to adjust your screen settings.';

  @override
  String get sleepIntegrationHelpSectionConfig => 'How to configure';

  @override
  String get sleepIntegrationHelpSectionConfigText =>
      '• Toggle \'Enable local API server\' on.\n• Keep the default port (45321) unless it is used by another application.\n• Configure your tracking software to send POST requests to:\n  - History: http://127.0.0.1:45321/api/sleep/sessions\n  - Real-time: http://127.0.0.1:45321/api/sleep/status';

  @override
  String get sleepIntegrationHelpSectionDeduplication => 'Data Deduplication';

  @override
  String get sleepIntegrationHelpSectionDeduplicationText =>
      'Local data has absolute priority. If a sleep session synced via Google Fit overlaps with a local API session (with a 1-hour safety buffer), the Google Fit session is automatically discarded to prevent double-logging and conflicts.';

  @override
  String get sleepIntegrationHelpSectionSecurity => 'Security & Privacy';

  @override
  String get sleepIntegrationHelpSectionSecurityText =>
      'The server runs strictly on the local loopback address (127.0.0.1) and is inaccessible from the internet or other network devices. Your sleep data remains entirely on your machine.';

  @override
  String get sleepIntegrationHelpSectionFormat => 'JSON Data Formats';

  @override
  String get sleepIntegrationHelpSectionFormatText =>
      'Solaris expects strict JSON payloads. Schema details:\n\n1. Sleep Sessions (POST to /api/sleep/sessions)\nExpected payload: A JSON array of sleep session objects.\nEach session object contains:\n• id: string (unique session identifier)\n• startTime: string (ISO 8601 date, e.g., \"2026-07-17T00:30:00Z\")\n• endTime: string (ISO 8601 date, e.g., \"2026-07-17T08:00:00Z\")\n• title: string (optional session name)\n• source: string (optional, \"local_api\" is default)\n\n2. Real-time sleep status (POST to /api/sleep/status)\nExpected payload: A JSON object containing:\n• is_sleeping: boolean (true if user is sleeping, false if awake)';

  @override
  String get mapboxTokenMissingTooltip =>
      'Mapbox access token is missing. Configure it in Settings (API Keys section).';

  @override
  String get weatherApiKeyMissingWarning =>
      'WeatherAPI provider is disabled. Configure WEATHER_API_KEY in Settings (API Keys section).';

  @override
  String get googleFitKeysMissingWarning =>
      'Google Fit integration is disabled. Configure GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in Settings (API Keys section).';

  @override
  String get apiKeysTitle => 'API Keys';

  @override
  String get apiKeysSubtitle =>
      'Configure custom API keys for external services';

  @override
  String get customWeatherApiKey => 'Custom WeatherAPI Key';

  @override
  String get customMapboxToken => 'Custom Mapbox Token';

  @override
  String get customGoogleClientId => 'Custom Google Client ID';

  @override
  String get customGoogleClientSecret => 'Custom Google Client Secret';

  @override
  String get apiKeysHelpText =>
      'This version of Solaris is built without pre-embedded API keys. To use Mapbox maps, WeatherAPI forecast, or Google Fit sync, please specify your custom keys here. They will be obfuscated and stored locally on your PC.';

  @override
  String get apiKeysHelpTextWithDefaults =>
      'This version of Solaris is built with pre-embedded default keys. If desired, you can override any of them by specifying your custom keys here. They will be obfuscated and stored locally on your PC.';

  @override
  String get apiKeysGetKeyLink => 'Get key';

  @override
  String get googleFitReleaseWarningTitle => 'GitHub Release Build';

  @override
  String get googleFitReleaseWarningBody =>
      'This official release downloaded from GitHub does not contain a built-in Google Client ID and Client Secret due to Google\'s stringent security policies regarding health data (Restricted Scopes). Public applications are prohibited from accessing sleep history without undergoing an extensive and costly independent security audit.\n\nTo enable synchronization:\n1. Input your custom Google Client ID and Client Secret in the settings card under \'API Keys\'.\n2. Alternatively, build the app from source with your own keys in your `.env` file.';

  @override
  String get googleFitLocalWarningTitle => 'Google Fit Keys Missing';

  @override
  String get googleFitLocalWarningBody =>
      'Google Fit integration requires Google OAuth credentials.\n\nTo enable synchronization:\n1. Input your custom Google Client ID and Client Secret in the settings card under \'API Keys\'.\n2. Alternatively, configure your local `.env` file and rebuild the application.';

  @override
  String get goToSettings => 'Go to settings';

  @override
  String get apiKeyActiveBuiltIn => 'Built-in active';

  @override
  String get apiKeyActiveCustom => 'Custom active';

  @override
  String get apiKeyNotConfigured => 'Key not configured';

  @override
  String get saveKey => 'Save';

  @override
  String get clearKey => 'Clear';

  @override
  String get saved => 'Saved';

  @override
  String get dpapiErrorTitle => 'Security Storage Alert';

  @override
  String get dpapiErrorPasswordChanged =>
      'Your Windows account credentials or password were changed. For security reasons, we could not decrypt your saved API keys. Please re-enter them in Settings.';

  @override
  String get dpapiErrorInvalidData =>
      'The saved settings security data is corrupted. Please re-enter your API keys.';

  @override
  String get dpapiErrorGeneric =>
      'A Windows security subsystem error occurred while decrypting your settings. Please re-enter your API keys.';

  @override
  String get dpapiErrorActionOk => 'OK';

  @override
  String get dpapiErrorActionSettings => 'Go to Settings';

  @override
  String get invalidCoordinatesError =>
      'Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180.';

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateAvailableVersion(Object version) => 'Update: v$version ⬆';

  @override
  String updateDownloadingPercent(Object percent) => 'Downloading: $percent% ↓';

  @override
  String get updateVerifying => 'Verifying integrity...';

  @override
  String get updateVerified => 'Verified';

  @override
  String get updateIntegrityError => 'Integrity error';

  @override
  String get updateReady => 'Ready to install ✓';

  @override
  String get updateInstallRestart => 'Install & Restart';

  @override
  String get updateLater => 'Later';

  @override
  String get updateRetry => 'Retry';

  @override
  String get updateError => 'Update error ⚠';

  @override
  String get updateReleaseNotes => 'Release Notes';

  @override
  String updateFileSize(Object size) => 'File size: $size';

  @override
  String get updateRestartWarning =>
      'Application will restart to apply the update.';

  @override
  String get updateCheckForUpdates => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates...';

  @override
  String get updateSuccessTitle => 'Application Updated';

  @override
  String updateSuccessBody(Object version) =>
      'Solaris has been successfully updated to version $version.';

  @override
  String get updateRolledBackTitle => 'Update Rolled Back';

  @override
  String updateRolledBackBody(Object reason) =>
      'Update failed. Application was restored to the previous version.\nReason: $reason';

  @override
  String get updateFailedTitle => 'Update Error';

  @override
  String updateFailedBody(Object reason) =>
      'An error occurred while applying the update.\nDetails: $reason';
}
