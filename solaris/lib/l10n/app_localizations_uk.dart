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
  String get precisionGps => 'Прецизійний GPS';

  @override
  String get gpsSubtitle =>
      'Високоточне визначення місцезнаходження для інтеграції з обладнанням відстеження сонця.';

  @override
  String get statusConnected => 'Статус: Підключено';

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
  String get surfaceTemp => 'Темп. поверхні';

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
  String get settingsSubtitle => 'Налаштуйте параметри вашого циркадного ритму';

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
  String get weatherAdjustmentTitle => 'Вплив погоди';

  @override
  String get weatherAdjustmentSubtitle =>
      'Знижує яскравість у хмарну або дощову погоду';

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
  String get circadianRegulation => 'Циркадна регуляція (Beta)';

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
  String get sunBase => 'База (Сонце)';

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
}
