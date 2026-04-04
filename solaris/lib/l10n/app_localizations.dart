import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uk'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Solaris'**
  String get appTitle;

  /// No description provided for @celestialControl.
  ///
  /// In en, this message translates to:
  /// **'CELESTIAL CONTROL'**
  String get celestialControl;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationAutomation.
  ///
  /// In en, this message translates to:
  /// **'Location & Automation'**
  String get locationAutomation;

  /// No description provided for @locationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your environment with your geographical position. Let the solar cycles dictate your workflow fluidity.'**
  String get locationSubtitle;

  /// No description provided for @celestialMap.
  ///
  /// In en, this message translates to:
  /// **'Celestial Map'**
  String get celestialMap;

  /// No description provided for @celestialMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold LMB on the map to set your location'**
  String get celestialMapSubtitle;

  /// No description provided for @autoDetect.
  ///
  /// In en, this message translates to:
  /// **'AUTO-DETECT: {status}'**
  String autoDetect(String status);

  /// No description provided for @manualCoordinateEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Coordinate Entry'**
  String get manualCoordinateEntry;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'LATITUDE'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'LONGITUDE'**
  String get longitude;

  /// No description provided for @updatePosition.
  ///
  /// In en, this message translates to:
  /// **'Update Position'**
  String get updatePosition;

  /// No description provided for @precisionGps.
  ///
  /// In en, this message translates to:
  /// **'Precision GPS'**
  String get precisionGps;

  /// No description provided for @gpsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High-precision location services for solar-tracking hardware integration.'**
  String get gpsSubtitle;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Status: Connected'**
  String get statusConnected;

  /// No description provided for @currentAnchor.
  ///
  /// In en, this message translates to:
  /// **'CURRENT ANCHOR'**
  String get currentAnchor;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @localTime.
  ///
  /// In en, this message translates to:
  /// **'LOCAL TIME'**
  String get localTime;

  /// No description provided for @goldenHour.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour'**
  String get goldenHour;

  /// No description provided for @goldenHourMorning.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour (Morning)'**
  String get goldenHourMorning;

  /// No description provided for @goldenHourEvening.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour (Evening)'**
  String get goldenHourEvening;

  /// No description provided for @eventZenithStart.
  ///
  /// In en, this message translates to:
  /// **'Zenith Start'**
  String get eventZenithStart;

  /// No description provided for @eventZenithEnd.
  ///
  /// In en, this message translates to:
  /// **'Zenith End'**
  String get eventZenithEnd;

  /// No description provided for @eventSolarNoon.
  ///
  /// In en, this message translates to:
  /// **'Solar Noon'**
  String get eventSolarNoon;

  /// No description provided for @eventGoldenHourEnd.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour End'**
  String get eventGoldenHourEnd;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'CALCULATING...'**
  String get calculating;

  /// No description provided for @comingIn.
  ///
  /// In en, this message translates to:
  /// **'COMING IN {time}'**
  String comingIn(String time);

  /// No description provided for @goldenHourActive.
  ///
  /// In en, this message translates to:
  /// **'GOLDEN HOUR ACTIVE'**
  String get goldenHourActive;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'{time} REMAINING'**
  String remaining(String time);

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'NIGHT'**
  String get night;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get finished;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'BRIGHTNESS'**
  String get brightness;

  /// No description provided for @remainingLower.
  ///
  /// In en, this message translates to:
  /// **'{time} Remaining'**
  String remainingLower(String time);

  /// No description provided for @remainingUntilSleep.
  ///
  /// In en, this message translates to:
  /// **'{time} until sleep'**
  String remainingUntilSleep(String time);

  /// Text shown during the rest period when the timer is no longer needed
  ///
  /// In en, this message translates to:
  /// **'Until wake-up'**
  String get remainingUntilWakeUp;

  /// No description provided for @circadianImpactWithStatus.
  ///
  /// In en, this message translates to:
  /// **'{feature} {impact}% brightness ({status})'**
  String circadianImpactWithStatus(String feature, int impact, String status);

  /// No description provided for @activeLower.
  ///
  /// In en, this message translates to:
  /// **'{time} Active'**
  String activeLower(String time);

  /// No description provided for @sunSet.
  ///
  /// In en, this message translates to:
  /// **'Sun set'**
  String get sunSet;

  /// No description provided for @calculatingLower.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculatingLower;

  /// No description provided for @transitionNotice.
  ///
  /// In en, this message translates to:
  /// **'System will transition to warm spectrum 2700K in approximately {hours} hours.'**
  String transitionNotice(int hours);

  /// No description provided for @goldenHourNotice.
  ///
  /// In en, this message translates to:
  /// **'System is currently in Golden Hour. Spectrum is shifted to warm 2700K.'**
  String get goldenHourNotice;

  /// No description provided for @solarCycleEnded.
  ///
  /// In en, this message translates to:
  /// **'Solar cycle for today has ended. System is in manual night mode.'**
  String get solarCycleEnded;

  /// No description provided for @updatingSolarData.
  ///
  /// In en, this message translates to:
  /// **'Updating solar data based on your location...'**
  String get updatingSolarData;

  /// No description provided for @autoAdapt.
  ///
  /// In en, this message translates to:
  /// **'Auto-Adapt'**
  String get autoAdapt;

  /// No description provided for @autoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Auto Brightness'**
  String get autoBrightness;

  /// No description provided for @autoTemperature.
  ///
  /// In en, this message translates to:
  /// **'Auto Temperature'**
  String get autoTemperature;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @nightShift.
  ///
  /// In en, this message translates to:
  /// **'Night Shift'**
  String get nightShift;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @statusAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Control'**
  String get statusAdaptive;

  /// No description provided for @statusManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Mode'**
  String get statusManual;

  /// No description provided for @phaseDeepNight.
  ///
  /// In en, this message translates to:
  /// **'DEEP NIGHT'**
  String get phaseDeepNight;

  /// No description provided for @phaseDawn.
  ///
  /// In en, this message translates to:
  /// **'DAWN'**
  String get phaseDawn;

  /// No description provided for @phaseMorningSpike.
  ///
  /// In en, this message translates to:
  /// **'MORNING SPIKE'**
  String get phaseMorningSpike;

  /// No description provided for @phaseZenith.
  ///
  /// In en, this message translates to:
  /// **'ZENITH'**
  String get phaseZenith;

  /// No description provided for @phaseGoldenHour.
  ///
  /// In en, this message translates to:
  /// **'GOLDEN HOUR'**
  String get phaseGoldenHour;

  /// No description provided for @phaseTwilight.
  ///
  /// In en, this message translates to:
  /// **'TWILIGHT'**
  String get phaseTwilight;

  /// No description provided for @descDeepNightAuto.
  ///
  /// In en, this message translates to:
  /// **'Night cycle. Adaptive control maintains minimum brightness.'**
  String get descDeepNightAuto;

  /// No description provided for @descDeepNightManual.
  ///
  /// In en, this message translates to:
  /// **'Deep night. System is in manual mode waiting for sunrise.'**
  String get descDeepNightManual;

  /// No description provided for @descDawnAuto.
  ///
  /// In en, this message translates to:
  /// **'Civil twilight. Smooth transition to day mode.'**
  String get descDawnAuto;

  /// No description provided for @descDawnManual.
  ///
  /// In en, this message translates to:
  /// **'Dawn. System is in manual mode waiting for sunrise.'**
  String get descDawnManual;

  /// No description provided for @descMorningSpikeAuto.
  ///
  /// In en, this message translates to:
  /// **'Pre-dawn spike. Brightness is gradually rising towards sunrise.'**
  String get descMorningSpikeAuto;

  /// No description provided for @descMorningSpikeManual.
  ///
  /// In en, this message translates to:
  /// **'Pre-dawn rise. Manual brightness control is active.'**
  String get descMorningSpikeManual;

  /// No description provided for @descZenithAuto.
  ///
  /// In en, this message translates to:
  /// **'Zenith. Maximum light efficiency according to schedule.'**
  String get descZenithAuto;

  /// No description provided for @descZenithManual.
  ///
  /// In en, this message translates to:
  /// **'Full day. You are using manual brightness settings.'**
  String get descZenithManual;

  /// No description provided for @descGoldenHourAuto.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour. Spectrum shifted to warm 2700K for comfort.'**
  String get descGoldenHourAuto;

  /// No description provided for @descGoldenHourManual.
  ///
  /// In en, this message translates to:
  /// **'Golden Hour. Color correction is currently paused.'**
  String get descGoldenHourManual;

  /// No description provided for @descTwilightAuto.
  ///
  /// In en, this message translates to:
  /// **'Civil Twilight. Smooth transition to night mode.'**
  String get descTwilightAuto;

  /// No description provided for @descTwilightManual.
  ///
  /// In en, this message translates to:
  /// **'Twilight. System is in manual mode with reduced intensity.'**
  String get descTwilightManual;

  /// No description provided for @panelTemperature.
  ///
  /// In en, this message translates to:
  /// **'Panel Temperature'**
  String get panelTemperature;

  /// No description provided for @efficiencyRate.
  ///
  /// In en, this message translates to:
  /// **'Efficiency Rate'**
  String get efficiencyRate;

  /// No description provided for @atmosphericClarity.
  ///
  /// In en, this message translates to:
  /// **'Atmospheric Clarity'**
  String get atmosphericClarity;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @sunriseLabel.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunriseLabel;

  /// No description provided for @sunsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunsetLabel;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Solaris Version {version}'**
  String appVersion(String version);

  /// No description provided for @allMonitors.
  ///
  /// In en, this message translates to:
  /// **'All Monitors'**
  String get allMonitors;

  /// No description provided for @luminosityProfile.
  ///
  /// In en, this message translates to:
  /// **'Luminosity Profile'**
  String get luminosityProfile;

  /// No description provided for @sunPosition.
  ///
  /// In en, this message translates to:
  /// **'Sun Position'**
  String get sunPosition;

  /// No description provided for @liveLocation.
  ///
  /// In en, this message translates to:
  /// **'Live Location'**
  String get liveLocation;

  /// No description provided for @solarTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Solar Telemetry'**
  String get solarTelemetry;

  /// No description provided for @civilTwilight.
  ///
  /// In en, this message translates to:
  /// **'Civil Twilight'**
  String get civilTwilight;

  /// No description provided for @astronomicalNight.
  ///
  /// In en, this message translates to:
  /// **'Astronomical Night'**
  String get astronomicalNight;

  /// No description provided for @surfaceTemp.
  ///
  /// In en, this message translates to:
  /// **'Surface Temp'**
  String get surfaceTemp;

  /// No description provided for @spectralIntensity.
  ///
  /// In en, this message translates to:
  /// **'Spectral Intensity'**
  String get spectralIntensity;

  /// No description provided for @uvIndex.
  ///
  /// In en, this message translates to:
  /// **'UV Index'**
  String get uvIndex;

  /// No description provided for @extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get extreme;

  /// No description provided for @azimuth.
  ///
  /// In en, this message translates to:
  /// **'AZIMUTH'**
  String get azimuth;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'ELEVATION'**
  String get elevation;

  /// No description provided for @zenith.
  ///
  /// In en, this message translates to:
  /// **'ZENITH'**
  String get zenith;

  /// No description provided for @constant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get constant;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @airTemp.
  ///
  /// In en, this message translates to:
  /// **'Air Temp'**
  String get airTemp;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your circadian rhythm parameters'**
  String get settingsSubtitle;

  /// No description provided for @circadianLimits.
  ///
  /// In en, this message translates to:
  /// **'Circadian Limits'**
  String get circadianLimits;

  /// No description provided for @circadianLimitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Define the boundaries for auto-brightness'**
  String get circadianLimitsSubtitle;

  /// No description provided for @minBrightness.
  ///
  /// In en, this message translates to:
  /// **'Minimum Brightness'**
  String get minBrightness;

  /// No description provided for @minBrightnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The lowest brightness level during the night'**
  String get minBrightnessSubtitle;

  /// No description provided for @maxBrightness.
  ///
  /// In en, this message translates to:
  /// **'Maximum Brightness'**
  String get maxBrightness;

  /// No description provided for @maxBrightnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The peak brightness reached during solar zenith'**
  String get maxBrightnessSubtitle;

  /// No description provided for @transBrightness.
  ///
  /// In en, this message translates to:
  /// **'Transition Brightness'**
  String get transBrightness;

  /// No description provided for @transBrightnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The target level during Golden Hour and Civil Twilight transitions'**
  String get transBrightnessSubtitle;

  /// No description provided for @realtimeApplyNotice.
  ///
  /// In en, this message translates to:
  /// **'Changes are applied in real-time. Use the dashboard to toggle between manual and automatic adjustment.'**
  String get realtimeApplyNotice;

  /// No description provided for @autorun.
  ///
  /// In en, this message translates to:
  /// **'Autorun at Startup'**
  String get autorun;

  /// No description provided for @autorunSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically start the application when you log into Windows'**
  String get autorunSubtitle;

  /// No description provided for @weatherAdjustmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather-based Adjustment'**
  String get weatherAdjustmentTitle;

  /// No description provided for @weatherAdjustmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce brightness in cloudy or rainy weather'**
  String get weatherAdjustmentSubtitle;

  /// No description provided for @weatherBrightnessReduction.
  ///
  /// In en, this message translates to:
  /// **'Weather: brightness reduced by {percent}%'**
  String weatherBrightnessReduction(int percent);

  /// No description provided for @selectMonitor.
  ///
  /// In en, this message translates to:
  /// **'Select Monitor'**
  String get selectMonitor;

  /// No description provided for @presetBrightest.
  ///
  /// In en, this message translates to:
  /// **'Brightest'**
  String get presetBrightest;

  /// No description provided for @presetBright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get presetBright;

  /// No description provided for @presetDim.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get presetDim;

  /// No description provided for @presetDimmest.
  ///
  /// In en, this message translates to:
  /// **'Dimmest'**
  String get presetDimmest;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get presetCustom;

  /// No description provided for @tempCoolest.
  ///
  /// In en, this message translates to:
  /// **'Coolest'**
  String get tempCoolest;

  /// No description provided for @tempCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get tempCool;

  /// No description provided for @tempWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get tempWarm;

  /// No description provided for @tempWarmest.
  ///
  /// In en, this message translates to:
  /// **'Warmest'**
  String get tempWarmest;

  /// No description provided for @tempCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get tempCustom;

  /// No description provided for @blueLightFilter.
  ///
  /// In en, this message translates to:
  /// **'Color Temperature (Blue Light Filter)'**
  String get blueLightFilter;

  /// No description provided for @blueLightFilterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically warm screen colors at night to reduce eye strain'**
  String get blueLightFilterSubtitle;

  /// No description provided for @chartModeBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get chartModeBrightness;

  /// No description provided for @chartModeTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get chartModeTemperature;

  /// No description provided for @disabledInSettings.
  ///
  /// In en, this message translates to:
  /// **'Disabled in settings'**
  String get disabledInSettings;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @sleepData.
  ///
  /// In en, this message translates to:
  /// **'Sleep Data'**
  String get sleepData;

  /// No description provided for @sleepDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync with Google Fit to track your rest cycles'**
  String get sleepDataSubtitle;

  /// No description provided for @connectGoogleFit.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Fit'**
  String get connectGoogleFit;

  /// No description provided for @disconnectGoogleFit.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectGoogleFit;

  /// No description provided for @googleFitConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to Google Fit'**
  String get googleFitConnected;

  /// No description provided for @googleFitDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get googleFitDisconnected;

  /// No description provided for @lastSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last sync successful'**
  String get lastSyncSuccess;

  /// No description provided for @lastSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Last sync failed'**
  String get lastSyncFailed;

  /// No description provided for @testSync.
  ///
  /// In en, this message translates to:
  /// **'Test Sync'**
  String get testSync;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep (Beta)'**
  String get sleep;

  /// No description provided for @circadianRegulationBetaNote.
  ///
  /// In en, this message translates to:
  /// **'This feature is currently in beta testing. Stable performance is not guaranteed.'**
  String get circadianRegulationBetaNote;

  /// No description provided for @sleepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze your sleep regimes and sync data'**
  String get sleepSubtitle;

  /// No description provided for @googleFitSync.
  ///
  /// In en, this message translates to:
  /// **'Google Fit Sync'**
  String get googleFitSync;

  /// No description provided for @connectedStatusSmall.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedStatusSmall;

  /// No description provided for @lastFetchLabel.
  ///
  /// In en, this message translates to:
  /// **'Last fetch:'**
  String get lastFetchLabel;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @verifyingConnection.
  ///
  /// In en, this message translates to:
  /// **'Verifying connection...'**
  String get verifyingConnection;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @hoursAbbreviation.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hoursAbbreviation;

  /// No description provided for @minutesAbbreviation.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minutesAbbreviation;

  /// No description provided for @sleepRegime.
  ///
  /// In en, this message translates to:
  /// **'Sleep Regime'**
  String get sleepRegime;

  /// No description provided for @scatter.
  ///
  /// In en, this message translates to:
  /// **'Scatter'**
  String get scatter;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @sleepInDate.
  ///
  /// In en, this message translates to:
  /// **'Sleep-in date'**
  String get sleepInDate;

  /// No description provided for @detectedRegimes.
  ///
  /// In en, this message translates to:
  /// **'Detected Regimes'**
  String get detectedRegimes;

  /// No description provided for @currentRegime.
  ///
  /// In en, this message translates to:
  /// **'Current Regime'**
  String get currentRegime;

  /// No description provided for @outdated.
  ///
  /// In en, this message translates to:
  /// **'Outdated'**
  String get outdated;

  /// No description provided for @smartCircadianTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Circadian Adjustment'**
  String get smartCircadianTitle;

  /// No description provided for @smartCircadianSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamic correction based on Google Fit sleep data (wind-down, bio-morning, sleep debt)'**
  String get smartCircadianSubtitle;

  /// No description provided for @circadianRegulation.
  ///
  /// In en, this message translates to:
  /// **'Circadian Regulation (Beta)'**
  String get circadianRegulation;

  /// No description provided for @featureWindDown.
  ///
  /// In en, this message translates to:
  /// **'Wind-down Phase'**
  String get featureWindDown;

  /// No description provided for @featureWindDownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smooth brightness reduction and warming before sleep'**
  String get featureWindDownSubtitle;

  /// No description provided for @featureTimeShift.
  ///
  /// In en, this message translates to:
  /// **'Bio-Morning (Dynamic Anchor)'**
  String get featureTimeShift;

  /// No description provided for @featureTimeShiftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shifts the schedule based on actual wake time'**
  String get featureTimeShiftSubtitle;

  /// No description provided for @featureSleepPressure.
  ///
  /// In en, this message translates to:
  /// **'Sleep Pressure (Wake Time)'**
  String get featureSleepPressure;

  /// No description provided for @featureSleepPressureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gradual dimming after long periods of wakefulness'**
  String get featureSleepPressureSubtitle;

  /// No description provided for @featureSleepDebt.
  ///
  /// In en, this message translates to:
  /// **'Sleep Debt Compensation'**
  String get featureSleepDebt;

  /// No description provided for @featureSleepDebtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduces load after short sleep (< 6.5h)'**
  String get featureSleepDebtSubtitle;

  /// No description provided for @influenceBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get influenceBrightness;

  /// No description provided for @influenceTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get influenceTemperature;

  /// No description provided for @featureWindDownInfo.
  ///
  /// In en, this message translates to:
  /// **'Prepares your body for sleep by gradually reducing blue light and overall luminosity. This stimulates melatonin production and makes it easier to fall asleep.'**
  String get featureWindDownInfo;

  /// No description provided for @featureTimeShiftInfo.
  ///
  /// In en, this message translates to:
  /// **'Adapts the circadian schedule to your actual wake-up time. If you wake up earlier or later than usual, the system will smoothly shift brightness and temperature peaks to sync with your current state.'**
  String get featureTimeShiftInfo;

  /// No description provided for @featureSleepPressureInfo.
  ///
  /// In en, this message translates to:
  /// **'Accounts for time spent awake. If you stay awake for too long, the system starts to gently dim the screen to reduce cognitive load and signal your body it\'s time to rest.'**
  String get featureSleepPressureInfo;

  /// No description provided for @featureSleepDebtInfo.
  ///
  /// In en, this message translates to:
  /// **'Activates if your last sleep was shorter than 6.5 hours. During the day, the system will maintain a more comfortable, muted lighting mode to reduce strain on tired eyes and the nervous system.'**
  String get featureSleepDebtInfo;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @brightnessIntensity.
  ///
  /// In en, this message translates to:
  /// **'Brightness Intensity'**
  String get brightnessIntensity;

  /// No description provided for @temperatureIntensity.
  ///
  /// In en, this message translates to:
  /// **'Temperature Intensity'**
  String get temperatureIntensity;

  /// No description provided for @shiftStrength.
  ///
  /// In en, this message translates to:
  /// **'Shift Strength'**
  String get shiftStrength;

  /// No description provided for @circadianImpact.
  ///
  /// In en, this message translates to:
  /// **'{feature} {impact}% brightness'**
  String circadianImpact(String feature, int impact);

  /// No description provided for @featureWindDownShort.
  ///
  /// In en, this message translates to:
  /// **'Wind-down'**
  String get featureWindDownShort;

  /// No description provided for @featureTimeShiftShort.
  ///
  /// In en, this message translates to:
  /// **'Bio-Morning'**
  String get featureTimeShiftShort;

  /// No description provided for @featureSleepPressureShort.
  ///
  /// In en, this message translates to:
  /// **'Sleep Pressure'**
  String get featureSleepPressureShort;

  /// No description provided for @featureSleepDebtShort.
  ///
  /// In en, this message translates to:
  /// **'Sleep Debt'**
  String get featureSleepDebtShort;

  /// No description provided for @circadianImpactWithTime.
  ///
  /// In en, this message translates to:
  /// **'{feature} {impact}% brightness ({time}{unit})'**
  String circadianImpactWithTime(
    String feature,
    int impact,
    int time,
    String unit,
  );

  /// No description provided for @windDownDuration.
  ///
  /// In en, this message translates to:
  /// **'Wind-down Duration'**
  String get windDownDuration;

  /// No description provided for @timeShiftDuration.
  ///
  /// In en, this message translates to:
  /// **'Bio-Morning Adaptation'**
  String get timeShiftDuration;

  /// No description provided for @sleepPressureLimit.
  ///
  /// In en, this message translates to:
  /// **'Wakefulness Limit'**
  String get sleepPressureLimit;

  /// No description provided for @sleepDebtThreshold.
  ///
  /// In en, this message translates to:
  /// **'Sleep Target (Debt threshold)'**
  String get sleepDebtThreshold;

  /// No description provided for @smartExclusions.
  ///
  /// In en, this message translates to:
  /// **'Smart Exclusions'**
  String get smartExclusions;

  /// No description provided for @smartExclusionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic brightness lock for games'**
  String get smartExclusionsSubtitle;

  /// No description provided for @enableGameMode.
  ///
  /// In en, this message translates to:
  /// **'Enable Game Mode'**
  String get enableGameMode;

  /// No description provided for @enableGameModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock brightness when a game is detected'**
  String get enableGameModeSubtitle;

  /// No description provided for @lockedBrightness.
  ///
  /// In en, this message translates to:
  /// **'Locked Brightness'**
  String get lockedBrightness;

  /// No description provided for @whitelist.
  ///
  /// In en, this message translates to:
  /// **'Whitelist'**
  String get whitelist;

  /// No description provided for @whitelistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apps that always trigger game mode'**
  String get whitelistSubtitle;

  /// No description provided for @blacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get blacklist;

  /// No description provided for @blacklistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore even if fullscreen'**
  String get blacklistSubtitle;

  /// No description provided for @sunBase.
  ///
  /// In en, this message translates to:
  /// **'Sun Base'**
  String get sunBase;

  /// No description provided for @finalValue.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get finalValue;

  /// No description provided for @brightnessReceipt.
  ///
  /// In en, this message translates to:
  /// **'Brightness Receipt'**
  String get brightnessReceipt;

  /// No description provided for @sleepAnalysisSettings.
  ///
  /// In en, this message translates to:
  /// **'Sleep Analysis Settings'**
  String get sleepAnalysisSettings;

  /// No description provided for @toleranceWindow.
  ///
  /// In en, this message translates to:
  /// **'Window of allowable deviations'**
  String get toleranceWindow;

  /// No description provided for @toleranceWindowDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the sleep onset time can deviate from the \'anchor\' value before it\'s counted as an anomaly.'**
  String get toleranceWindowDesc;

  /// No description provided for @maxAnomalies.
  ///
  /// In en, this message translates to:
  /// **'Maximum anomalies'**
  String get maxAnomalies;

  /// No description provided for @maxAnomaliesDesc.
  ///
  /// In en, this message translates to:
  /// **'Number of consecutive \'anomalous\' days allowed by the algorithm before the current regime is broken.'**
  String get maxAnomaliesDesc;

  /// No description provided for @minRegimeLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum number of days'**
  String get minRegimeLength;

  /// No description provided for @minRegimeLengthDesc.
  ///
  /// In en, this message translates to:
  /// **'Minimum duration of a regime for it not to be merged with a neighbor.'**
  String get minRegimeLengthDesc;

  /// No description provided for @anchorSize.
  ///
  /// In en, this message translates to:
  /// **'Anchor window size'**
  String get anchorSize;

  /// No description provided for @anchorSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Number of first days for forming the anchor average value.'**
  String get anchorSizeDesc;

  /// No description provided for @maxSpread.
  ///
  /// In en, this message translates to:
  /// **'Maximum regime spread'**
  String get maxSpread;

  /// No description provided for @maxSpreadDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum difference (max - min) in the sleep onset graph in minutes. If exceeded, the regime is split.'**
  String get maxSpreadDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @ukrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get ukrainian;

  /// No description provided for @globalHotkeys.
  ///
  /// In en, this message translates to:
  /// **'Global Hotkeys'**
  String get globalHotkeys;

  /// No description provided for @globalHotkeysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control presets and brightness from any application'**
  String get globalHotkeysSubtitle;

  /// No description provided for @nextPreset.
  ///
  /// In en, this message translates to:
  /// **'Next Preset'**
  String get nextPreset;

  /// No description provided for @prevPreset.
  ///
  /// In en, this message translates to:
  /// **'Previous Preset'**
  String get prevPreset;

  /// No description provided for @increaseBrightness.
  ///
  /// In en, this message translates to:
  /// **'Increase Brightness'**
  String get increaseBrightness;

  /// No description provided for @decreaseBrightness.
  ///
  /// In en, this message translates to:
  /// **'Decrease Brightness'**
  String get decreaseBrightness;

  /// No description provided for @brightnessStep.
  ///
  /// In en, this message translates to:
  /// **'Brightness Adjustment Step'**
  String get brightnessStep;

  /// No description provided for @brightnessStepUp.
  ///
  /// In en, this message translates to:
  /// **'Step (Increase)'**
  String get brightnessStepUp;

  /// No description provided for @brightnessStepDown.
  ///
  /// In en, this message translates to:
  /// **'Step (Decrease)'**
  String get brightnessStepDown;

  /// No description provided for @pressToRecord.
  ///
  /// In en, this message translates to:
  /// **'Press keys to record...'**
  String get pressToRecord;

  /// No description provided for @hotkeyRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get hotkeyRecording;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @toggleAutoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Toggle Auto-brightness'**
  String get toggleAutoBrightness;

  /// No description provided for @savePreset.
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get savePreset;

  /// No description provided for @presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get presetName;

  /// No description provided for @namePresetHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name...'**
  String get namePresetHint;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get deletePreset;

  /// No description provided for @deletePresetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this preset?'**
  String get deletePresetConfirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @errorWithMsg.
  ///
  /// In en, this message translates to:
  /// **'Error: {msg}'**
  String errorWithMsg(String msg);

  /// No description provided for @sunAzimuthFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String sunAzimuthFormat(String value);

  /// No description provided for @sunElevationFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String sunElevationFormat(String value);

  /// No description provided for @sunZenithFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String sunZenithFormat(String value);

  /// No description provided for @timeFormat.
  ///
  /// In en, this message translates to:
  /// **'{hour}:{minute}'**
  String timeFormat(String hour, String minute);

  /// No description provided for @percentFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentFormat(String value);

  /// No description provided for @temperatureFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}°C'**
  String temperatureFormat(String value);

  /// No description provided for @spectralIntensityValue.
  ///
  /// In en, this message translates to:
  /// **'{value} W/m²'**
  String spectralIntensityValue(String value);

  /// No description provided for @uvIndexValue.
  ///
  /// In en, this message translates to:
  /// **'{value}'**
  String uvIndexValue(String value);

  /// No description provided for @latLonFormat.
  ///
  /// In en, this message translates to:
  /// **'Lat: {lat}, Lon: {lon}'**
  String latLonFormat(String lat, String lon);

  /// No description provided for @detectingLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting location...'**
  String get detectingLocation;

  /// No description provided for @coordinatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Coordinates unavailable'**
  String get coordinatesUnavailable;

  /// No description provided for @north.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get north;

  /// No description provided for @south.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get south;

  /// No description provided for @east.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get east;

  /// No description provided for @west.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get west;

  /// No description provided for @dmsFormat.
  ///
  /// In en, this message translates to:
  /// **'{latDeg}° {latMin}\' {latSec}\" {latDir}, {lonDeg}° {lonMin}\' {lonSec}\" {lonDir}'**
  String dmsFormat(
    int latDeg,
    int latMin,
    int latSec,
    String latDir,
    int lonDeg,
    int lonMin,
    int lonSec,
    String lonDir,
  );

  /// No description provided for @chartDegreesFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String chartDegreesFormat(int value);

  /// No description provided for @chartTemperatureFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}K'**
  String chartTemperatureFormat(int value);

  /// No description provided for @chartPercentFormat.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String chartPercentFormat(int value);

  /// No description provided for @currentPosition.
  ///
  /// In en, this message translates to:
  /// **'Current Position'**
  String get currentPosition;

  /// No description provided for @lockedBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String lockedBrightnessValue(int value);

  /// No description provided for @gameModeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. game.exe'**
  String get gameModeHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal Information'**
  String get legal;

  /// No description provided for @legalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Legal & Privacy'**
  String get legalSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read about how we handle your data and Google Fit integration.'**
  String get privacyPolicySubtitle;

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerText.
  ///
  /// In en, this message translates to:
  /// **'DISCLAIMER: This software is provided \'AS IS\', WITHOUT WARRANTY OF ANY KIND, express or implied, including but not limited to the warranties of merchantability and fitness for a particular purpose. The developer shall not be liable for any hardware failures, firmware issues, or physical discomfort resulting from the use of this software. By using Solaris, you acknowledge that you do so at your own risk and assume full responsibility for equipment compatibility. In no event shall the author be liable for any special, incidental, or consequential damages.'**
  String get disclaimerText;

  /// No description provided for @viewLicenses.
  ///
  /// In en, this message translates to:
  /// **'View Licenses'**
  String get viewLicenses;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @multiMonitorOffsets.
  ///
  /// In en, this message translates to:
  /// **'Multi-monitor Offsets'**
  String get multiMonitorOffsets;

  /// No description provided for @multiMonitorOffsetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust individual monitor brightness relative to global level'**
  String get multiMonitorOffsetsSubtitle;

  /// No description provided for @brightnessOffset.
  ///
  /// In en, this message translates to:
  /// **'Brightness Offset'**
  String get brightnessOffset;

  /// No description provided for @linkAndOffset.
  ///
  /// In en, this message translates to:
  /// **'Link & Offset'**
  String get linkAndOffset;

  /// No description provided for @offsetFormula.
  ///
  /// In en, this message translates to:
  /// **'Final = Global + Offset'**
  String get offsetFormula;

  /// No description provided for @weatherAnimations.
  ///
  /// In en, this message translates to:
  /// **'Weather Animations'**
  String get weatherAnimations;

  /// No description provided for @showRain.
  ///
  /// In en, this message translates to:
  /// **'Show Rain'**
  String get showRain;

  /// No description provided for @showSnow.
  ///
  /// In en, this message translates to:
  /// **'Show Snow'**
  String get showSnow;

  /// No description provided for @showThunder.
  ///
  /// In en, this message translates to:
  /// **'Show Thunderstorm'**
  String get showThunder;

  /// No description provided for @showClouds.
  ///
  /// In en, this message translates to:
  /// **'Show Clouds'**
  String get showClouds;

  /// No description provided for @weatherSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize animation visibility'**
  String get weatherSettingsSubtitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search settings (e.g. \'brightness\', \'sleep\', \'hotkeys\')...'**
  String get searchPlaceholder;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found for \'{query}\''**
  String noResultsFound(String query);

  /// No description provided for @tags_brightness.
  ///
  /// In en, this message translates to:
  /// **'light, dark, glow, sun, backlight, screen, brightness, dim, bright, monitor, display, panel, level'**
  String get tags_brightness;

  /// No description provided for @tags_auto_brightness.
  ///
  /// In en, this message translates to:
  /// **'automatic, adaptive, sensor, solar, schedule, auto, brightness, dynamic, link, sync, synchronization'**
  String get tags_auto_brightness;

  /// No description provided for @tags_auto_temperature.
  ///
  /// In en, this message translates to:
  /// **'color, warm, blue light, filter, night, evening, kelvin, temperature, auto, night shift, k, spectrum'**
  String get tags_auto_temperature;

  /// No description provided for @tags_schedule.
  ///
  /// In en, this message translates to:
  /// **'graph, sun path, cycle, morning, day, evening, night, chart, schedule, curve, plot, profile, daily'**
  String get tags_schedule;

  /// No description provided for @tags_sleep.
  ///
  /// In en, this message translates to:
  /// **'google fit, rest, wake up, rhythm, sleep, analysis, data, google, fit, alarm, regime'**
  String get tags_sleep;

  /// No description provided for @tags_smart_circadian.
  ///
  /// In en, this message translates to:
  /// **'smart, adaptive, biological, dynamic, sleep pressure, wind down, bio morning, sleep debt, beta, experimental, adjustment'**
  String get tags_smart_circadian;

  /// No description provided for @tags_wind_down.
  ///
  /// In en, this message translates to:
  /// **'melatonin, evening, pre-sleep, calm, dimming, warm, red, wind down, prepare'**
  String get tags_wind_down;

  /// No description provided for @tags_game_mode.
  ///
  /// In en, this message translates to:
  /// **'gaming, fullscreen, priority, lock, performance, exclude, game, app'**
  String get tags_game_mode;

  /// No description provided for @tags_circadian_limits.
  ///
  /// In en, this message translates to:
  /// **'min, max, range, boundaries, limit, brightness, range, constraints, curve, anchor, points'**
  String get tags_circadian_limits;

  /// No description provided for @tags_autorun.
  ///
  /// In en, this message translates to:
  /// **'boot, startup, windows, launch, autorun, startup'**
  String get tags_autorun;

  /// No description provided for @tags_weather.
  ///
  /// In en, this message translates to:
  /// **'rain, cloud, sun, storm, snow, visibility, weather, reduction, atmosphere, clarity'**
  String get tags_weather;

  /// No description provided for @tags_hotkeys.
  ///
  /// In en, this message translates to:
  /// **'shortcut, keys, keyboard, command, fast, hotkeys, binding, global, shortcut'**
  String get tags_hotkeys;

  /// No description provided for @tags_language.
  ///
  /// In en, this message translates to:
  /// **'lang, english, russian, ukrainian, dialect, translation, language, locale'**
  String get tags_language;

  /// No description provided for @tags_location.
  ///
  /// In en, this message translates to:
  /// **'gps, map, coordinates, city, geo, position, location, latitude, longitude'**
  String get tags_location;

  /// No description provided for @tags_location_auto.
  ///
  /// In en, this message translates to:
  /// **'gps, detect, ip, geo, auto, detect, position, automatic'**
  String get tags_location_auto;

  /// No description provided for @tags_multi_monitor.
  ///
  /// In en, this message translates to:
  /// **'display, screen, multi, link, offset, separate, individual, monitor'**
  String get tags_multi_monitor;

  /// No description provided for @tags_weather_animations.
  ///
  /// In en, this message translates to:
  /// **'animation, visual, rain, snow, thunder, effect, clouds, toggle, map'**
  String get tags_weather_animations;

  /// No description provided for @tags_sleep_analysis.
  ///
  /// In en, this message translates to:
  /// **'threshold, anomalies, average, regime, spread, analysis, sleep, settings'**
  String get tags_sleep_analysis;

  /// No description provided for @tags_legal.
  ///
  /// In en, this message translates to:
  /// **'legal, license, disclaimer, hardware, liability, info, about'**
  String get tags_legal;

  /// No description provided for @mapIssueDetected.
  ///
  /// In en, this message translates to:
  /// **'Map Issue Detected'**
  String get mapIssueDetected;

  /// No description provided for @mapboxTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'Mapbox access token is missing or invalid.'**
  String get mapboxTokenMissing;

  /// No description provided for @noInternetAccess.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Mapbox servers. Please check your internet connection.'**
  String get noInternetAccess;

  /// No description provided for @vcRedistMissing.
  ///
  /// In en, this message translates to:
  /// **'Visual C++ Redistributable (msvcp140.dll) is missing. This is required for maps to render correctly.'**
  String get vcRedistMissing;

  /// No description provided for @downloadVcRedist.
  ///
  /// In en, this message translates to:
  /// **'Download Visual C++ Redistributable'**
  String get downloadVcRedist;

  /// No description provided for @retryDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Retry Diagnosis'**
  String get retryDiagnostics;

  /// No description provided for @mapboxServers.
  ///
  /// In en, this message translates to:
  /// **'Mapbox Servers'**
  String get mapboxServers;

  /// No description provided for @mapboxReachabilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Mapbox servers are unreachable.'**
  String get mapboxReachabilityDesc;

  /// No description provided for @sslIssueHint.
  ///
  /// In en, this message translates to:
  /// **'This looks like a certificate issue. Clean Windows 10 installations often lack modern root certificates. Try running Windows Update or manual update.'**
  String get sslIssueHint;

  /// No description provided for @missingRedistHint.
  ///
  /// In en, this message translates to:
  /// **'Visual C++ components are missing. These are not pre-installed on clean Windows. Please install the package.'**
  String get missingRedistHint;

  /// No description provided for @fixSslCert.
  ///
  /// In en, this message translates to:
  /// **'Fix SSL Certificate'**
  String get fixSslCert;

  /// No description provided for @sslFixInstruction.
  ///
  /// In en, this message translates to:
  /// **'To fix this, we need to trigger a Root Certificate update in Windows. Clicking the button below will open a secure link in your browser - simply visiting it often forces Windows to fetch the missing certificate.'**
  String get sslFixInstruction;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Solaris'**
  String get trayOpen;

  /// No description provided for @trayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get trayExit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
