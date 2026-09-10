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
      'Нічний цикл. М\'яке підсвічування піклується про зір у темряві.';

  @override
  String get descDeepNightManual =>
      'Глибока ніч. Автопідстроювання спить, чекаючи на перші промені світанку.';

  @override
  String get descDawnAuto =>
      'Настає світанок. Экран плавно прокидається та переходить на денний режим.';

  @override
  String get descDawnManual =>
      'Небо світлішає. Ви керуєте яскравістю вручную в очікуванні сходу сонця.';

  @override
  String get descMorningSpikeAuto =>
      'Перші промені сонця. Яскравість плавно зростає, допомагаючи вам прокинутися.';

  @override
  String get descMorningSpikeManual =>
      'Передсвітанковий підйом. Ви перейшли на ручне керування яскравістю.';

  @override
  String get descZenithAuto =>
      'Сонце в зеніті. Встановлено оптимальну яскравість для денної роботи.';

  @override
  String get descZenithManual =>
      'Розпал дня. Автопідстроювання вимкнено, яскравість задано вручную.';

  @override
  String get descGoldenHourMorningBothAuto =>
      'Ранкова золота година. М\'яке тепле світло та яскравість налаштовані для легкого початку дня.';

  @override
  String get descGoldenHourMorningTempOnly =>
      'Ранкова золота година. Екран переведено в теплий спектр для комфорту ваших очей.';

  @override
  String get descGoldenHourMorningBrightOnly =>
      'Ранкова золота година. Яскравість адаптується під м\'яке світло раннього ранку.';

  @override
  String get descGoldenHourMorningManual =>
      'Ранкова золота година. Автопідстроювання відпочиває, параметры встановлено вручну.';

  @override
  String get descGoldenHourEveningBothAuto =>
      'Вечірня золота година. М\'яке тепле світло та яскравість адаптовані для затишного вечора.';

  @override
  String get descGoldenHourEveningTempOnly =>
      'Вечірня золота година. Екран переходить у теплий спектр, знижуючи навантаження перед сном.';

  @override
  String get descGoldenHourEveningBrightOnly =>
      'Вечірня золота година. Яскравість плавно знижується під стать сонцю, що заходить.';

  @override
  String get descGoldenHourEveningManual =>
      'Вечірня золота година. Автопідстроювання відпочиває, параметры встановлено вручну.';

  @override
  String get descTwilightAuto =>
      'Згущаються сутінки. Екран плавно переходить на затишний нічний режим.';

  @override
  String get descTwilightManual =>
      'Надворі сутінки. Автопідстроювання вимкнено, яскравість встановлено вручну.';

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
  String get presetSystemPrefix => 'Системна';

  @override
  String get presetUserPrefix => 'Кастомна';

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
  String get regimeAnomaly => 'Аномалія';

  @override
  String get regimeAnomalyTooltip =>
      'Аномальний час: поодиноке відхилення від звичного графіка';

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
  String get gameModeTargetDisplays => 'Цільові дисплеї';

  @override
  String get gameModeTargetDisplaysSubtitle =>
      'Оберіть, на яких моніторах блокувати яскравість та колір під час ігор';

  @override
  String get gameModeAllDisplays => 'Всі дисплеї';

  @override
  String get gameModePrimaryOnly => 'Тільки основний';

  @override
  String get gameModeCustom => 'Вибірково';

  @override
  String get primaryBadge => 'Основний';

  @override
  String get lockedBrightness => 'Заблокована яскравість';

  @override
  String get enableGameModeTemperature => 'Фіксувати температуру в грі';

  @override
  String get enableGameModeTemperatureSubtitle =>
      'Вимкнути авто-регулювання температури при виявленні гри';

  @override
  String get lockedTemperature => 'Температура в грі';

  @override
  String get gameModeExitDelay => 'Затримка при згортанні';

  @override
  String get gameModeExitDelaySubtitle =>
      'Час у секундах до вимкнення ігрового режиму після згортання гри';

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
  String get offlineReasonMissingToken =>
      'Токен доступу Mapbox не налаштований. Використовується резервна назва часового поясу.';

  @override
  String get offlineReasonApiError =>
      'Не вдалося отримати назву міста через API. Використовується резервна назва часового поясу.';

  @override
  String get coordinatesUnavailable => 'Координати недоступні';

  @override
  String get autoLocationFailedTooltip =>
      'Автовизначення геопозиції не спрацювало. Використовується системний часовий пояс (погодні ефекти вимкнено). Спробуйте обрати розташування на карті або ввести координати вручну.';

  @override
  String get systemTimezoneFallbackTitle => 'Системний часовий пояс';

  @override
  String get coordinatesNotSet => 'Координати не визначені';

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
  String get errorLoadingPrivacyPolicy =>
      'Помилка завантаження політики конфіденційності';

  @override
  String get disclaimerTitle => 'Відмова від відповідальності';

  @override
  String get disclaimerText =>
      'ВІДМОВА ВІД ВІДПОВІДАЛЬНОСТІ: Це програмне забезпечення надається на умовах «ЯК Є», БЕЗ БУДЬ-ЯКИХ ГАРАНТІЙ, явних або неявних. За жодних обставин розробник або автор не несуть відповідальності за будь-які апаратні збої, мерехтіння, пошкодження моніторів, фізичний дискомфорт, втрату даних, компрометацію системи безпеки, несанкціонований доступ до програми або витік ваших персональних API-ключів та облікових даних. Використовуючи Solaris, ви підтверджуєте, що робите це на власний ризик і берете на себе повну відповідальність за сумісність обладнання, безпечне зберігання ключів, а також за будь-які фінансові зобов\'язання, витрати або збитки, що виникли внаслідок компрометації ключів, перевищення лімітів сторонніх API або злому системи. Автор не несе відповідальності за будь-які прямі, непрямі, випадкові або послідовні збитки.';

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
      'ігри, повний екран, пріоритет, блок, продуктивність, виключення, гра, додаток, затримка, згортання, зафіксувати, температура, яскравість, білий список, чорний список';

  @override
  String get tags_game_mode_target_displays =>
      'ігри, цільові дисплеї, монітори, тільки основний, всі дисплеї, помоніторно, екран, вибір монітора, блокування яскравості';

  @override
  String get tags_game_mode_temp =>
      'ігри, зафіксувати температуру, температура в грі, колір, кельвіни';

  @override
  String get tags_game_mode_exit_delay =>
      'ігри, затримка при згортанні, затримка, згортання, таймер, секунди, вихід';

  @override
  String get tags_game_mode_brightness =>
      'ігри, зафіксована яскравість, рівень яскравості, екран';

  @override
  String get tags_game_mode_whitelist =>
      'ігри, білий список, дозволені програми, ігри exe, додання';

  @override
  String get tags_game_mode_blacklist =>
      'ігри, чорний список, заблоковані програми, виключення';

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
  String get serverPortSharedTooltip =>
      'Зміна цього порту також змінює загальний порт Solaris Control API у Налаштуваннях';

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
      '• Увімкніть тумблер «Увімкнути локальний API сервер».\n• Модульність та автономність: інтеграція сну працює повністю незалежно від Solaris Control API. Якщо основний API у Налаштуваннях вимкнено, API сну продовжить приймати дані.\n• Порт (за замовчуванням 45321) є спільним для сервера додатку: зміна номера порту тут автоматично синхронізується з Налаштуваннями.\n• Налаштуйте ваше ПЗ для надсилання POST-запитів на адреси:\n  - Історія сну: http://127.0.0.1:45321/api/sleep/sessions\n  - Статус реального часу: http://127.0.0.1:45321/api/sleep/status\n(Також підтримуються префікси /api/v1/sleep/...)';

  @override
  String get sleepIntegrationHelpSectionDeduplication => 'Дедуплікація даних';

  @override
  String get sleepIntegrationHelpSectionDeduplicationText =>
      'Локальні дані мають абсолютний пріоритет. Якщо сесія з Google Fit перетинається за часом з локальною сесією (з похибкою в 1 годину), запис Google Fit автоматично видаляється, запобігаючи накладенню та подвійним записам.';

  @override
  String get sleepIntegrationHelpSectionSecurity => 'Безпека та приватність';

  @override
  String get sleepIntegrationHelpSectionSecurityText =>
      'За замовчуванням сервер працює суто на локальній адресі 127.0.0.1 і недоступний із зовнішньої мережі. Якщо в Налаштуваннях увімкнено доступ по LAN (0.0.0.0), для надсилання даних сну з інших пристроїв обов\'язково вимагається валідний API-токен із дозволом на операції зі сном (push_sleep_status). Неавторизований доступ із LAN суворо блокується кодом 401 Unauthorized.';

  @override
  String get sleepIntegrationHelpSectionFormat => 'Формат JSON-даних';

  @override
  String get sleepIntegrationHelpSectionFormatText =>
      'Додаток очікує дані у форматі JSON. Деталі схеми:\n\n1. Сесії сну (POST на /api/sleep/sessions)\nОчікувані дані: Масив об\'єктів сесій сну JSON.\nКожен об\'єкт містить:\n• id: рядок (унікальний ідентифікатор сесії)\n• startTime: рядок (дата/час ISO 8601, наприклад, \"2026-07-17T00:30:00Z\")\n• endTime: рядок (дата/час ISO 8601, наприклад, \"2026-07-17T08:00:00Z\")\n• title: рядок (необов\'язкова назва сесії)\n• source: рядок (необов\'язково, за замовчуванням \"local_api\")\n\n2. Поточний статус сну (POST на /api/sleep/status)\nОчікувані дані: Об\'єкт JSON, що містить:\n• is_sleeping: логічне значення (true, якщо користувач спить, false — якщо не спить)';

  @override
  String get mapboxTokenMissingTooltip =>
      'Токен доступу Mapbox відсутній. Налаштуйте його в Налаштуваннях (розділ «API Ключі»).';

  @override
  String get weatherApiKeyMissingWarning =>
      'Провайдер WeatherAPI вимкнено. Налаштуйте WEATHER_API_KEY у Налаштуваннях (розділ «API Ключі»).';

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
      'Ця офіційна версія додатка завантажена з GitHub і не містить вбудованого Google Client ID та Client Secret через сувору політику безпеки Google щодо даних про здоров\'я (Restricted Scopes). Публічним додаткам заборонено отримувати доступ до історії сну без проходження дорогого незалежного аудиту безпеки.\n\nЩоб увімкнути синхронізацію:\n1. Введіть свій власний Google Client ID та Client Secret в розділі налаштувань «API Ключі».\n2. Або зберіть додаток із вихідного коду зі своїми ключами у файлі `.env`.';

  @override
  String get googleFitLocalWarningTitle => 'Відсутні ключі Google Fit';

  @override
  String get googleFitLocalWarningBody =>
      'Для інтеграції з Google Fit потрібні облікові дані Google OAuth.\n\nЩоб увімкнути синхронізацію:\n1. Введіть свій власний Google Client ID та Client Secret в розділі налаштувань «API Ключі».\n2. Або налаштуйте локальний файл `.env` та перезберіть додаток.';

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

  @override
  String get dpapiErrorTitle => 'Захист даних Windows';

  @override
  String get dpapiErrorPasswordChanged =>
      'Облікові дані або пароль вашого облікового запису Windows були змінені. З міркувань безпеки ми не змогли розшифрувати збережені API-ключі. Будь ласка, введіть їх заново в Налаштуваннях.';

  @override
  String get dpapiErrorInvalidData =>
      'Збережені захищені дані налаштувань пошкоджено. Будь ласка, введіть ваші API-ключі заново.';

  @override
  String get dpapiErrorGeneric =>
      'Сталася помилка підсистеми безпеки Windows при розшифруванні налаштувань. Будь ласка, введіть ваші API-ключі заново.';

  @override
  String get dpapiErrorActionOk => 'ОК';

  @override
  String get dpapiErrorActionSettings => 'У налаштування';

  @override
  String get invalidCoordinatesError =>
      'Некоректні координати. Широта має бути від -90 до 90, довгота від -180 до 180.';

  @override
  String get updateAvailable => 'Доступне оновлення';

  @override
  String updateAvailableVersion(Object version) {
    return 'Оновлення: v$version ⬆';
  }

  @override
  String updateCurrentVersion(Object version) {
    return 'Поточна версія: v$version';
  }

  @override
  String updateDownloadingPercent(Object percent) {
    return 'Завантаження: $percent% ↓';
  }

  @override
  String get updateVerifying => 'Перевірка цілісності...';

  @override
  String get updateVerified => 'Перевірено';

  @override
  String get updateIntegrityError => 'Помилка цілісності';

  @override
  String get updateReady => 'Готово до встановлення ✓';

  @override
  String get updateInstallRestart => 'Встановити та перезапустити';

  @override
  String get updateLater => 'Пізніше';

  @override
  String get updateRetry => 'Повторити';

  @override
  String get updateError => 'Помилка оновлення ⚠';

  @override
  String get updateReleaseNotes => 'Що нового';

  @override
  String updateFileSize(Object size) {
    return 'Розмір: $size';
  }

  @override
  String get updateViewOnGithub => 'Реліз на GitHub';

  @override
  String get updateRestartWarning =>
      'Програма буде перезапущена для встановлення оновлення.';

  @override
  String get updateCheckForUpdates => 'Перевірити наявність оновлень';

  @override
  String get updateChecking => 'Перевірка оновлень...';

  @override
  String get updateSuccessTitle => 'Застосунок оновлено';

  @override
  String updateSuccessBody(Object version) {
    return 'Solaris успішно оновлено до версії $version.';
  }

  @override
  String get updateRolledBackTitle => 'Відкат оновлення';

  @override
  String updateRolledBackBody(Object reason) {
    return 'Оновлення не вдалося. Застосунок відновлено до попередньої версії.\nПричина: $reason';
  }

  @override
  String get updateFailedTitle => 'Помилка оновлення';

  @override
  String updateFailedBody(Object reason) {
    return 'Сталася помилка під час встановлення оновлення.\nДеталі: $reason';
  }

  @override
  String get autoUpdatesTitle => 'Автоматичні оновлення';

  @override
  String get autoUpdatesSubtitle =>
      'Автоматично перевіряти наявність оновлень під час запуску та у фоновому режимі';

  @override
  String get tags_auto_updates =>
      'оновлення,автооновлення,версія,github,updates';

  @override
  String get customBuildNotice =>
      'Власна збірка: автоматичну перевірку вимкнено за замовчуванням';

  @override
  String get customBuildWarningTitle => 'Попередження про оновлення';

  @override
  String get customBuildWarningBody =>
      'При оновленні з власної збірки на офіційну версію ви можете втратити збережені API-ключі (Mapbox, WeatherAPI, Google Fit), а також створені ключі Solaris Control API. Обов\'язково скопіюйте та збережіть їх перед оновленням.';

  @override
  String get continueButton => 'Продовжити';

  @override
  String get dialogOk => 'ОК';

  @override
  String get updateNoUpdatesTitle => 'Оновлень не знайдено';

  @override
  String get updateNoUpdatesFound =>
      'Оновлень не знайдено, у вас актуальна версія.';

  @override
  String get updateInstallingTitle => 'Оновлення...';

  @override
  String get updateInstallingStatus => 'Встановлення оновлення...';

  @override
  String get updateDownloadingPackage => 'Завантаження пакета оновлення...';

  @override
  String get updateBackgroundNotice =>
      'Ви можете закрити це вікно. Процес триватиме у фоновому режимі.';

  @override
  String get apiTitle => 'Solaris Control API v1';

  @override
  String apiStatusActiveLan(int port) {
    return 'Активний (LAN: 0.0.0.0:$port)';
  }

  @override
  String apiStatusActiveLocalhost(int port) {
    return 'Активний (Localhost: 127.0.0.1:$port)';
  }

  @override
  String get apiStatusDisabled => 'Вимкнений';

  @override
  String get apiNetworkAccessMode => 'Режим мережевого доступу';

  @override
  String get apiModeLocalhost => 'Тільки Localhost (127.0.0.1)';

  @override
  String get apiModeLan => 'Доступ по LAN (0.0.0.0)';

  @override
  String get apiFirewallUacError =>
      'Помилка: Відмовлено в дозволі UAC Windows Firewall. Доступ по LAN скасовано.';

  @override
  String get apiServerPort => 'Порт API сервера';

  @override
  String get apiDocumentation => 'Інтерактивна документація';

  @override
  String get apiOpenSwagger => 'Відкрити OpenAPI Docs';

  @override
  String apiOpenDocsError(String error) {
    return 'Не вдалося відкрити документацію: $error';
  }

  @override
  String get apiAccessKey => 'Ключ доступу API (X-API-Key)';

  @override
  String get apiTokenHintRequiredLan => 'Обов\'язковий для LAN';

  @override
  String get apiTokenHintOptionalLocalhost => 'Опціонально для Localhost';

  @override
  String get apiCopyKeyTooltip => 'Скопіювати ключ API';

  @override
  String get apiKeyCopied => 'Ключ API скопійовано в буфер обміну';

  @override
  String get apiGenerateKeyTooltip => 'Згенерувати новий ключ';

  @override
  String get apiKeyGenerated => 'Згенеровано новий ключ API';

  @override
  String get webhooksTitle => 'Вихідні вебхуки';

  @override
  String webhooksSubtitle(int count, int queueCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count налаштовано',
      few: '$count налаштовано',
      one: '1 налаштовано',
    );
    return '$_temp0 | Черга WAL: $queueCount';
  }

  @override
  String get webhooksViewDlqTooltip =>
      'Переглянути чергу необроблених повідомлень (DLQ)';

  @override
  String get webhooksAddButton => 'Додати вебхук';

  @override
  String get webhooksEmptyMessage =>
      'Вихідні вебхуки не налаштовані.\nНатисніть \"Додати вебхук\" для інтеграції з Home Assistant, Node-RED або n8n.';

  @override
  String get webhooksDefaultName => 'Вебхук';

  @override
  String webhooksEventsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подій',
      few: '$count події',
      one: '1 подія',
    );
    return '$_temp0';
  }

  @override
  String get webhooksSendTestPingTooltip => 'Надіслати тестовий запит';

  @override
  String get webhooksSendingTestPing => 'Надсилання тестового запиту...';

  @override
  String get webhooksTestPingSuccess => 'Тестовий запит успішно доставлено!';

  @override
  String get webhooksTestPingFailed => 'Не вдалося доставити тестовий запит.';

  @override
  String get webhooksEditTooltip => 'Редагувати вебхук';

  @override
  String get webhooksDeleteTooltip => 'Видалити вебхук';

  @override
  String get webhooksAddTitle => 'Додати вихідний вебхук';

  @override
  String get webhooksEditTitle => 'Редагувати вебхук';

  @override
  String get webhooksUrlLabel => 'URL цільового вебхука *';

  @override
  String get webhooksNameLabel => 'Назва (Опціонально)';

  @override
  String get webhooksSecretLabel => 'Секретний ключ HMAC (Опціонально)';

  @override
  String get webhooksSecretHint => 'Секрет для перевірки X-Solaris-Signature';

  @override
  String get webhooksSubscribedEvents => 'Підписки на події:';

  @override
  String get webhooksSelectAll => 'Вибрати всі';

  @override
  String get webhooksDeselectAll => 'Зняти вибір з усіх';

  @override
  String get webhooksInvalidUrlError =>
      'Будь ласка, введіть коректний абсолютний URL (наприклад, http://...)';

  @override
  String get webhooksSaveChangesButton => 'Зберегти зміни';

  @override
  String webhooksDlqTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Черга необроблених повідомлень ($count)',
      few: 'Черга необроблених повідомлень ($count)',
      one: 'Черга необроблених повідомлень (1)',
    );
    return '$_temp0';
  }

  @override
  String get webhooksDlqEmpty =>
      'Черга необроблених повідомлень порожня! Усі вебхуки успішно доставлені.';

  @override
  String webhooksDlqEvent(String eventName, String url) {
    return 'Подія: $eventName -> $url';
  }

  @override
  String webhooksDlqDetails(int count, String error, String id) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count спроб',
      few: '$count спроби',
      one: '1 спроба',
    );
    return '$_temp0 | Помилка: $error\nID доставки: $id';
  }

  @override
  String get webhooksClearDlq => 'Очистити DLQ';

  @override
  String get apiPermissionsDialogTitle =>
      'Права доступу API та гранулярний контроль';

  @override
  String get apiPermissionsReadOnlyLabel => 'Режим «Лише читання» (Read-Only)';

  @override
  String get apiPermissionsReadOnlyHint =>
      'Якщо увімкнено, усі керуючі API-запити (POST/PUT/DELETE) блокуються з кодом HTTP 403 Forbidden.';

  @override
  String get apiPermissionsDataSharingSection =>
      'Дозволи на передачу даних (Читання)';

  @override
  String get apiPermissionsAllowMonitors => 'Монітори та стан яскравості';

  @override
  String get apiPermissionsAllowSolar => 'Сонячні та астрономічні дані';

  @override
  String get apiPermissionsAllowWeather =>
      'Погодні коригування та дані провайдера';

  @override
  String get apiPermissionsAllowSleep => 'Метрики сну та циркадного ритму';

  @override
  String get apiPermissionsAllowCircadian => 'Стан системи Smart Circadian';

  @override
  String get apiPermissionsControlCategoriesSection =>
      'Дозволені категорії команд (Управління)';

  @override
  String get apiPermissionsCategoryMonitors =>
      'Монітори (яскравість, температура, зсуви)';

  @override
  String get apiPermissionsCategoryPresets => 'Пресети та профілі яскравості';

  @override
  String get apiPermissionsCategoryCircadian =>
      'Циркадний ритм та авто-налаштування';

  @override
  String get apiPermissionsCategoryGaming => 'Ігровий режим та білі списки ПЗ';

  @override
  String get apiPermissionsCategoryEnvironment =>
      'Довкілля та погодні налаштування';

  @override
  String get apiPermissionsCategorySleep => 'Дії сну та оновлення статусу';

  @override
  String get apiPermissionsCategorySystem => 'Системні дії (вебхуки, анімації)';

  @override
  String get apiPermissionsConfigureButton => 'Налаштувати права API...';

  @override
  String get apiPermissionsSummaryReadOnly => 'Режим «Лише читання» активний';

  @override
  String apiPermissionsSummaryCustom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дозволено $count категорій',
      few: 'Дозволено $count категорії',
      one: 'Дозволено $count категорію',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysManagementDialogTitle => 'Управління ключами доступу API';

  @override
  String get apiKeysManagementSubtitle =>
      'Принцип найменших привілеїв: індивідуальні ключі для зовнішніх інтеграцій';

  @override
  String apiKeysActiveCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Налаштовано $count активних ключів',
      few: 'Налаштовано $count активні ключі',
      one: 'Налаштовано $count активний ключ',
      zero: 'Налаштовано 0 активних ключів',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysManageButton => 'Управління API-ключами...';

  @override
  String get apiKeysCreateButton => 'Створити новий ключ';

  @override
  String get apiKeysTableHeaderName => 'Назва';

  @override
  String get apiKeysTableHeaderScopes => 'Права (Scopes)';

  @override
  String get apiKeysTableHeaderCreated => 'Створено';

  @override
  String get apiKeysTableHeaderActions => 'Дії';

  @override
  String apiKeysReadOnlyChip(int count) {
    return 'Read-Only ($count/5)';
  }

  @override
  String apiKeysActiveScopesChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count з 7 категорій',
      few: '$count з 7 категорій',
      one: '1 з 7 категорій',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysCopySuccessSnackbar =>
      'Токен API-ключа скопійовано в буфер обміну!';

  @override
  String get apiKeysRegenerateConfirmTitle => 'Перегенерувати токен?';

  @override
  String get apiKeysRegenerateConfirmMessage =>
      'Усі пристрої та сервіси, що використовують поточний токен, втратять доступ до API.';

  @override
  String get apiKeysDeleteConfirmTitle => 'Відкликати API-ключ?';

  @override
  String apiKeysDeleteConfirmMessage(String name) {
    return 'Ви впевнені, що хочете відкликати ключ «$name»? Цю дію неможливо скасувати.';
  }

  @override
  String apiKeysDpapiWarningBanner(String name) {
    return 'Токен ключа «$name» було автоматично перестворено через зміну пароля Windows. Скопіюйте новий токен у ваші зовнішні пристрої.';
  }

  @override
  String get apiKeysDpapiBadge => 'Токен скинуто (зміна пароля ОС)';

  @override
  String get apiKeysSoleKeyDeleteWarning =>
      'Неможливо видалити єдиний API-ключ.';

  @override
  String get createApiKeyDialogTitle => 'Створення API-ключа';

  @override
  String get createApiKeyNameFieldLabel => 'Назва ключа';

  @override
  String get requireLocalTokenLabel =>
      'Вимагати авторизацію для локальних запитів';

  @override
  String get requireLocalTokenSubtitle =>
      'Запити з 127.0.0.1 без API-токена будуть відхилятися зі статусом HTTP 401 Unauthorized';

  @override
  String get showNewTokenDialogTitle => 'Ваш новий API-ключ';

  @override
  String get showNewTokenWarning =>
      'Скопіюйте цей токен просто зараз. З міркувань безпеки він більше ніколи не буде показаний у відкритому вигляді.';

  @override
  String get copyTokenButton => 'Скопіювати токен';

  @override
  String get savedTokenButton => 'Я зберіг токен';

  @override
  String get deleteSleepSessionTitle => 'Видалити сесію сну';

  @override
  String get deleteSleepSegmentTitle => 'Видалити сегмент сну';

  @override
  String deleteSleepSessionConfirm(String dateRange) {
    return 'Ви впевнені, що хочете видалити цю сесію сну ($dateRange)?';
  }

  @override
  String deleteSleepSegmentConfirm(String timeRange) {
    return 'Ви впевнені, що хочете видалити цей сегмент сну ($timeRange)?';
  }

  @override
  String get doNotSyncInFuture => 'Не синхронізувати в майбутньому';

  @override
  String get deleteAction => 'Видалити';

  @override
  String get cancelAction => 'Скасувати';

  @override
  String get editAction => 'Редагувати';

  @override
  String get editSleepSession => 'Редагувати сесію сну';

  @override
  String get editSleepSegment => 'Редагувати сегмент сну';

  @override
  String get mergeAndEditNight => 'Об\'єднати та редагувати ніч';

  @override
  String get mergeNightSessionsHint =>
      'Об\'єднає всі сегменти цієї ночі в одну суцільну сесію';

  @override
  String get sleepCardsInteractionTooltip =>
      'Картки сну:\n• Клік — редагувати час\n• ПКМ — контекстне меню (редагувати/видалити)\n• Затискання — видалити';

  @override
  String get sleepCardsInteractionTitle => 'Керування сесіями сну';

  @override
  String get sleepCardsInteractionHelpIntro =>
      'Solaris надає повний контроль над записами сну у поточному та збережених режимах:';

  @override
  String get sleepCardsInteractionHelpEditTitle =>
      'Редагування часу та об\'єднання';

  @override
  String get sleepCardsInteractionHelpEditText =>
      'Натисніть на будь-який рядок ночі, щоб відредагувати інтервал сну. Якщо ніч складається з кількох фрагментів, ви зможете об\'єднати їх в одну неперервну сесію або відредагувати конкретний сегмент окремо, натиснувши на його чип.';

  @override
  String get sleepCardsInteractionHelpDeleteTitle => 'Видалення записів';

  @override
  String get sleepCardsInteractionHelpDeleteText =>
      'Для видалення ночі затисніть рядок ночі (довгий тап) або натисніть правою кнопкою миші (ПКМ) для виклику контекстного меню дій.';

  @override
  String get addSleepSession => 'Додати сесію сну';

  @override
  String get startTime => 'Початок сну';

  @override
  String get endTime => 'Кінець сну';

  @override
  String get duration => 'Тривалість';

  @override
  String get sleepSessionTitleHint => 'Наприклад: Нічний сон';

  @override
  String get sleepSessionDescHint => 'Наприклад: Ручне введення';

  @override
  String get manualSleepTitleDefault => 'Нічний сон';

  @override
  String get manualSleepDescDefault => 'Додано вручну';

  @override
  String get invalidTimeRangeError =>
      'Час закінчення має бути пізніше часу початку';

  @override
  String get saveAction => 'Зберегти';

  @override
  String get sessionTitleLabel => 'Заголовок';

  @override
  String get sessionDescLabel => 'Опис';

  @override
  String get apiPermissionsActionSetBrightness => 'Зміна яскравості';

  @override
  String get apiPermissionsActionSetTemperature =>
      'Зміна колірної температури (К)';

  @override
  String get apiPermissionsActionSetMonitorOffset =>
      'Індивідуальне зміщення монітора';

  @override
  String get apiPermissionsActionSetBrightnessPreset => 'Пресети яскравості';

  @override
  String get apiPermissionsActionSetTemperaturePreset => 'Пресети температури';

  @override
  String get apiPermissionsActionSetUserPreset => 'Користувацькі пресети';

  @override
  String get apiPermissionsActionCyclePreset => 'Циклічне перемикання пресетів';

  @override
  String get apiPermissionsActionSetAutoBrightness =>
      'Перемикач авто-яскравості';

  @override
  String get apiPermissionsActionSetAutoTemperature =>
      'Перемикач авто-температури';

  @override
  String get apiPermissionsActionSetSmartCircadian =>
      'Перемикач Smart Circadian';

  @override
  String get apiPermissionsActionSetSmartCircadianSubmodules =>
      'Управління підмодулями ритму';

  @override
  String get apiPermissionsActionSetGameMode => 'Ігровий режим (увімк/вимк)';

  @override
  String get apiPermissionsActionSetGameModeBrightness =>
      'Яскравість ігрового режиму';

  @override
  String get apiPermissionsActionManageGameModeWhitelist =>
      'Управління білим списком ПЗ';

  @override
  String get apiPermissionsActionSetWeatherAdjustment => 'Погодне коригування';

  @override
  String get apiPermissionsActionSetWeatherTemperatureAdjustment =>
      'Погодне коригування температури';

  @override
  String get apiPermissionsActionSetWeatherIntensity =>
      'Інтенсивність погодних ефектів';

  @override
  String get apiPermissionsActionSetManualLocation =>
      'Ручне введення координат геопозиції';

  @override
  String get apiPermissionsActionSetWeatherProvider =>
      'Вибір провайдера погоди';

  @override
  String get apiPermissionsActionTriggerSunSync =>
      'Примусова синхронізація сонця та погоди';

  @override
  String get apiPermissionsActionPushSleepStatus => 'Передача статусу сну';

  @override
  String get apiPermissionsActionManageWebhooks =>
      'Управління вебхуками (CRUD та DLQ)';

  @override
  String get apiPermissionsActionSetMapAnimations => 'Анімації карти погоди';

  @override
  String get apiPermissionsActionOnSystemResume => 'Обробка відновлення ОС';

  @override
  String get apiPermissionsActionOnHardwareError => 'Обробка апаратних помилок';

  @override
  String get apiPermissionsActionGetAppOverrides =>
      'Отримання правил застосунків';

  @override
  String get apiPermissionsActionManageAppOverrides =>
      'Управління правилами застосунків';

  @override
  String get apiPermissionsActionResetBuiltinAppOverrides =>
      'Скинути системні пресети застосунків';

  @override
  String apiKeysGranularActionChip(int count, int total) {
    return 'Дозволено дій: $count з $total';
  }

  @override
  String get tags_solaris_api =>
      'апі, api, control api, solaris control api, http, rest, openapi, swagger, порт, локалхост, localhost, lan, сервер, розробникам';

  @override
  String get tags_api_keys =>
      'api key, токен, доступ, ключі api, права доступу, авторизація, безпека, bearer, scopes, ключ доступу';

  @override
  String get tags_webhooks =>
      'вебхук, вебхуки, webhook, webhooks, home assistant, node-red, n8n, hmac, події, сповіщення, інтеграція, автоматизація, dlq';

  @override
  String get searchCity => 'ПОШУК МІСТА';

  @override
  String get searchCityHint => 'Введіть назву міста...';

  @override
  String get citySearchDisabledNoToken =>
      'Для пошуку міст потрібен Mapbox API Key в Налаштуваннях';

  @override
  String get manualCoordinatesAdjusted => 'Ручне коригування';

  @override
  String get searchingCities => 'Пошук міст...';

  @override
  String get noCitiesFound => 'Міста не знайдені';

  @override
  String get ddcNotSupportedTooltip =>
      'Цей монітор не підтримує DDC/CI або його вимкнено в налаштуваннях.\nЗміна яскравості недоступна, але регулювання температури працює.';

  @override
  String get checkDdcAgain => 'Перевірити DDC/CI знову';

  @override
  String get tryAgain => 'Повторити';

  @override
  String get backToSettings => 'Назад до налаштувань';

  @override
  String get appOverridesTitle => 'Налаштування для додатків';

  @override
  String get appOverridesSubtitle =>
      'Налаштування індивідуальної яскравості та температури для вибраних додатків.';

  @override
  String get tags_app_overrides =>
      'правила додатків, додатки, індивідуальні налаштування, гра, профілі додатків, затримка вимкнення, exe, процеси, оверрайди';

  @override
  String get tags_app_override_exit_delay =>
      'затримка вимкнення, таймер, згортання додатку, фоновий режим, час очікування';

  @override
  String get tags_app_override_rules =>
      'додати додаток, правила, профілі, список додатків, exe файл, кастомна яскравість, користувацькі правила';

  @override
  String get appOverrideExitDelay => 'Затримка вимкнення';

  @override
  String get appOverrideExitDelaySubtitle =>
      'Час у секундах до вимкнення профілю при згортанні додатку.';

  @override
  String appOverrideExitDelaySeconds(int seconds) {
    return '$seconds сек';
  }

  @override
  String get userRulesSection => 'Правила користувача';

  @override
  String builtinRulesSection(int count) {
    return 'Вбудовані пресети ($count)';
  }

  @override
  String get addAppOverride => 'Додати додаток';

  @override
  String get resetBuiltinRules => 'Скинути системні правила';

  @override
  String get promoteToUser => 'Перенести в Мої';

  @override
  String get appOverrideModeGlobal => 'Глобальний';

  @override
  String get appOverrideModeFixed => 'Фіксований';

  @override
  String get appOverrideModeCurve => 'Крива';

  @override
  String get brightnessMode => 'Режим яскравості';

  @override
  String get temperatureMode => 'Режим температури';

  @override
  String get selectAppTitle => 'Вибір додатку';

  @override
  String get runningApps => 'Запущені процеси';

  @override
  String get selectExecutable => 'Обрати .exe файл...';

  @override
  String get customExeName => 'Ім\'я виконуваного файлу (наприклад app.exe)';

  @override
  String get customDisplayName => 'Назва додатку';

  @override
  String appPromotedToast(String appName) {
    return 'Додаток $appName перенесено з вбудованих пресетів у ваші правила';
  }

  @override
  String get resetBuiltinConfirmTitle => 'Скинути системні правила?';

  @override
  String get resetBuiltinConfirmMessage =>
      'Ви впевнені, що хочете відновити фабричні значення вбудованих пресетів? Ваші власні правила збережуться.';

  @override
  String get deleteOverrideConfirmTitle => 'Видалити правило?';

  @override
  String deleteOverrideConfirmMessage(String appName) {
    return 'Ви впевнені, що хочете видалити правило для $appName?';
  }

  @override
  String get noRunningApps => 'Запущені процеси не знайдені';

  @override
  String get selectPreset => 'Обрати пресет';

  @override
  String get searchAppPlaceholder => 'Пошук процесу...';

  @override
  String get noCustomAppRulesYet => 'Користувацькі правила ще не додані';

  @override
  String get noCustomAppRulesHint =>
      'Натисніть «Додати додаток», щоб створити власний профіль, або перенесіть вбудовані пресети нижче.';

  @override
  String get appOverridesConfigure => 'Налаштувати';

  @override
  String appRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count правил',
      few: '$count правила',
      one: '$count правило',
    );
    return '$_temp0';
  }

  @override
  String get builtinRuleBadge => 'Вбудований пресет';

  @override
  String get builtinActiveParameters => 'Вбудоване правило, що застосовується';

  @override
  String get manualAppEntry => 'Власний додаток';

  @override
  String get selectAppSubtitle =>
      'Оберіть активний процес або додайте власний файл';

  @override
  String get manualAppEntryHint =>
      'Вкажіть назву файлу .exe для налаштування правила, навіть якщо застосунок зараз не запущений';

  @override
  String get refreshProcesses => 'Оновити список процесів';

  @override
  String get clearSearch => 'Очистити пошук';

  @override
  String get selectedProcessLabel => 'Обраний процес';

  @override
  String get processDoubleTapHint => 'Подвійний клік для швидкого додавання';

  @override
  String get selectAppHint =>
      'Оберіть процес зі списку вище для додавання правила';

  @override
  String get addApp => 'Додати';

  @override
  String processesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count процесів',
      few: '$count процеси',
      one: '$count процес',
    );
    return '$_temp0';
  }
}
