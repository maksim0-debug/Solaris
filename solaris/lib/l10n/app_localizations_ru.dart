// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Solaris';

  @override
  String get celestialControl => 'НЕБЕСНЫЙ КОНТРОЛЬ';

  @override
  String get dashboard => 'Панель управления';

  @override
  String get schedule => 'Солнечный цикл';

  @override
  String get settings => 'Настройки';

  @override
  String get location => 'Местоположение';

  @override
  String get locationAutomation => 'Местоположение и Автоматизация';

  @override
  String get locationSubtitle =>
      'Синхронизируйте вашу среду с географическим положением. Пусть солнечные циклы диктуют плавность вашего рабочего процесса.';

  @override
  String get celestialMap => 'Небесная карта';

  @override
  String get celestialMapSubtitle =>
      'Удерживайте ЛКМ на карте, чтобы задать ваше местоположение';

  @override
  String autoDetect(String status) {
    return 'АВТО-ОПРЕДЕЛЕНИЕ: $status';
  }

  @override
  String get manualCoordinateEntry => 'Ручной ввод координат';

  @override
  String get latitude => 'ШИРОТА';

  @override
  String get longitude => 'ДОЛГОТА';

  @override
  String get updatePosition => 'Обновить позицию';

  @override
  String get precisionGps => 'Прецизионный GPS';

  @override
  String get gpsSubtitle =>
      'Высокоточное определение местоположения для интеграции с оборудованием слежения за солнцем.';

  @override
  String get statusConnected => 'Статус: Подключено';

  @override
  String get currentAnchor => 'ТЕКУЩИЙ ЯКОРЬ';

  @override
  String get reset => 'Сбросить';

  @override
  String get localTime => 'МЕСТНОЕ ВРЕМЯ';

  @override
  String get goldenHour => 'Золотой час';

  @override
  String get goldenHourMorning => 'Золотой час (утро)';

  @override
  String get goldenHourEvening => 'Золотой час (вечер)';

  @override
  String get eventZenithStart => 'Начало зенита';

  @override
  String get eventZenithEnd => 'Конец зенита';

  @override
  String get eventSolarNoon => 'Солнечный полдень';

  @override
  String get eventGoldenHourEnd => 'Конец золотого часа';

  @override
  String get calculating => 'РАСЧЕТ...';

  @override
  String comingIn(String time) {
    return 'ЧЕРЕЗ $time';
  }

  @override
  String get goldenHourActive => 'ЗОЛОТОЙ ЧАС АКТИВЕН';

  @override
  String remaining(String time) {
    return 'ОСТАЛОСЬ $time';
  }

  @override
  String get night => 'НОЧЬ';

  @override
  String get finished => 'ЗАВЕРШЕНО';

  @override
  String get brightness => 'ЯРКОСТЬ';

  @override
  String remainingLower(String time) {
    return 'Осталось $time';
  }

  @override
  String remainingUntilSleep(String time) {
    return 'До сна: $time';
  }

  @override
  String get remainingUntilWakeUp => 'До пробуждения';

  @override
  String circadianImpactWithStatus(String feature, int impact, String status) {
    return '$feature $impact% к яркости ($status)';
  }

  @override
  String activeLower(String time) {
    return 'Активно $time';
  }

  @override
  String get sunSet => 'Солнце зашло';

  @override
  String get calculatingLower => 'Расчет...';

  @override
  String transitionNotice(int hours) {
    return 'Система перейдет на теплый спектр 2700K примерно через $hours ч.';
  }

  @override
  String get goldenHourNotice =>
      'Сейчас Золотой час. Спектр смещен к теплому 2700K.';

  @override
  String get solarCycleEnded =>
      'Солнечный цикл на сегодня завершен. Система в ручном ночном режиме.';

  @override
  String get updatingSolarData =>
      'Обновление данных о солнце на основе вашего местоположения...';

  @override
  String get autoAdapt => 'Автоподстройка';

  @override
  String get autoBrightness => 'Автояркость';

  @override
  String get autoTemperature => 'Автотемпература';

  @override
  String get active => 'Активно';

  @override
  String get nightShift => 'Ночной режим';

  @override
  String get disabled => 'Выкл.';

  @override
  String get statusAdaptive => 'Адаптивный контроль';

  @override
  String get statusManual => 'Ручной режим';

  @override
  String get phaseDeepNight => 'ГЛУБОКАЯ НОЧЬ';

  @override
  String get phaseDawn => 'РАССВЕТ';

  @override
  String get phaseMorningSpike => 'РАССВЕТНЫЙ ПИК';

  @override
  String get phaseZenith => 'ЗЕНИТ';

  @override
  String get phaseGoldenHour => 'ЗОЛОТОЙ ЧАС';

  @override
  String get phaseTwilight => 'СУМЕРКИ';

  @override
  String get descDeepNightAuto =>
      'Ночной цикл. Адаптивный контроль поддерживает минимальную яркость.';

  @override
  String get descDeepNightManual =>
      'Глубокая ночь. Система в ручном режиме ожидания рассвета.';

  @override
  String get descDawnAuto =>
      'Гражданские сумерки. Плавный переход к дневному режиму.';

  @override
  String get descDawnManual =>
      'Рассвет. Система в ручном режиме ожидания солнца.';

  @override
  String get descMorningSpikeAuto =>
      'Предрассветный пик. Яркость плавно растет к восходу.';

  @override
  String get descMorningSpikeManual =>
      'Предрассветный подъем. Установлена фиксированная яркость.';

  @override
  String get descZenithAuto =>
      'Зенит. Максимальная световая эффективность по расписанию.';

  @override
  String get descZenithManual =>
      'Полный день. Вы используете ручные настройки яркости.';

  @override
  String get descGoldenHourAuto =>
      'Золотой час. Спектр смещен к теплому 2700K для комфорта.';

  @override
  String get descGoldenHourManual =>
      'Золотой час. Цветовая коррекция приостановлена.';

  @override
  String get descTwilightAuto =>
      'Гражданские сумерки. Плавный переход к ночному режиму.';

  @override
  String get descTwilightManual =>
      'Сумерки. Система в ручном режиме пониженной яркости.';

  @override
  String get panelTemperature => 'Температура панели';

  @override
  String get efficiencyRate => 'Эффективность';

  @override
  String get atmosphericClarity => 'Ясность атмосферы';

  @override
  String get high => 'Высокая';

  @override
  String get sunriseLabel => 'Восход';

  @override
  String get sunsetLabel => 'Закат';

  @override
  String appVersion(String version) {
    return 'Версия Solaris $version';
  }

  @override
  String get allMonitors => 'Все мониторы';

  @override
  String get luminosityProfile => 'Профиль освещенности';

  @override
  String get sunPosition => 'Профиль освещенности';

  @override
  String get liveLocation => 'Местоположение';

  @override
  String get solarTelemetry => 'Солнечная телеметрия';

  @override
  String get civilTwilight => 'Гражданские сумерки';

  @override
  String get astronomicalNight => 'Астрономическая ночь';

  @override
  String get surfaceTemp => 'Темп. поверхности';

  @override
  String get spectralIntensity => 'Спектральная интенсивность';

  @override
  String get uvIndex => 'Индекс УФ';

  @override
  String get extreme => 'Экстремальный';

  @override
  String get azimuth => 'АЗИМУТ';

  @override
  String get elevation => 'ВЫСОТА';

  @override
  String get zenith => 'ЗЕНИТ';

  @override
  String get constant => 'Постоянно';

  @override
  String get humidity => 'Влажность';

  @override
  String get airTemp => 'Темп. воздуха';

  @override
  String get settingsSubtitle => 'Настройте параметры вашего циркадного ритма';

  @override
  String get circadianLimits => 'Циркадные пределы';

  @override
  String get circadianLimitsSubtitle => 'Определите границы для автояркости';

  @override
  String get minBrightness => 'Минимальная яркость';

  @override
  String get minBrightnessSubtitle => 'Самый низкий уровень яркости ночью';

  @override
  String get maxBrightness => 'Максимальная яркость';

  @override
  String get maxBrightnessSubtitle => 'Пиковая яркость, достигаемая в зените';

  @override
  String get transBrightness => 'Яркость перехода';

  @override
  String get transBrightnessSubtitle =>
      'Целевой уровень во время Золотого часа и гражданских сумерек';

  @override
  String get realtimeApplyNotice =>
      'Изменения применяются в реальном времени. Используйте панель управления для переключения между ручной и автоматической настройкой.';

  @override
  String get autorun => 'Автозапуск при старте';

  @override
  String get autorunSubtitle =>
      'Автоматически запускать приложение при входе в Windows';

  @override
  String get weatherAdjustmentTitle => 'Влияние погоды';

  @override
  String get weatherAdjustmentSubtitle =>
      'Снижает яркость в облачную или дождливую погоду';

  @override
  String weatherBrightnessReduction(int percent) {
    return 'Погода: снижение яркости на $percent%';
  }

  @override
  String get selectMonitor => 'Выберите монитор';

  @override
  String get presetBrightest => 'Ярчайший';

  @override
  String get presetBright => 'Яркий';

  @override
  String get presetDim => 'Тусклый';

  @override
  String get presetDimmest => 'Темный';

  @override
  String get presetCustom => 'Свой';

  @override
  String get tempCoolest => 'Во льдах';

  @override
  String get tempCool => 'Холодный';

  @override
  String get tempWarm => 'Теплый';

  @override
  String get tempWarmest => 'В огне!';

  @override
  String get tempCustom => 'Свой';

  @override
  String get blueLightFilter => 'Адаптивная цветовая температура';

  @override
  String get blueLightFilterSubtitle =>
      'Автоматически делает цвета теплее вечером для снижения нагрузки на глаза';

  @override
  String get chartModeBrightness => 'Яркость';

  @override
  String get chartModeTemperature => 'Температура';

  @override
  String get disabledInSettings => 'Отключено в настройках';

  @override
  String get enable => 'Включить';

  @override
  String get sleepData => 'Данные о сне';

  @override
  String get sleepDataSubtitle =>
      'Синхронизация с Google Fit для отслеживания циклов отдыха';

  @override
  String get connectGoogleFit => 'Подключить Google Fit';

  @override
  String get disconnectGoogleFit => 'Отключить';

  @override
  String get googleFitConnected => 'Подключено к Google Fit';

  @override
  String get googleFitDisconnected => 'Не подключено';

  @override
  String get lastSyncSuccess => 'Последняя синхронизация: успешно';

  @override
  String get lastSyncFailed => 'Последняя синхронизация: ошибка';

  @override
  String get testSync => 'Проверить синхронизацию';

  @override
  String get sleep => 'Сон (Beta)';

  @override
  String get circadianRegulationBetaNote =>
      'Данный функционал находится в стадии бета-тестирования. Стабильная работа не гарантируется.';

  @override
  String get sleepSubtitle =>
      'Анализируйте режимы сна и синхронизируйте данные';

  @override
  String get googleFitSync => 'Синхронизация Google Fit';

  @override
  String get connectedStatusSmall => 'Подключено';

  @override
  String get lastFetchLabel => 'Последнее обновление:';

  @override
  String get never => 'Никогда';

  @override
  String get signOut => 'Выйти';

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get syncing => 'Синхронизация...';

  @override
  String get verifyingConnection => 'Проверка подключения...';

  @override
  String get connectionError => 'Ошибка подключения';

  @override
  String get hoursAbbreviation => 'ч';

  @override
  String get minutesAbbreviation => 'м';

  @override
  String get sleepRegime => 'Режим сна';

  @override
  String get scatter => 'Разброс';

  @override
  String daysCount(int count) {
    return '$count дн.';
  }

  @override
  String get sleepInDate => 'Дата засыпания';

  @override
  String get detectedRegimes => 'Обнаруженные режимы';

  @override
  String get currentRegime => 'Текущий режим';

  @override
  String get outdated => 'Устарело';

  @override
  String get smartCircadianTitle => 'Умная циркадная подстройка';

  @override
  String get smartCircadianSubtitle =>
      'Динамическая коррекция на основе данных о сне из Google Fit (фаза засыпания, био-утро, недосып)';

  @override
  String get circadianRegulation => 'Циркадная регуляция (Beta)';

  @override
  String get featureWindDown => 'Фаза «Подготовки ко сну» (Wind-down)';

  @override
  String get featureWindDownSubtitle =>
      'Плавное снижение яркости и потепление экрана перед сном';

  @override
  String get featureTimeShift => 'Био-утро (Динамический якорь)';

  @override
  String get featureTimeShiftSubtitle =>
      'Смещение графика под реальное время пробуждения';

  @override
  String get featureSleepPressure => 'Давление сна (Время бодрствования)';

  @override
  String get featureSleepPressureSubtitle =>
      'Плавное диммирование при длительном отсутствии сна';

  @override
  String get featureSleepDebt => 'Компенсация недосыпа';

  @override
  String get featureSleepDebtSubtitle =>
      'Снижение нагрузки при коротком сне (< 6.5ч)';

  @override
  String get influenceBrightness => 'Яркость';

  @override
  String get influenceTemperature => 'Температура';

  @override
  String get featureWindDownInfo =>
      'Готовит организм ко сну, постепенно уменьшая количество синего света и общую освещенность. Это стимулирует выработку мелатонина и облегчает засыпание.';

  @override
  String get featureTimeShiftInfo =>
      'Адаптирует циркадный график под ваше реальное время пробуждения. Если вы проснулись раньше или позже обычного, система плавно сместит пики яркости и температуры, чтобы синхронизироваться с вашим текущим состоянием.';

  @override
  String get featureSleepPressureInfo =>
      'Учитывает время, проведенное без сна. Если вы бодрствуете слишком долго, система начинает плавно снижать яркость, чтобы уменьшить когнитивную нагрузку и подать организму сигнал о необходимости отдыха.';

  @override
  String get featureSleepDebtInfo =>
      'Активируется, если ваш последний сон был короче 6.5 часов. В течение дня система будет поддерживать более комфортный, приглушенный режим освещения, чтобы снизить нагрузку на уставшие глаза и нервную систему.';

  @override
  String get intensity => 'Интенсивность';

  @override
  String get strength => 'Сила';

  @override
  String get brightnessIntensity => 'Интенсивность (яркость)';

  @override
  String get temperatureIntensity => 'Интенсивность (температура)';

  @override
  String get shiftStrength => 'Сила смещения';

  @override
  String circadianImpact(String feature, int impact) {
    return '$feature $impact% к яркости';
  }

  @override
  String get featureWindDownShort => 'Подготовка ко сну';

  @override
  String get featureTimeShiftShort => 'Био-утро';

  @override
  String get featureSleepPressureShort => 'Давление сна';

  @override
  String get featureSleepDebtShort => 'Недосып';

  @override
  String circadianImpactWithTime(
    String feature,
    int impact,
    int time,
    String unit,
  ) {
    return '$feature $impact% к яркости ($time $unit)';
  }

  @override
  String get windDownDuration => 'Длительность подготовки ко сну';

  @override
  String get timeShiftDuration => 'Время адаптации био-утра';

  @override
  String get sleepPressureLimit => 'Порог бодрствования';

  @override
  String get sleepDebtThreshold => 'Норма сна (порог недосыпа)';

  @override
  String get smartExclusions => 'Умные Исключения';

  @override
  String get smartExclusionsSubtitle =>
      'Автоматическая блокировка яркости для игр';

  @override
  String get enableGameMode => 'Включить игровой режим';

  @override
  String get enableGameModeSubtitle =>
      'Блокировать яркость при обнаружении игры';

  @override
  String get lockedBrightness => 'Заблокированная яркость';

  @override
  String get whitelist => 'Белый список';

  @override
  String get whitelistSubtitle =>
      'Приложения, которые всегда включают игровой режим';

  @override
  String get blacklist => 'Черный список';

  @override
  String get blacklistSubtitle => 'Игнорировать, даже если во весь экран';

  @override
  String get sunBase => 'База (Солнце)';

  @override
  String get finalValue => 'Итог';

  @override
  String get brightnessReceipt => 'Чек яркости';

  @override
  String get sleepAnalysisSettings => 'Настройки анализа сна';

  @override
  String get toleranceWindow => 'Окно допустимых отклонений';

  @override
  String get toleranceWindowDesc =>
      'Насколько может отклоняться время отхода ко сну от «опорного» значения, прежде чем будет засчитана аномалия.';

  @override
  String get maxAnomalies => 'Максимум аномалий';

  @override
  String get maxAnomaliesDesc =>
      'Количество последовательных «аномальных» дней, которое допускается алгоритмом до разрыва текущего режима.';

  @override
  String get minRegimeLength => 'Минимальное количество дней';

  @override
  String get minRegimeLengthDesc =>
      'Минимальная продолжительность режима, чтобы он не был объединен с соседним.';

  @override
  String get anchorSize => 'Размер опорного окна';

  @override
  String get anchorSizeDesc =>
      'Количество первых дней для формирования якорного среднего значения.';

  @override
  String get maxSpread => 'Максимальный разброс режима';

  @override
  String get maxSpreadDesc =>
      'Максимальная разница (максимум — минимум) в графике отхода ко сну в минутах. Если превышена, режим разбивается.';

  @override
  String get language => 'Язык';

  @override
  String get english => 'Английский';

  @override
  String get russian => 'Русский';

  @override
  String get ukrainian => 'Украинский';

  @override
  String get globalHotkeys => 'Глобальные горячие клавиши';

  @override
  String get globalHotkeysSubtitle =>
      'Управляйте пресетами и яркостью из любого приложения';

  @override
  String get nextPreset => 'Следующий пресет';

  @override
  String get prevPreset => 'Предыдущий пресет';

  @override
  String get increaseBrightness => 'Ярче';

  @override
  String get decreaseBrightness => 'Темнее';

  @override
  String get brightnessStep => 'Шаг настройки яркости';

  @override
  String get brightnessStepUp => 'Шаг (увеличение)';

  @override
  String get brightnessStepDown => 'Шаг (уменьшение)';

  @override
  String get pressToRecord => 'Нажмите клавиши...';

  @override
  String get hotkeyRecording => 'Запись...';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get toggleAutoBrightness => 'Вкл/Выкл автояркость';

  @override
  String get savePreset => 'Сохранить пресет';

  @override
  String get presetName => 'Название пресета';

  @override
  String get namePresetHint => 'Введите название...';

  @override
  String get deletePreset => 'Удалить пресет';

  @override
  String get deletePresetConfirm =>
      'Вы уверены, что хотите удалить этот пресет?';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String errorWithMsg(String msg) {
    return 'Ошибка: $msg';
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
    return 'Широта: $lat, Долгота: $lon';
  }

  @override
  String get detectingLocation => 'Определение местоположения...';

  @override
  String get coordinatesUnavailable => 'Координаты недоступны';

  @override
  String get north => 'С';

  @override
  String get south => 'Ю';

  @override
  String get east => 'В';

  @override
  String get west => 'З';

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
  String get currentPosition => 'Текущее положение';

  @override
  String lockedBrightnessValue(int value) {
    return '$value%';
  }

  @override
  String get gameModeHint => 'напр. game.exe';

  @override
  String get about => 'О программе';

  @override
  String get legal => 'Юридическая информация';

  @override
  String get disclaimerTitle => 'Отказ от ответственности';

  @override
  String get disclaimerText =>
      'ОТКАЗ ОТ ОТВЕТСТВЕННОСТИ: Данное ПО предоставляется на условиях «КАК ЕСТЬ», БЕЗ КАКИХ-ЛИБО ГАРАНТИЙ. Разработчик не несет ответственности за аппаратные сбои, мерцание, повреждения мониторов, потерю данных или физический дискомфорт, возникшие в результате использования программы. Программа взаимодействует с оборудованием через протокол DDC/CI; пользователь берет на себя полную ответственность за проверку совместимости. Ни при каких обстоятельствах автор не несет ответственности за косвенные или случайные убытки.';

  @override
  String get viewLicenses => 'Лицензии';

  @override
  String get close => 'Закрыть';

  @override
  String get multiMonitorOffsets => 'Линковка и Смещение';

  @override
  String get multiMonitorOffsetsSubtitle =>
      'Индивидуальная подстройка яркости для каждого монитора';

  @override
  String get brightnessOffset => 'Смещение яркости';

  @override
  String get linkAndOffset => 'Линковка и Смещение';

  @override
  String get offsetFormula => 'Итог = Общая + Смещение';

  @override
  String get weatherAnimations => 'Погодные эффекты';

  @override
  String get showRain => 'Дождь';

  @override
  String get showSnow => 'Снег';

  @override
  String get showThunder => 'Гроза';

  @override
  String get showClouds => 'Облачность';

  @override
  String get weatherSettingsSubtitle =>
      'Настройте видимость погодных условий на карте';
}
