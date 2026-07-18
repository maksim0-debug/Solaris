// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Solaris';

  @override
  String get celestialControl => 'НЕБЕСНИЙ КОНТРОЛЬ';

  @override
  String get dashboard => 'Панель керування';

  @override
  String get schedule => 'Графік';

  @override
  String get settings => 'Налаштування';

  @override
  String get location => 'Місцезнаходження';

  @override
  String get locationAutomation => 'Місцезнаходження та автоматизація';

  @override
  String get locationSubtitle =>
      'Синхронізуйте ваше середовище з географічним положенням. Нехай сонячні цикли диктують плавність вашого робочого процесу.';

  @override
  String get celestialMap => 'Небесна карта';

  @override
  String get celestialMapSubtitle =>
      'Утримуйте ЛКМ на карті, щоб задати ваше місцезнаходження';

  @override
  String autoDetect(String status) {
    return 'АВТОМАТИЧНЕ ВИЗНАЧЕННЯ: $status';
  }

  @override
  String get manualCoordinateEntry => 'Ручне введення координат';

  @override
  String get latitude => 'ШИРОТА';

  @override
  String get longitude => 'ДОВГОТА';

  @override
  String get updatePosition => 'Оновити позицію';

  @override
  String get autoDetectSubtitle =>
      'Автоматично визначати місцеположення за системними службами або IP';

  @override
  String get currentAnchor => 'ПОТОЧНИЙ ЯКІР';

  @override
  String get reset => 'Скинути';

  @override
  String get localTime => 'МІСЦЕВИЙ ЧАС';

  @override
  String get goldenHour => 'Золота година';

  @override
  String get goldenHourMorning => 'Золота година (ранок)';

  @override
  String get goldenHourEvening => 'Золота година (вечір)';

  @override
  String get eventZenithStart => 'Початок зеніту';

  @override
  String get eventZenithEnd => 'Кінець зеніту';

  @override
  String get eventSolarNoon => 'Сонячний полудень';

  @override
  String get eventGoldenHourEnd => 'Кінець золотої години';

  @override
  String get calculating => 'РОЗРАХУНОК...';

  @override
  String comingIn(String time) {
    return 'ЧЕРЕЗ $time';
  }

  @override
  String get goldenHourActive => 'ЗОЛОТА ГОДИНА АКТИВНА';

  @override
  String remaining(String time) {
    return 'ЗАЛИШИЛОСЯ $time';
  }

  @override
  String get night => 'НІЧ';

  @override
  String get finished => 'ЗАВЕРШЕНО';

  @override
  String get brightness => 'ЯСКРАВІСТЬ';

  @override
  String remainingLower(String time) {
    return 'Залишилося $time';
  }

  @override
  String remainingUntilSleep(String time) {
    return 'До сну: $time';
  }

  @override
  String get remainingUntilWakeUp => 'До пробудження';

  @override
  String circadianImpactWithStatus(String feature, int impact, String status) {
    return '$feature $impact% яскравість ($status)';
  }

  @override
  String activeLower(String time) {
    return 'Активно $time';
  }

  @override
  String get sunSet => 'Сонце зайшло';

  @override
  String get calculatingLower => 'Розрахунок...';

  @override
  String transitionNotice(int hours) {
    return 'Система перейде на теплий спектр 2700K приблизно через $hours год.';
  }

  @override
  String get goldenHourNotice =>
      'Зараз Золота година. Спектр зміщено до теплого 2700K.';

  @override
  String get solarCycleEnded =>
      'Сонячний цикл на сьогодні завершено. Система в ручному нічному режимі.';

  @override
  String get updatingSolarData =>
      'Оновлення даних про сонце на основі вашого місцезнаходження...';

  @override
  String get autoAdapt => 'Автопідстроювання';

  @override
  String get autoBrightness => 'Автояскравість';

  @override
  String get autoTemperature => 'Автотемпература';

  @override
  String get active => 'Активно';

  @override
  String get nightShift => 'Нічний режим';

  @override
  String get disabled => 'Вимкнено';

  @override
  String get statusAdaptive => 'Адаптивний контроль';

  @override
  String get statusManual => 'Ручний режим';

  @override
  String get phaseDeepNight => 'ГЛИБОКА НІЧ';

  @override
  String get phaseDawn => 'СВІТАНОК';

  @override
  String get phaseMorningSpike => 'РАНКОВИЙ ПІК';

  @override
  String get phaseZenith => 'ЗЕНІТ';

  @override
  String get phaseGoldenHour => 'ЗОЛОТА ГОДИНА';

  @override
  String get phaseTwilight => 'СУТІНКИ';

  @override
  String get descDeepNightAuto =>
      'Нічний цикл. Адаптивний контроль підтримує мінімальну яскравість.';

  @override
  String get descDeepNightManual =>
      'Глибока ніч. Система в ручному режимі очікування світанку.';

  @override
  String get descDawnAuto =>
      'Цивільні сутінки. Плавний перехід до денного режиму.';

  @override
  String get descDawnManual =>
      'Світанок. Система в ручному режимі очікування сонця.';

  @override
  String get descMorningSpikeAuto =>
      'Передсвітанковий пік. Яскравість плавно зростає до сходу сонця.';

  @override
  String get descMorningSpikeManual =>
      'Передсвітанковий підйом. Встановлено фіксовану яскравість.';

  @override
  String get descZenithAuto =>
      'Зеніт. Максимальна світлова ефективність за розкладом.';

  @override
  String get descZenithManual =>
      'Повний день. Ви використовуєте ручні налаштування яскравості.';

  @override
  String get descGoldenHourAuto =>
      'Золота година. Спектр зміщено до теплого 2700K для комфорту.';

  @override
  String get descGoldenHourManual =>
      'Золота година. Колірна корекція призупинена.';

  @override
  String get descTwilightAuto =>
      'Цивільні сутінки. Плавний перехід до нічного режиму.';

  @override
  String get descTwilightManual =>
      'Сутінки. Система в ручному режимі зниженої яскравості.';

  @override
  String get panelTemperature => 'Температура панелі';

  @override
  String get efficiencyRate => 'Ефективність';

  @override
  String get atmosphericClarity => 'Ясність атмосфери';

  @override
  String get high => 'Висока';

  @override
  String get sunriseLabel => 'Схід сонця';

  @override
  String get sunsetLabel => 'Захід сонця';

  @override
  String appVersion(String version) {
    return 'Версія Solaris $version';
  }

  @override
  String get allMonitors => 'Усі монітори';

  @override
  String get luminosityProfile => 'Профіль освітленості';

  @override
  String get sunPosition => 'Положення сонця';

  @override
  String get liveLocation => 'Місцезнаходження';

  @override
  String get solarTelemetry => 'Сонячна телеметрія';

  @override
  String get civilTwilight => 'Цивільні сутінки';

  @override
  String get astronomicalNight => 'Астрономічна ніч';

  @override
  String get windSpeed => 'Швидкість вітру';

  @override
  String get spectralIntensity => 'Спектральна інтенсивність';

  @override
  String get uvIndex => 'Індекс УФ';

  @override
  String get extreme => 'Екстремальний';

  @override
  String get azimuth => 'АЗИМУТ';

  @override
  String get elevation => 'ВИСОТА';

  @override
  String get zenith => 'ЗЕНІТ';

  @override
  String get constant => 'Постійно';

  @override
  String get humidity => 'Вологість';

  @override
  String get airTemp => 'Темп. повітря';

  @override
  String get settingsSubtitle =>
      'Налаштуйте параметри вашого циркадного ритму. Ви можете перетягувати пресети, затиснувши ліву кнопку миші, а також перейменувати або видалити їх, натиснувши праву кнопку миші.';

  @override
  String get circadianLimits => 'Циркадні межі';

  @override
  String get circadianLimitsSubtitle => 'Визначте межі для автояскравості';

  @override
  String get minBrightness => 'Мінімальна яскравість';

  @override
  String get minBrightnessSubtitle => 'Найнижчий рівень яскравості вночі';

  @override
  String get maxBrightness => 'Максимальна яскравість';

  @override
  String get maxBrightnessSubtitle =>
      'Пікова яскравість, що досягається в зеніті';

  @override
  String get transBrightness => 'Яскравість переходу';

  @override
  String get transBrightnessSubtitle =>
      'Цільовий рівень під час золотої години та цивільних сутінків';

  @override
  String get realtimeApplyNotice =>
      'Зміни застосовуються в реальному часі. Використовуйте панель керування для перемикання між ручним та автоматичним регулюванням.';

  @override
  String get autorun => 'Автозапуск при старті';

  @override
  String get autorunSubtitle =>
      'Автоматично запускати програму при вході у Windows';

  @override
  String get startupMode => 'Режим запуску';

  @override
  String get startupModeTray => 'У треї';

  @override
  String get startupModeMinimized => 'Згорнуто';

  @override
  String get weatherAdjustmentTitle => 'Корекція по погоді';

  @override
  String get weatherAdjustmentSubtitle =>
      'Автоматичне коригування екрана залежно від погодних умов';

  @override
  String get weatherBrightnessAdjustmentTitle =>
      'Адаптація яскравості за погодою';

  @override
  String get weatherBrightnessAdjustmentSubtitle =>
      'Зниження яскравості в похмуру або дощову погоду для комфорту очей';

  @override
  String get weatherTemperatureAdjustmentTitle =>
      'Адаптація температури за погодою';

  @override
  String get weatherTemperatureAdjustmentSubtitle =>
      'Зниження колірної температури в похмуру або дощову погоду для відпочинку очей';

  @override
  String get temperatureRegulationTitle => 'Регуляція температури';

  @override
  String get temperatureBreakdownBase => 'Базова температура кривої';

  @override
  String get temperatureBreakdownWeather => 'Погода (зниження)';

  @override
  String get temperatureBreakdownSleepPressure => 'Тиск сну';

  @override
  String get temperatureBreakdownWindDown => 'Підготовка до сну';

  @override
  String get temperatureBreakdownSleepDebt => 'Компенсація недосипу';

  @override
  String get temperatureBreakdownFinal => 'Підсумкова температура';

  @override
  String get weatherIntensity => 'Інтенсивність корекції';

  @override
  String get weatherAdjustmentIntensitySubtitle =>
      'Керує тим, наскільки сильно погода впливає на яскравість екрана';

  @override
  String get weatherProvider => 'Провайдер погоди';

  @override
  String get weatherProviderAuto => 'Автоматично';

  @override
  String get weatherProviderWeatherApi => 'WeatherAPI.com';

  @override
  String get weatherProviderOpenMeteo => 'Open-Meteo.com';

  @override
  String weatherBrightnessReduction(int percent) {
    return 'Погода: зниження яскравості на $percent%';
  }

  @override
  String get selectMonitor => 'Оберіть монітор';

  @override
  String get presetBrightest => 'Найяскравіший';

  @override
  String get presetBright => 'Яскравий';

  @override
  String get presetDim => 'Тьмяний';

  @override
  String get presetDimmest => 'Найтемніший';

  @override
  String get presetCustom => 'Свій';

  @override
  String get tempCoolest => 'Найхолодніший';

  @override
  String get tempCool => 'Холодний';

  @override
  String get tempWarm => 'Теплий';

  @override
  String get tempWarmest => 'Найтепліший';

  @override
  String get tempCustom => 'Свій';

  @override
  String get blueLightFilter => 'Адаптивна колірна температура';

  @override
  String get blueLightFilterSubtitle =>
      'Автоматично робить кольори теплішими ввечері для зниження навантаження на очі';

  @override
  String get chartModeBrightness => 'Яскравість';

  @override
  String get chartModeTemperature => 'Температура';

  @override
  String get disabledInSettings => 'Вимкнено в налаштуваннях';

  @override
  String get enable => 'Увімкнути';

  @override
  String get sleepData => 'Дані про сон';

  @override
  String get sleepDataSubtitle =>
      'Синхронізація з Google Fit для відстеження циклів відпочинку';

  @override
  String get connectGoogleFit => 'Підключити Google Fit';

  @override
  String get disconnectGoogleFit => 'Відключити';

  @override
  String get googleFitConnected => 'Підключено до Google Fit';

  @override
  String get googleFitDisconnected => 'Не підключено';

  @override
  String get lastSyncSuccess => 'Остання синхронізація: успішно';

  @override
  String get lastSyncFailed => 'Остання синхронізація: помилка';

  @override
  String get testSync => 'Перевірити синхронізацію';

  @override
  String get sleep => 'Сон (Beta)';

  @override
  String get circadianRegulationBetaNote =>
      'Даний функціонал перебуває на стадії бета-тестування. Стабільна робота не гарантується.';

  @override
  String get sleepSubtitle => 'Аналізуйте режими сну та синхронізуйте дані';

  @override
  String get googleFitSync => 'Синхронізація Google Fit';

  @override
  String get connectedStatusSmall => 'Підключено';

  @override
  String get lastFetchLabel => 'Останнє оновлення:';

  @override
  String get never => 'Ніколи';

  @override
  String get signOut => 'Вийти';

  @override
  String get syncNow => 'Синхронізувати';

  @override
  String get syncing => 'Синхронізація...';

  @override
  String get verifyingConnection => 'Перевірка підключення...';

  @override
  String get connectionError => 'Помилка підключення';

  @override
  String get hoursAbbreviation => 'год';

  @override
  String get minutesAbbreviation => 'хв';

  @override
  String get sleepRegime => 'Режим сну';

  @override
  String get scatter => 'Розсіювання';

  @override
  String daysCount(int count) {
    return '$count дн.';
  }

  @override
  String get sleepInDate => 'Дата засинання';

  @override
  String get detectedRegimes => 'Виявлені режими';

  @override
  String get currentRegime => 'Поточний режим';

  @override
  String get outdated => 'Застаріло';

  @override
  String get smartCircadianTitle => 'Розумне циркадне підстроювання';

  @override
  String get smartCircadianSubtitle =>
      'Динамічна корекція на основі даних про сон з Google Fit (фаза засинання, біо-ранок, недосип)';

  @override
  String get circadianRegulation => 'Регуляція яскравості';

  @override
  String get featureWindDown => 'Фаза «Підготовки до сну» (Wind-down)';

  @override
  String get featureWindDownSubtitle =>
      'Плавне зниження яскравості та потепління екрана перед сном';

  @override
  String get featureTimeShift => 'Біо-ранок (Динамічний якір)';

  @override
  String get featureTimeShiftSubtitle =>
      'Зміщення графіка під реальний час пробудження';

  @override
  String get featureSleepPressure => 'Тиск сну (Час бадьорості)';

  @override
  String get featureSleepPressureSubtitle =>
      'Плавне димування при тривалій відсутності сну';

  @override
  String get featureSleepDebt => 'Компенсація недосипу';

  @override
  String get featureSleepDebtSubtitle =>
      'Зниження навантаження при короткому сні (< 6.5год)';

  @override
  String get influenceBrightness => 'Яскравість';

  @override
  String get influenceTemperature => 'Температура';

  @override
  String get featureWindDownInfo =>
      'Готує організм до сну, поступово зменшуючи кількість синього світла та загальну освітленість. Це стимулює вироблення мелатоніну та полегшує засинання.';

  @override
  String get featureTimeShiftInfo =>
      'Адаптує циркадний графік під ваш реальний час пробудження. Якщо ви прокинулися раніше або пізніше звичайного, система плавно змістить піки яскравості та температури, щоб синхронізуватися з вашим поточним станом.';

  @override
  String get featureSleepPressureInfo =>
      'Враховує час, проведений без сну. Якщо ви бадьорствуєте занадто довго, система починає плавно знижувати яскравість, щоб зменшити когнітивне навантаження та подати організму сигнал про необхідність відпочинку.';

  @override
  String get featureSleepDebtInfo =>
      'Активується, якщо ваш останній сон був коротшим за 6.5 годин. Протягом дня система підтримуватиме комфортніший, приглушений режим освітлення, щоб знизити навантаження на втомлені очі та нервову систему.';

  @override
  String get intensity => 'Інтенсивність';

  @override
  String get strength => 'Сила';

  @override
  String get brightnessIntensity => 'Інтенсивність (яскравість)';

  @override
  String get temperatureIntensity => 'Інтенсивність (температура)';

  @override
  String get shiftStrength => 'Сила зміщення';

  @override
  String circadianImpact(String feature, int impact) {
    return '$feature $impact% яскравість';
  }

  @override
  String get featureWindDownShort => 'Підготовка до сну';

  @override
  String get featureTimeShiftShort => 'Біо-ранок';

  @override
  String get featureSleepPressureShort => 'Тиск сну';

  @override
  String get featureSleepDebtShort => 'Недосип';

  @override
  String circadianImpactWithTime(
    String feature,
    int impact,
    int time,
    String unit,
  ) {
    return '$feature $impact% яскравість ($time $unit)';
  }

  @override
  String get windDownDuration => 'Тривалість підготовки до сну';

  @override
  String get timeShiftDuration => 'Час адаптації біо-ранку';

  @override
  String get sleepPressureLimit => 'Поріг бадьорості';

  @override
  String get sleepDebtThreshold => 'Норма сну (поріг недосипу)';

  @override
  String get smartExclusions => 'Розумні виключення';

  @override
  String get smartExclusionsSubtitle =>
      'Автоматичне блокування яскравості для ігор';

  @override
  String get enableGameMode => 'Увімкнути ігровий режим';

  @override
  String get enableGameModeSubtitle => 'Блокувати яскравість при виявленні гри';

  @override
  String get lockedBrightness => 'Заблокована яскравість';

  @override
  String get whitelist => 'Білий список';

  @override
  String get whitelistSubtitle => 'Програми, які завжди вмикають ігровий режим';

  @override
  String get blacklist => 'Чорний список';

  @override
  String get blacklistSubtitle => 'Ігнорувати, навіть якщо на весь екран';

  @override
  String get sunBase => 'Базова яскравість кривої';

  @override
  String get finalValue => 'Підсумок';

  @override
  String get brightnessReceipt => 'Чек яскравості';

  @override
  String get sleepAnalysisSettings => 'Налаштування аналізу сну';

  @override
  String get toleranceWindow => 'Вікно допустимих відхилень';

  @override
  String get toleranceWindowDesc =>
      'Наскільки може відхилятися час відходу до сну від «опорного» значення, перш ніж буде зарахована аномалія.';

  @override
  String get maxAnomalies => 'Максимум аномалій';

  @override
  String get maxAnomaliesDesc =>
      'Кількість послідовних «аномальних» днів, що допускається алгоритмом до розриву поточного режиму.';

  @override
  String get minRegimeLength => 'Мінімальна кількість днів';

  @override
  String get minRegimeLengthDesc =>
      'Мінімальна тривалість режиму, щоб він не був об’єднаний із сусіднім.';

  @override
  String get anchorSize => 'Розмір опорного вікна';

  @override
  String get anchorSizeDesc =>
      'Кількість перших днів для формування якірного середнього значення.';

  @override
  String get maxSpread => 'Максимальний розкид режиму';

  @override
  String get maxSpreadDesc =>
      'Максимальна різниця (макс — мін) у графіку відходу до сну у хвилинах. Якщо перевищена, режим розбивається.';

  @override
  String get language => 'Мова';

  @override
  String get english => 'Англійська';

  @override
  String get russian => 'Російська';

  @override
  String get ukrainian => 'Українська';

  @override
  String get globalHotkeys => 'Глобальні гарячі клавіші';

  @override
  String get globalHotkeysSubtitle =>
      'Керуйте пресетами та яскравістю з будь-якої програми';

  @override
  String get nextPreset => 'Наступний пресет';

  @override
  String get prevPreset => 'Попередній пресет';

  @override
  String get increaseBrightness => 'Яскравіше';

  @override
  String get decreaseBrightness => 'Тьмяніше';

  @override
  String get brightnessStep => 'Крок налаштування яскравості';

  @override
  String get brightnessStepUp => 'Крок (збільшення)';

  @override
  String get brightnessStepDown => 'Крок (зменшення)';

  @override
  String get pressToRecord => 'Натисніть клавіші...';

  @override
  String get hotkeyRecording => 'Запис...';

  @override
  String get cancel => 'Скасувати';

  @override
  String get save => 'Зберегти';

  @override
  String get toggleAutoBrightness => 'Увімк./Вимк. автояскравість';

  @override
  String get savePreset => 'Зберегти пресет';

  @override
  String get presetName => 'Назва пресета';

  @override
  String get namePresetHint => 'Введіть назву...';

  @override
  String get deletePreset => 'Видалити пресет';

  @override
  String get deletePresetConfirm =>
      'Ви впевнені, що хочете видалити цей пресет?';

  @override
  String get delete => 'Видалити';

  @override
  String get rename => 'Перейменувати';

  @override
  String errorWithMsg(String msg) {
    return 'Помилка: $msg';
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
    return '$value км/год';
  }

  @override
  String spectralIntensityValue(String value) {
    return '$value Вт/м²';
  }

  @override
  String uvIndexValue(String value) {
    return '$value';
  }

  @override
  String latLonFormat(String lat, String lon) {
    return 'Широта: $lat, Довгота: $lon';
  }

  @override
  String get detectingLocation => 'Визначення місцезнаходження...';

  @override
  String get coordinatesUnavailable => 'Координати недоступні';

  @override
  String get north => 'Пн';

  @override
  String get south => 'Пд';

  @override
  String get east => 'Сх';

  @override
  String get west => 'Зх';

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
  String get currentPosition => 'Поточне положення';

  @override
  String lockedBrightnessValue(int value) {
    return '$value%';
  }

  @override
  String get gameModeHint => 'напр. game.exe';

  @override
  String get about => 'Про програму';

  @override
  String get legal => 'Юридична інформація';

  @override
  String get legalSubtitle => 'Юридична інформація та конфіденційність';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get privacyPolicySubtitle =>
      'Дізнайтеся про те, як ми обробляємо ваші дані та інтеграцію з Google Fit.';

  @override
  String get disclaimerTitle => 'Відмова від відповідальності';

  @override
  String get disclaimerText =>
      'ВІДМОВА ВІД ВІДПОВІДАЛЬНОСТІ: Це програмне забезпечення надається на умовах «ЯК Є», БЕЗ БУДЬ-ЯКИХ ГАРАНТІЙ. Розробник не несе відповідальності за апаратні збої, проблеми з прошивкою або фізичний дискомфорт, що виникли внаслідок використання цієї програми. Використовуючи Solaris, ви визнаєте, що робите це на власний ризик і берете на себе повну відповідальність за сумісність обладнання. У жодному разі автор не несе відповідальності за будь-які особливі, випадкові або непрямі збитки.';

  @override
  String get viewLicenses => 'Переглянути ліцензії';

  @override
  String get close => 'Закрити';

  @override
  String get multiMonitorOffsets => 'Зміщення для декількох моніторів';

  @override
  String get multiMonitorOffsetsSubtitle =>
      'Налаштуйте індивідуальну яскравість моніторів відносно глобального рівня';

  @override
  String get brightnessOffset => 'Зміщення яскравості';

  @override
  String get linkAndOffset => 'Зв\'язок та зміщення';

  @override
  String get offsetFormula => 'Підсумок = Глобальна + Зміщення';

  @override
  String get weatherAnimations => 'Анімації погоди';

  @override
  String get showRain => 'Показати дощ';

  @override
  String get showSnow => 'Показати сніг';

  @override
  String get showThunder => 'Показати грозу';

  @override
  String get showClouds => 'Показати хмари';

  @override
  String get weatherSettingsSubtitle => 'Налаштуйте видимість анімацій';

  @override
  String get lastUpdated => 'Оновлено';

  @override
  String lastUpdatedFormat(String time) {
    return 'Оновлено о $time';
  }

  @override
  String get mapSettings => 'Налаштування карти';

  @override
  String get mapStyle => 'Стиль карти';

  @override
  String get mapStyleAuto => 'Автоматично';

  @override
  String get mapStyleDay => 'День';

  @override
  String get mapStyleNight => 'Ніч';

  @override
  String get searchPlaceholder =>
      'Пошук налаштувань (яскравість, сон, клавіші)...';

  @override
  String noResultsFound(String query) {
    return 'Нічого не знайдено за запитом \'$query\'';
  }

  @override
  String get tags_brightness =>
      'світло, яскравість, підсвічування, екран, монітор, темніше, світліше, очі, дисплей, панель, рівень';

  @override
  String get tags_auto_brightness =>
      'автоматично, адаптивно, датчик, графік, сонце, авто, динаміка, лінкування, синхронізація, зв\'язок';

  @override
  String get tags_auto_temperature =>
      'колір, тепло, синє світло, фільтр, ніч, вечір, кельвіни, температура, авто, спектр, нічний режим';

  @override
  String get tags_schedule =>
      'графік, крива, цикл, ранок, день, вечір, ніч, діаграма, розклад, профіль, план, карта';

  @override
  String get tags_sleep =>
      'гугл фіт, відпочинок, підйом, ритм, сон, аналіз, дані, будильник, режим, трекер';

  @override
  String get tags_smart_circadian =>
      'розумний, адаптивний, біо, динаміка, тиск сну, засинання, біо-ранок, борг сну, бета, тест, налаштування';

  @override
  String get tags_wind_down =>
      'мелатонін, вечір, підготовка, спокій, загасання, теплий, червоний, засинання, релакс';

  @override
  String get tags_game_mode =>
      'ігри, повний екран, пріоритет, блок, продуктивність, виключення, гра, додаток';

  @override
  String get tags_circadian_limits =>
      'мін, макс, діапазон, межі, ліміт, яскравість, границя, обмеження, крива, точки, якір';

  @override
  String get tags_autorun =>
      'старт, запуск, віндовс, автозапуск, завантаження, авто, запуск';

  @override
  String get tags_weather =>
      'дощ, хмари, сонце, гроза, сніг, видимість, погода, зниження, ясність, атмосфера';

  @override
  String get tags_hotkeys =>
      'поєднання, клавіші, клавіатура, команда, швидко, хоткеї, прив\'язка, глобальні, кнопки';

  @override
  String get tags_language =>
      'мова, українська, російська, англійська, переклад, локалізація, говірка';

  @override
  String get tags_location =>
      'gps, карта, координати, місто, гео, позиція, локація, широта, довгота';

  @override
  String get tags_location_auto =>
      'gps, визначити, ip, гео, авто, позиція, автоматично';

  @override
  String get tags_multi_monitor =>
      'монітор, дисплей, екран, кілька, лінкування, зміщення, окремо, індивідуально';

  @override
  String get tags_weather_animations =>
      'анімація, візуально, дощ, сніг, гроза, ефект, хмари, увімкнути, карта';

  @override
  String get tags_sleep_analysis =>
      'поріг, аномалії, середнє, режим, розкид, аналіз, сон, налаштування';

  @override
  String get tags_legal =>
      'юридичний, ліцензія, відмова, відповідальність, залізо, інфо, про програму';

  @override
  String get tags_google_fit =>
      'гугл фіт, хмара, синхронізація, акаунт, авторизація, гугл, фіт, трекер сну, дані';

  @override
  String get tags_time_shift =>
      'біо ранок, біо-ранок, пробудження, зміщення, графік, динамічний, якір, бадьорість, циркадний';

  @override
  String get tags_sleep_pressure =>
      'тиск сну, димування, час бадьорість, тривалість, ліміт, години, втома';

  @override
  String get tags_sleep_debt =>
      'борг сну, недосип, компенсація, короткий сон, дефіцит відпочинку, відновлення, приглушений режим';

  @override
  String get tags_local_sleep_integration =>
      'локальна інтеграція сну, ipc сервер, http server, api, локалхост, порт, синхронізація сну';

  @override
  String get tags_weather_brightness =>
      'яскравість за погодою, хмарність, дощ, гроза, сонце, регулювання яскравості';

  @override
  String get tags_weather_temperature =>
      'температура за погодою, теплий, холодний, синє світло, хмарність, гроза, регулювання кольору';

  @override
  String get mapIssueDetected => 'Виявлено проблему з картою';

  @override
  String get mapboxTokenMissing =>
      'Токен доступу Mapbox відсутній або недійсний.';

  @override
  String get noInternetAccess =>
      'Не вдалося зв\'язатися з серверами Mapbox. Будь ласка, перевірте підключення до інтернету.';

  @override
  String get vcRedistMissing =>
      'Відсутній Visual C++ Redistributable (msvcp140.dll). Це необхідно для коректного відображення карт.';

  @override
  String get downloadVcRedist => 'Завантажити Visual C++ Redistributable';

  @override
  String get retryDiagnostics => 'Повторити діагностику';

  @override
  String get mapboxServers => 'Сервери Mapbox';

  @override
  String get mapboxReachabilityDesc => 'Сервери Mapbox недоступні.';

  @override
  String get sslIssueHint =>
      'Схоже на проблему з сертифікатами. Чисті установки Windows 10 часто не мають сучасних кореневих сертифікатів (наприклад, ISRG Root X1).';

  @override
  String get missingRedistHint =>
      'Відсутні компоненти Visual C++. Вони не предустановлені в чистій Windows. Будь ласка, встановіть цей пакет.';

  @override
  String get fixSslCert => 'Виправити SSL сертифікат';

  @override
  String get sslFixInstruction =>
      'Для виправлення потрібно ініціювати оновлення кореневих сертифікатів у Windows. Натискання кнопки нижче відкриє безпечне посилання у вашому браузері — сам візит на цю сторінку часто змушує Windows завантажити відсутній сертифікат.';

  @override
  String get trayOpen => 'Відкрити';

  @override
  String get trayExit => 'Вихід';

  @override
  String get sleepIntegrationTitle => 'Інтеграція сну (Локальний API)';

  @override
  String get sleepIntegrationSubtitle =>
      'Зв\'язок зі сторонніми трекерами сну та API';

  @override
  String get enableLocalIpcServer => 'Увімкнути локальний API сервер';

  @override
  String get enableLocalIpcServerSubtitle =>
      'Дозволяє приймати сесії сну на порту localhost';

  @override
  String get serverPort => 'Порт сервера';

  @override
  String get serverPortSubtitle =>
      'При зміні сервер перезапуститься автоматично';

  @override
  String serverRunningStatus(int port) {
    return 'Сервер запущений на порту $port';
  }

  @override
  String get serverStoppedStatus => 'Сервер зупинено або порт зайнятий';

  @override
  String serverPortBusyAlertTitle(int port) {
    return 'Порт $port зайнятий або недоступний';
  }

  @override
  String serverPortBusyAlertExplanation(int port) {
    return 'Solaris не вдалося запустити локальний API-сервер, оскільки порт $port наразі використовується іншою програмою або службою на вашому комп\'ютері.';
  }

  @override
  String serverPortBusyAlertSolution(Object port) {
    return 'Щоб вирішити цю проблему, ви можете ввести інший номер порту в полі вище (наприклад, 45322) або закрити програму, яка використовує порт $port.';
  }

  @override
  String get sleepIntegrationHelpTitle => 'Посібник з інтеграції сну';

  @override
  String get sleepIntegrationHelpIntro =>
      'Ця інтеграція дозволяє стороннім програмам для відстеження сну, розумним будильникам або скриптам автоматизації надсилати дані про сон безпосередньо в цей додаток через безпечне локальне з\'єднання.';

  @override
  String get sleepIntegrationHelpSectionWhat => 'Що це таке?';

  @override
  String get sleepIntegrationHelpSectionWhatText =>
      'Solaris динамічно регулює яскравість та колірну температуру ваших моніторів на основі циркадних ритмів. Для цього додатку потрібні точні дані про сон. Локальний API-сервер дозволяє отримувати точні дані без затримок та офлайн від програм, що запущені на вашому ПК.';

  @override
  String get sleepIntegrationHelpSectionHow => 'Як це працює';

  @override
  String get sleepIntegrationHelpSectionHowText =>
      '1. При увімкненні додаток запускає міні-сервер на вашому ПК, який слухає лише локальні запити (127.0.0.1).\n2. Сторонні програми надсилають сесії сну (у форматі JSON) або статус сну в реальному часі (спить / не спить).\n3. Додаток обробляє ці дані та автоматично коригує профіль екрана.';

  @override
  String get sleepIntegrationHelpSectionConfig => 'Налаштування';

  @override
  String get sleepIntegrationHelpSectionConfigText =>
      '• Увімкніть тумблер «Увімкнути локальний API сервер».\n• Залиште порт за замовчуванням (45321), якщо він не зайнятий іншою програмою.\n• Налаштуйте ваше ПЗ для надсилання POST-запитів на адреси:\n  - Історія сну: http://127.0.0.1:45321/api/sleep/sessions\n  - Статус реального часу: http://127.0.0.1:45321/api/sleep/status';

  @override
  String get sleepIntegrationHelpSectionDeduplication => 'Дедуплікація даних';

  @override
  String get sleepIntegrationHelpSectionDeduplicationText =>
      'Локальні дані мають абсолютний пріоритет. Якщо сесія з Google Fit перетинається за часом з локальною сесією (з похибкою в 1 годину), запис Google Fit автоматично видаляється, запобігаючи накладенню та подвійним записам.';

  @override
  String get sleepIntegrationHelpSectionSecurity => 'Безпека та приватність';

  @override
  String get sleepIntegrationHelpSectionSecurityText =>
      'Сервер працює виключно на локальній адресі 127.0.0.1 і недоступен з інтернету або локальної мережі. Ваші дані про сон залишаються тільки на вашому пристрої.';

  @override
  String get sleepIntegrationHelpSectionFormat => 'Формат JSON-даних';

  @override
  String get sleepIntegrationHelpSectionFormatText =>
      'Додаток очікує дані у форматі JSON. Деталі схеми:\n\n1. Сесії сну (POST на /api/sleep/sessions)\nОчікувані дані: Масив об\'єктів сесій сну JSON.\nКожен об\'єкт містить:\n• id: рядок (унікальний ідентифікатор сесії)\n• startTime: рядок (дата/час ISO 8601, наприклад, \"2026-07-17T00:30:00Z\")\n• endTime: рядок (дата/час ISO 8601, наприклад, \"2026-07-17T08:00:00Z\")\n• title: рядок (необов\'язкова назва сесії)\n• source: рядок (необов\'язково, за замовчуванням \"local_api\")\n\n2. Поточний статус сну (POST на /api/sleep/status)\nОчікувані дані: Об\'єкт JSON, що містить:\n• is_sleeping: логічне значення (true, якщо користувач спить, false — якщо не спить)';

  @override
  String get mapboxTokenMissingTooltip =>
      'Токен доступу Mapbox відсутній. Налаштуйте його в API Ключах або .env.';

  @override
  String get weatherApiKeyMissingWarning =>
      'Провайдер WeatherAPI вимкнено. Налаштуйте WEATHER_API_KEY в API Ключах або .env.';

  @override
  String get googleFitKeysMissingWarning =>
      'Інтеграція з Google Fit вимкнена. Налаштуйте GOOGLE_CLIENT_ID та GOOGLE_CLIENT_SECRET у Налаштуваннях (розділ «API Ключі»).';

  @override
  String get apiKeysTitle => 'API Ключі';

  @override
  String get apiKeysSubtitle =>
      'Налаштування персональних ключів доступу до сервісів';

  @override
  String get customWeatherApiKey => 'Персональний WeatherAPI ключ';

  @override
  String get customMapboxToken => 'Персональний Mapbox токен';

  @override
  String get customGoogleClientId => 'Персональний Google Client ID';

  @override
  String get customGoogleClientSecret => 'Персональний Google Client Secret';

  @override
  String get apiKeysHelpText =>
      'Ця версія Solaris зібрана без вбудованих ключів. Щоб використовувати функції карт, детальної погоди або синхронізації Google Fit, вкажіть свої ключі тут. Вони будуть обфусковані та збережені локально на вашому ПК.';

  @override
  String get apiKeysHelpTextWithDefaults =>
      'Ця версія Solaris зібрана з вбудованими ключами за замовчуванням. При бажанні ви можете перевизначити будь-який з них, вказавши тут свій власний ключ. Користувацькі ключі будуть обфусковані та збережені локально на вашому ПК.';

  @override
  String get apiKeysGetKeyLink => 'Отримати ключ';

  @override
  String get googleFitReleaseWarningTitle => 'Релізна версія з GitHub';

  @override
  String get googleFitReleaseWarningBody =>
      'Ця офіційна версія додатка завантажена з GitHub і не містить вбудованого Google Client ID та Client Secret через сувору політику безпеки Google щодо даних про здоров\'я (Restricted Scopes). Публічним додаткам заборонено отримувати доступ до історії сну без проходження дорогого незалежного аудиту безпеки.\n\nЩоб увімкнути синхронізацію:\n1. Введіть свій власний Google Client ID та Client Secret в розділі налаштувань «API Ключі».\n2. Або зберіть додаток з вихідних кодів зі своїм ключем у файлі `.env`.';

  @override
  String get goToSettings => 'В налаштування';

  @override
  String get apiKeyActiveBuiltIn => 'Вбудований активний';

  @override
  String get apiKeyActiveCustom => 'Користувацький активний';

  @override
  String get apiKeyNotConfigured => 'Ключ не налаштований';

  @override
  String get saveKey => 'Зберегти';

  @override
  String get clearKey => 'Очистити';

  @override
  String get saved => 'Збережено';
}
