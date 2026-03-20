import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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

  /// No description provided for @engineVersion.
  ///
  /// In en, this message translates to:
  /// **'Solaris Engine v{version}'**
  String engineVersion(String version);

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

  /// No description provided for @dragNodesToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Drag nodes to adjust transition curves'**
  String get dragNodesToAdjust;

  /// No description provided for @view24h.
  ///
  /// In en, this message translates to:
  /// **'24h View'**
  String get view24h;

  /// No description provided for @editCurve.
  ///
  /// In en, this message translates to:
  /// **'Edit Curve'**
  String get editCurve;

  /// No description provided for @liveLocation.
  ///
  /// In en, this message translates to:
  /// **'LIVE LOCATION'**
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
      <String>['en', 'ru'].contains(locale.languageCode);

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
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
