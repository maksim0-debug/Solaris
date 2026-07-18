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
  String get autoDetectSubtitle =>
      'Автоматически определять местоположение по системным службам или IP';

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
  String get windSpeed => 'Скорость ветра';

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
  String get settingsSubtitle =>
      'Настройте параметры вашего циркадного ритма. Вы можете перетаскивать пресеты, зажав левую кнопку мыши, а также переименовать или удалить их, нажав правую кнопку мыши.';

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
  String get startupMode => 'Режим запуска';

  @override
  String get startupModeTray => 'В трее';

  @override
  String get startupModeMinimized => 'Свернутым';

  @override
  String get weatherAdjustmentTitle => 'Коррекция по погоде';

  @override
  String get weatherAdjustmentSubtitle =>
      'Автоматическая коррекция экрана в зависимости от погодных условий';

  @override
  String get weatherBrightnessAdjustmentTitle => 'Адаптация яркости по погоде';

  @override
  String get weatherBrightnessAdjustmentSubtitle =>
      'Снижение яркости в пасмурную или дождливую погоду для комфорта глаз';

  @override
  String get weatherTemperatureAdjustmentTitle =>
      'Адаптация температуры по погоде';

  @override
  String get weatherTemperatureAdjustmentSubtitle =>
      'Снижение цветовой температуры в пасмурную или дождливую погоду для отдыха глаз';

  @override
  String get temperatureRegulationTitle => 'Регуляция температуры';

  @override
  String get temperatureBreakdownBase => 'Базовая температура кривой';

  @override
  String get temperatureBreakdownWeather => 'Погода (снижение)';

  @override
  String get temperatureBreakdownSleepPressure => 'Давление сна';

  @override
  String get temperatureBreakdownWindDown => 'Подготовка ко сну';

  @override
  String get temperatureBreakdownSleepDebt => 'Компенсация недосыпа';

  @override
  String get temperatureBreakdownFinal => 'Итоговая температура';

  @override
  String get weatherIntensity => 'Интенсивность коррекции';

  @override
  String get weatherAdjustmentIntensitySubtitle =>
      'Управляет тем, насколько сильно погода влияет на яркость экрана';

  @override
  String get weatherProvider => 'Провайдер погоды';

  @override
  String get weatherProviderAuto => 'Автоматически';

  @override
  String get weatherProviderWeatherApi => 'WeatherAPI.com';

  @override
  String get weatherProviderOpenMeteo => 'Open-Meteo.com';

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
  String get circadianRegulation => 'Регуляция яркости';

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
  String get sunBase => 'Базовая яркость кривой';

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
  String windSpeedFormat(String value) {
    return '$value км/ч';
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
  String get offlineReasonMissingToken =>
      'Токен доступа Mapbox не настроен. Используется резервное имя часового пояса.';

  @override
  String get offlineReasonApiError =>
      'Не удалось получить название города через API. Используется резервное имя часового пояса.';

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
  String get legalSubtitle => 'Юридическая информация и конфиденциальность';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get privacyPolicySubtitle =>
      'Узнайте о том, как мы обрабатываем ваши данные и интеграции с Google Fit.';

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

  @override
  String get lastUpdated => 'Обновлено';

  @override
  String lastUpdatedFormat(String time) {
    return 'Обновлено в $time';
  }

  @override
  String get mapSettings => 'Настройки карты';

  @override
  String get mapStyle => 'Стиль карты';

  @override
  String get mapStyleAuto => 'Автоматически';

  @override
  String get mapStyleDay => 'День';

  @override
  String get mapStyleNight => 'Ночь';

  @override
  String get searchPlaceholder => 'Поиск настроек (яркость, сон, клавиши)...';

  @override
  String noResultsFound(String query) {
    return 'Ничего не найдено по запросу \'$query\'';
  }

  @override
  String get tags_brightness =>
      'свет, яркость, подсветка, экран, монитор, темнее, светлее, глаза, дисплей, панель, уровень';

  @override
  String get tags_auto_brightness =>
      'автоматически, адаптивно, датчик, график, солнце, авто, динамика, линковка, синхронизация, связь';

  @override
  String get tags_auto_temperature =>
      'цвет, тепло, синий свет, фильтр, ночь, вечер, кельвины, температура, авто, спектр, ночной режим';

  @override
  String get tags_schedule =>
      'график, кривая, цикл, утро, день, вечер, ночь, диаграмма, расписание, профиль, план, карта';

  @override
  String get tags_sleep =>
      'гугл фит, отдых, подъем, ритм, сон, анализ, данные, будильник, режим, трекер';

  @override
  String get tags_smart_circadian =>
      'умный, адаптивный, био, динамика, давление сна, засыпание, био-утро, долг сна, бета, тест, настройка';

  @override
  String get tags_wind_down =>
      'мелатонин, вечер, подготовка, покой, затухание, теплый, красный, засыпание, релакс';

  @override
  String get tags_game_mode =>
      'игры, полный экран, приоритет, блок, производительность, исключения, игра, приложение';

  @override
  String get tags_circadian_limits =>
      'мин, макс, диапазон, границы, лимит, яркость, предел, ограничения, кривая, точки, якорь';

  @override
  String get tags_autorun =>
      'старт, запуск, виндовс, автозапуск, загрузка, авто, запуск';

  @override
  String get tags_weather =>
      'дождь, облака, солнце, гроза, снег, видимость, погода, снижение, ясность, атмосфера';

  @override
  String get tags_hotkeys =>
      'сочетание, клавиши, клавиатура, команда, быстро, хоткеи, привязка, глобальные, кнопки';

  @override
  String get tags_language =>
      'язык, русский, английский, украинский, перевод, локализация, наречие';

  @override
  String get tags_location =>
      'gps, карта, координаты, город, гео, позиция, локация, широта, долгота';

  @override
  String get tags_location_auto =>
      'gps, определить, ip, гео, авто, позиция, автоматически';

  @override
  String get tags_multi_monitor =>
      'монитор, дисплей, экран, несколько, линковка, смещение, раздельно, индивидуально';

  @override
  String get tags_weather_animations =>
      'анимация, визуально, дождь, снег, гроза, эффект, облака, включить, карта';

  @override
  String get tags_sleep_analysis =>
      'порог, аномалии, среднее, режим, разброс, анализ, сон, настройки';

  @override
  String get tags_legal =>
      'юридический, лицензия, отказ, ответственность, железо, инфо, о программе';

  @override
  String get tags_google_fit =>
      'гугл фит, облако, синхронизация, аккаунт, авторизация, гугл, фит, трекер сна, данные';

  @override
  String get tags_time_shift =>
      'био утро, био-утро, пробуждение, смещение, график, динамический, якорь, бодрствование, циркадный';

  @override
  String get tags_sleep_pressure =>
      'давление сна, диммирование, время бодрствования, длительность, лимит, часы, усталость';

  @override
  String get tags_sleep_debt =>
      'долг сна, недосып, компенсация, короткий сон, дефицит отдыха, восстановление, приглушенный режим';

  @override
  String get tags_local_sleep_integration =>
      'локальная интеграция сна, ipc сервер, http сервер, api, локалхост, порт, синхронизация сна';

  @override
  String get tags_weather_brightness =>
      'яркость по погоде, облачность, дождь, гроза, солнце, регулировка яркости';

  @override
  String get tags_weather_temperature =>
      'температура по погоде, теплый, холодный, синий свет, облачность, гроза, регулировка цвета';

  @override
  String get mapIssueDetected => 'Обнаружена проблема с картой';

  @override
  String get mapboxTokenMissing =>
      'Токен доступа Mapbox отсутствует или недействителен.';

  @override
  String get noInternetAccess =>
      'Не удалось связаться с серверами Mapbox. Пожалуйста, проверьте подключение к интернету.';

  @override
  String get vcRedistMissing =>
      'Отсутствует Visual C++ Redistributable (msvcp140.dll). Это необходимо для корректного отображения карт.';

  @override
  String get downloadVcRedist => 'Скачать Visual C++ Redistributable';

  @override
  String get retryDiagnostics => 'Повторить диагностику';

  @override
  String get mapboxServers => 'Серверы Mapbox';

  @override
  String get mapboxReachabilityDesc => 'Серверы Mapbox недоступны.';

  @override
  String get sslIssueHint =>
      'Похоже на проблему с сертификатами. Чистые установки Windows 10 часто не имеют современных корневых сертификатов. Попробуйте запустить Центр обновления Windows.';

  @override
  String get missingRedistHint =>
      'Отсутствуют компоненты Visual C++ (2015-2022). Они не предустановлены в чистой Windows. Пожалуйста, установите этот пакет.';

  @override
  String get fixSslCert => 'Исправить SSL сертификат';

  @override
  String get sslFixInstruction =>
      'Для исправления нужно инициировать обновление корневых сертификатов в Windows. Нажатие кнопки ниже откроет защищенную ссылку в вашем браузере — сам визит на эту страницу часто заставляет Windows загрузить недостающий сертификат.';

  @override
  String get trayOpen => 'Открыть Solaris';

  @override
  String get trayExit => 'Выход';

  @override
  String get sleepIntegrationTitle => 'Интеграция сна (Локальный API)';

  @override
  String get sleepIntegrationSubtitle =>
      'Связь со сторонними трекерами сна и API';

  @override
  String get enableLocalIpcServer => 'Включить локальный API сервер';

  @override
  String get enableLocalIpcServerSubtitle =>
      'Позволяет принимать сессии сна на порту localhost';

  @override
  String get serverPort => 'Порт сервера';

  @override
  String get serverPortSubtitle =>
      'При изменении сервер перезапустится автоматически';

  @override
  String serverRunningStatus(int port) {
    return 'Сервер запущен на порту $port';
  }

  @override
  String get serverStoppedStatus => 'Сервер остановлен или порт занят';

  @override
  String serverPortBusyAlertTitle(int port) {
    return 'Порт $port занят или недоступен';
  }

  @override
  String serverPortBusyAlertExplanation(int port) {
    return 'Solaris не удалось запустить локальный API-сервер, так как порт $port в данный момент используется другим приложением или службой на вашем компьютере.';
  }

  @override
  String serverPortBusyAlertSolution(Object port) {
    return 'Чтобы решить эту проблему, вы можете ввести другой номер порта в поле выше (например, 45322) или закрыть приложение, которое использует порт $port.';
  }

  @override
  String get sleepIntegrationHelpTitle => 'Руководство по интеграции сна';

  @override
  String get sleepIntegrationHelpIntro =>
      'Эта интеграция позволяет сторонним программам для отслеживания сна, умным будильникам или скриптам автоматизации отправлять данные о сне напрямую в это приложение через безопасное локальное соединение.';

  @override
  String get sleepIntegrationHelpSectionWhat => 'Что это такое?';

  @override
  String get sleepIntegrationHelpSectionWhatText =>
      'Solaris динамически регулирует яркость и цветовую температуру ваших мониторов на основе циркадных ритмов. Для этого приложению нужны точные данные о сне. Локальный API-сервер позволяет получать данные без задержек и офлайн от программ, запущенных на вашем ПК.';

  @override
  String get sleepIntegrationHelpSectionHow => 'Как это работает';

  @override
  String get sleepIntegrationHelpSectionHowText =>
      '1. При включении приложение запускает мини-сервер на вашем ПК, который слушает только локальные запросы (127.0.0.1).\n2. Сторонние программы отправляют сессии сна (в формате JSON) или статус сна в реальном времени (спит / бодрствует).\n3. Приложение обрабатывает эти данные и автоматически корректирует профиль экрана.';

  @override
  String get sleepIntegrationHelpSectionConfig => 'Настройка';

  @override
  String get sleepIntegrationHelpSectionConfigText =>
      '• Включите тумблер «Включить локальный API сервер».\n• Оставьте порт по умолчанию (45321), если он не занят другим приложением.\n• Настройте ваше ПО для отправки POST-запросов на адреса:\n  - История сна: http://127.0.0.1:45321/api/sleep/sessions\n  - Статус реального времени: http://127.0.0.1:45321/api/sleep/status';

  @override
  String get sleepIntegrationHelpSectionDeduplication => 'Дедупликация данных';

  @override
  String get sleepIntegrationHelpSectionDeduplicationText =>
      'Локальные данные имеют абсолютный приоритет. Если сессия из Google Fit пересекается по времени с локальной сессией (с погрешностью в 1 час), запись Google Fit автоматически удаляется, предотвращая наложение и двойные записи.';

  @override
  String get sleepIntegrationHelpSectionSecurity =>
      'Безопасность и приватность';

  @override
  String get sleepIntegrationHelpSectionSecurityText =>
      'Сервер работает исключительно на локальном адресе 127.0.0.1 и недоступен из интернета или локальной сети. Ваши данные о сне остаются только на вашем устройстве.';

  @override
  String get sleepIntegrationHelpSectionFormat => 'Формат JSON-данных';

  @override
  String get sleepIntegrationHelpSectionFormatText =>
      'Приложение ожидает данные в формате JSON. Детали схемы:\n\n1. Сессии сна (POST на /api/sleep/sessions)\nОжидаемые данные: Массив объектов сессий сна JSON.\nКаждый объект содержит:\n• id: строка (уникальный идентификатор сессии)\n• startTime: строка (дата/время ISO 8601, например, \"2026-07-17T00:30:00Z\")\n• endTime: строка (дата/время ISO 8601, например, \"2026-07-17T08:00:00Z\")\n• title: строка (опциональное название сессии)\n• source: строка (опционально, по умолчанию \"local_api\")\n\n2. Текущий статус сна (POST на /api/sleep/status)\nОжидаемые данные: Объект JSON, содержащий:\n• is_sleeping: логическое значение (true, если пользователь спит, false — если бодрствует)';

  @override
  String get mapboxTokenMissingTooltip =>
      'Токен доступа Mapbox отсутствует. Настройте его в Настройках (раздел «API Ключи»).';

  @override
  String get weatherApiKeyMissingWarning =>
      'Провайдер WeatherAPI отключен. Настройте WEATHER_API_KEY в Настройках (раздел «API Ключи»).';

  @override
  String get googleFitKeysMissingWarning =>
      'Интеграция с Google Fit отключена. Настройте GOOGLE_CLIENT_ID и GOOGLE_CLIENT_SECRET в Настройках (раздел «API Ключи»).';

  @override
  String get apiKeysTitle => 'API Ключи';

  @override
  String get apiKeysSubtitle =>
      'Настройка персональных ключей доступа к сервисам';

  @override
  String get customWeatherApiKey => 'Персональный WeatherAPI ключ';

  @override
  String get customMapboxToken => 'Персональный Mapbox токен';

  @override
  String get customGoogleClientId => 'Персональный Google Client ID';

  @override
  String get customGoogleClientSecret => 'Персональный Google Client Secret';

  @override
  String get apiKeysHelpText =>
      'Эта версия Solaris собрана без встроенных ключей. Чтобы использовать функции карт, детальной погоды или синхронизации Google Fit, укажите свои ключи здесь. Они будут обфусцированы и сохранены локально на вашем ПК.';

  @override
  String get apiKeysHelpTextWithDefaults =>
      'Эта версия Solaris содержит встроенные ключи по умолчанию. При желании вы можете переопределить любой из них, указав здесь свой собственный ключ. Пользовательские ключи будут обфусцированы и сохранены локально на вашем ПК.';

  @override
  String get apiKeysGetKeyLink => 'Получить ключ';

  @override
  String get googleFitReleaseWarningTitle => 'Релизная версия с GitHub';

  @override
  String get googleFitReleaseWarningBody =>
      'Эта официальная версия приложения скачана с GitHub и не содержит встроенного Google Client ID и Client Secret из-за строгой политики безопасности Google в отношении данных о здоровье (Restricted Scopes). Публичным приложениям запрещено получать доступ к истории сна без прохождения дорогостоящего независимого аудита безопасности.\n\nЧтобы включить синхронизацию:\n1. Введите свои собственные Google Client ID и Client Secret в разделе настроек «API Ключи».\n2. Либо соберите приложение из исходников с вашими ключами в файле `.env`.';

  @override
  String get googleFitLocalWarningTitle => 'Отсутствуют ключи Google Fit';

  @override
  String get googleFitLocalWarningBody =>
      'Для интеграции с Google Fit требуются учетные данные Google OAuth.\n\nЧтобы включить синхронизацию:\n1. Введите свои собственные Google Client ID и Client Secret в разделе настроек «API Ключи».\n2. Либо настройте локальный файл `.env` и пересоберите приложение.';

  @override
  String get goToSettings => 'В настройки';

  @override
  String get apiKeyActiveBuiltIn => 'Встроенный активен';

  @override
  String get apiKeyActiveCustom => 'Пользовательский активен';

  @override
  String get apiKeyNotConfigured => 'Ключ не настроен';

  @override
  String get saveKey => 'Сохранить';

  @override
  String get clearKey => 'Очистить';

  @override
  String get saved => 'Сохранено';
}
