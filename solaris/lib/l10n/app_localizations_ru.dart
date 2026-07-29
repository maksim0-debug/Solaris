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
    return 'Система перейдет на теплый спектр примерно через $hours ч.';
  }

  @override
  String get goldenHourNotice =>
      'Сейчас Золотой час. Включен мягкий теплый спектр.';

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
      'Ночной цикл. Мягкая подсветка заботится о зрении в темноте.';

  @override
  String get descDeepNightManual =>
      'Глубокая ночь. Авторегулировка спит, ожидая первых лучей рассвета.';

  @override
  String get descDawnAuto =>
      'Наступает рассвет. Экран плавно просыпается и переходит на дневной режим.';

  @override
  String get descDawnManual =>
      'Небо светлеет. Вы управляете яркостью вручную в ожидании восхода.';

  @override
  String get descMorningSpikeAuto =>
      'Первые лучи солнца. Яркость плавно растет, помогая вам проснуться.';

  @override
  String get descMorningSpikeManual =>
      'Предрассветный подъем. Вы перешли на ручное управление яркостью.';

  @override
  String get descZenithAuto =>
      'Солнце в зените. Установлена оптимальная яркость для дневной работы.';

  @override
  String get descZenithManual =>
      'Разгар дня. Автоподстройка отключена, яркость задана вручную.';

  @override
  String get descGoldenHourMorningBothAuto =>
      'Утренний золотой час. Мягкий теплый свет и яркость настроены для легкого начала дня.';

  @override
  String get descGoldenHourMorningTempOnly =>
      'Утренний золотой час. Экран переведен в теплый спектр для комфорта ваших глаз.';

  @override
  String get descGoldenHourMorningBrightOnly =>
      'Утренний золотой час. Яркость адаптируется под мягкий свет раннего утра.';

  @override
  String get descGoldenHourMorningManual =>
      'Утренний золотой час. Авторегулировка отдыхает, параметры установлены вручную.';

  @override
  String get descGoldenHourEveningBothAuto =>
      'Вечерний золотой час. Мягкий теплый свет и яркость адаптированы для уютного вечера.';

  @override
  String get descGoldenHourEveningTempOnly =>
      'Вечерний золотой час. Экран переходит в теплый спектр, снижая нагрузку перед сном.';

  @override
  String get descGoldenHourEveningBrightOnly =>
      'Вечерний золотой час. Яркость плавно снижается под стать заходящему солнцу.';

  @override
  String get descGoldenHourEveningManual =>
      'Вечерний золотой час. Авторегулировка отдыхает, параметры установлены вручную.';

  @override
  String get descTwilightAuto =>
      'Сгущаются сумерки. Экран плавно переходит на уютный ночной режим.';

  @override
  String get descTwilightManual =>
      'На дворе сумерки. Автоподстройка отключена, яркость установлена вручную.';

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
      'Готовит организм ко сну, постепенно уменьшая количество синего света и общую освещенность. Это помогает сохранить естественный уровень мелатонина и облегчает засыпание.';

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
  String get autoLocationFailedTooltip =>
      'Автоопределение геопозиции не сработало. Используется системный часовой пояс (погодные эффекты отключены). Попробуйте выбрать местоположение на карте или ввести координаты вручную.';

  @override
  String get systemTimezoneFallbackTitle => 'Системный часовой пояс';

  @override
  String get coordinatesNotSet => 'Координаты не определены';

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
  String get errorLoadingPrivacyPolicy =>
      'Ошибка загрузки политики конфиденциальности';

  @override
  String get disclaimerTitle => 'Отказ от ответственности';

  @override
  String get disclaimerText =>
      'ОТКАЗ ОТ ОТВЕТСТВЕННОСТИ: Данное программное обеспечение предоставляется на условиях «КАК ЕСТЬ», БЕЗ КАКИХ-ЛИБО ГАРАНТИЙ, явных или подразумеваемых. Ни при каких обстоятельствах разработчик или автор не несут ответственности за любые аппаратные сбои, мерцание, повреждения мониторов, физический дискомфорт, утерю данных, компрометацию системы безопасности, несанкционированный доступ к приложению или утечку ваших персональных API-ключей и учетных данных. Используя Solaris, вы подтверждаете, что делаете это на свой страх и риск, и принимаете на себя полную ответственность за совместимость оборудования, хранение ключей, а также за любые финансовые обязательства, расходы или убытки, возникшие в результате компрометации ключей, превышения квот и лимитов сторонних API или взлома системы. Автор не несет ответственности за любой прямой, косвенный, случайный или последующий ущерб.';

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

  @override
  String get dpapiErrorTitle => 'Защита данных Windows';

  @override
  String get dpapiErrorPasswordChanged =>
      'Учетные данные или пароль вашей учетной записи Windows были изменены. В целях безопасности мы не смогли расшифровать сохраненные API-ключи. Пожалуйста, введите их заново в Настройках.';

  @override
  String get dpapiErrorInvalidData =>
      'Сохраненные защищенные данные настроек повреждены. Пожалуйста, введите ваши API-ключи заново.';

  @override
  String get dpapiErrorGeneric =>
      'Произошла ошибка подсистемы безопасности Windows при расшифровке настроек. Пожалуйста, введите ваши API-ключи заново.';

  @override
  String get dpapiErrorActionOk => 'ОК';

  @override
  String get dpapiErrorActionSettings => 'В настройки';

  @override
  String get invalidCoordinatesError =>
      'Некорректные координаты. Широта должна быть от -90 до 90, долгота от -180 до 180.';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String updateAvailableVersion(Object version) {
    return 'Обновление: v$version ⬆';
  }

  @override
  String updateCurrentVersion(Object version) {
    return 'Текущая версия: v$version';
  }

  @override
  String updateDownloadingPercent(Object percent) {
    return 'Скачивание: $percent% ↓';
  }

  @override
  String get updateVerifying => 'Проверка целостности...';

  @override
  String get updateVerified => 'Проверено';

  @override
  String get updateIntegrityError => 'Ошибка целостности';

  @override
  String get updateReady => 'Готово к установке ✓';

  @override
  String get updateInstallRestart => 'Установить и перезапустить';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateRetry => 'Повторить';

  @override
  String get updateError => 'Ошибка обновления ⚠';

  @override
  String get updateReleaseNotes => 'Что нового';

  @override
  String updateFileSize(Object size) {
    return 'Размер: $size';
  }

  @override
  String get updateViewOnGithub => 'Релиз на GitHub';

  @override
  String get updateRestartWarning =>
      'Приложение будет перезапущено для установки обновления.';

  @override
  String get updateCheckForUpdates => 'Проверить обновления';

  @override
  String get updateChecking => 'Проверка обновлений...';

  @override
  String get updateSuccessTitle => 'Приложение обновлено';

  @override
  String updateSuccessBody(Object version) {
    return 'Solaris успешно обновлен до версии $version.';
  }

  @override
  String get updateRolledBackTitle => 'Откат обновления';

  @override
  String updateRolledBackBody(Object reason) {
    return 'Обновление не удалось. Приложение восстановлено до предыдущей версии.\nПричина: $reason';
  }

  @override
  String get updateFailedTitle => 'Ошибка обновления';

  @override
  String updateFailedBody(Object reason) {
    return 'Произошла ошибка при установке обновления.\nДетали: $reason';
  }

  @override
  String get autoUpdatesTitle => 'Автоматические обновления';

  @override
  String get autoUpdatesSubtitle =>
      'Автоматически проверять наличие обновлений при запуске и в фоновом режиме';

  @override
  String get tags_auto_updates =>
      'обновления,автообновления,версия,github,updates,autoupdate';

  @override
  String get customBuildNotice =>
      'Пользовательская сборка: автоматическая проверка отключена по умолчанию';

  @override
  String get customBuildWarningTitle => 'Предупреждение об обновлении';

  @override
  String get customBuildWarningBody =>
      'При обновлении с неофициальной версии на официальную вы можете потерять сохраненные API-ключи (Mapbox, WeatherAPI, Google Fit), а также созданные ключи Solaris Control API. Обязательно скопируйте и сохраните их перед обновлением.';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get dialogOk => 'ОК';

  @override
  String get updateNoUpdatesTitle => 'Обновлений не найдено';

  @override
  String get updateNoUpdatesFound =>
      'Обновлений не найдено, у вас актуальная версия.';

  @override
  String get updateInstallingTitle => 'Обновление...';

  @override
  String get updateInstallingStatus => 'Установка обновления...';

  @override
  String get updateDownloadingPackage => 'Загрузка пакета обновления...';

  @override
  String get updateBackgroundNotice =>
      'Вы можете закрыть это окно. Процесс продолжится в фоновом режиме.';

  @override
  String get apiTitle => 'Solaris Control API v1';

  @override
  String apiStatusActiveLan(int port) {
    return 'Активен (LAN: 0.0.0.0:$port)';
  }

  @override
  String apiStatusActiveLocalhost(int port) {
    return 'Активен (Localhost: 127.0.0.1:$port)';
  }

  @override
  String get apiStatusDisabled => 'Отключен';

  @override
  String get apiNetworkAccessMode => 'Режим сетевого доступа';

  @override
  String get apiModeLocalhost => 'Только Localhost (127.0.0.1)';

  @override
  String get apiModeLan => 'Доступ по LAN (0.0.0.0)';

  @override
  String get apiFirewallUacError =>
      'Ошибка: Отказано в разрешении UAC Windows Firewall. Доступ по LAN отменен.';

  @override
  String get apiServerPort => 'Порт API сервера';

  @override
  String get apiDocumentation => 'Интерактивная документация';

  @override
  String get apiOpenSwagger => 'Открыть Swagger UI';

  @override
  String apiOpenDocsError(String error) {
    return 'Не удалось открыть документацию: $error';
  }

  @override
  String get apiAccessKey => 'Ключ доступа API (X-API-Key)';

  @override
  String get apiTokenHintRequiredLan => 'Обязателен для LAN';

  @override
  String get apiTokenHintOptionalLocalhost => 'Опционально для Localhost';

  @override
  String get apiCopyKeyTooltip => 'Скопировать ключ API';

  @override
  String get apiKeyCopied => 'Ключ API скопирован в буфер обмена';

  @override
  String get apiGenerateKeyTooltip => 'Сгенерировать новый ключ';

  @override
  String get apiKeyGenerated => 'Сгенерирован новый ключ API';

  @override
  String get webhooksTitle => 'Исходящие вебхуки';

  @override
  String webhooksSubtitle(int count, int queueCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count настроено',
      few: '$count настроено',
      one: '1 настроен',
    );
    return '$_temp0 | Очередь WAL: $queueCount';
  }

  @override
  String get webhooksViewDlqTooltip =>
      'Просмотреть очередь необработанных сообщений (DLQ)';

  @override
  String get webhooksAddButton => 'Добавить вебхук';

  @override
  String get webhooksEmptyMessage =>
      'Исходящие вебхуки не настроены.\nНажмите \"Добавить вебхук\" для интеграции с Home Assistant, Node-RED или n8n.';

  @override
  String get webhooksDefaultName => 'Вебхук';

  @override
  String webhooksEventsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count событий',
      few: '$count события',
      one: '1 событие',
    );
    return '$_temp0';
  }

  @override
  String get webhooksSendTestPingTooltip => 'Отправить тестовый запрос';

  @override
  String get webhooksSendingTestPing => 'Отправка тестового запроса...';

  @override
  String get webhooksTestPingSuccess => 'Тестовый запрос успешно доставлен!';

  @override
  String get webhooksTestPingFailed => 'Не удалось доставить тестовый запрос.';

  @override
  String get webhooksEditTooltip => 'Редактировать вебхук';

  @override
  String get webhooksDeleteTooltip => 'Удалить вебхук';

  @override
  String get webhooksAddTitle => 'Добавить исходящий вебхук';

  @override
  String get webhooksEditTitle => 'Редактировать вебхук';

  @override
  String get webhooksUrlLabel => 'URL целевого вебхука *';

  @override
  String get webhooksNameLabel => 'Название (Опционально)';

  @override
  String get webhooksSecretLabel => 'Секретный ключ HMAC (Опционально)';

  @override
  String get webhooksSecretHint => 'Секрет для проверки X-Solaris-Signature';

  @override
  String get webhooksSubscribedEvents => 'Подписки на события:';

  @override
  String get webhooksSelectAll => 'Выбрать все';

  @override
  String get webhooksDeselectAll => 'Снять выбор со всех';

  @override
  String get webhooksInvalidUrlError =>
      'Пожалуйста, введите корректный абсолютный URL (например, http://...)';

  @override
  String get webhooksSaveChangesButton => 'Сохранить изменения';

  @override
  String webhooksDlqTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Очередь необработанных сообщений ($count)',
      few: 'Очередь необработанных сообщений ($count)',
      one: 'Очередь необработанных сообщений (1)',
    );
    return '$_temp0';
  }

  @override
  String get webhooksDlqEmpty =>
      'Очередь необработанных сообщений пуста! Все вебхуки успешно доставлены.';

  @override
  String webhooksDlqEvent(String eventName, String url) {
    return 'Событие: $eventName -> $url';
  }

  @override
  String webhooksDlqDetails(int count, String error, String id) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count попыток',
      few: '$count попытки',
      one: '1 попытка',
    );
    return '$_temp0 | Ошибка: $error\nID доставки: $id';
  }

  @override
  String get webhooksClearDlq => 'Очистить DLQ';

  @override
  String get apiPermissionsDialogTitle =>
      'Права доступа API и гранулярный контроль';

  @override
  String get apiPermissionsReadOnlyLabel => 'Режим «Только чтение» (Read-Only)';

  @override
  String get apiPermissionsReadOnlyHint =>
      'Если включено, все управляющие API-запросы (POST/PUT/DELETE) блокируются с кодом HTTP 403 Forbidden.';

  @override
  String get apiPermissionsDataSharingSection =>
      'Разрешения на передачу данных (Чтение)';

  @override
  String get apiPermissionsAllowMonitors => 'Мониторы и состояние яркости';

  @override
  String get apiPermissionsAllowSolar => 'Солнечные и астрономические данные';

  @override
  String get apiPermissionsAllowWeather =>
      'Погодные корректировки и данные провайдера';

  @override
  String get apiPermissionsAllowSleep => 'Метрики сна и циркадного ритма';

  @override
  String get apiPermissionsAllowCircadian =>
      'Состояние системы Smart Circadian';

  @override
  String get apiPermissionsControlCategoriesSection =>
      'Разрешенные категории команд (Управление)';

  @override
  String get apiPermissionsCategoryMonitors =>
      'Мониторы (яркость, температура, смещения)';

  @override
  String get apiPermissionsCategoryPresets => 'Пресеты и профили яркости';

  @override
  String get apiPermissionsCategoryCircadian =>
      'Циркадный ритм и авто-настройки';

  @override
  String get apiPermissionsCategoryGaming => 'Игровой режим и белые списки ПО';

  @override
  String get apiPermissionsCategoryEnvironment =>
      'Окружение и погодные настройки';

  @override
  String get apiPermissionsCategorySleep => 'Действия сна и обновление статуса';

  @override
  String get apiPermissionsCategorySystem =>
      'Системные действия (вебхуки, анимации)';

  @override
  String get apiPermissionsConfigureButton => 'Настроить права API...';

  @override
  String get apiPermissionsSummaryReadOnly => 'Режим «Только чтение» активен';

  @override
  String apiPermissionsSummaryCustom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Разрешено $count категорий',
      few: 'Разрешено $count категории',
      one: 'Разрешена $count категория',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysManagementDialogTitle => 'Управление ключами доступа API';

  @override
  String get apiKeysManagementSubtitle =>
      'Принцип наименьших привилегий: индивидуальные ключи для внешних интеграций';

  @override
  String apiKeysActiveCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Настроено $count активных ключей',
      few: 'Настроено $count активных ключа',
      one: 'Настроен $count активный ключ',
      zero: 'Настроено 0 активных ключей',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysManageButton => 'Управление API-ключами...';

  @override
  String get apiKeysCreateButton => 'Создать новый ключ';

  @override
  String get apiKeysTableHeaderName => 'Название';

  @override
  String get apiKeysTableHeaderScopes => 'Права (Scopes)';

  @override
  String get apiKeysTableHeaderCreated => 'Создан';

  @override
  String get apiKeysTableHeaderActions => 'Действия';

  @override
  String apiKeysReadOnlyChip(int count) {
    return 'Read-Only ($count/7)';
  }

  @override
  String apiKeysActiveScopesChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count из 7 категорий',
      few: '$count из 7 категорий',
      one: '1 из 7 категорий',
    );
    return '$_temp0';
  }

  @override
  String get apiKeysCopySuccessSnackbar =>
      'Токен API-ключа скопирован в буфер обмена!';

  @override
  String get apiKeysRegenerateConfirmTitle => 'Перегенерировать токен?';

  @override
  String get apiKeysRegenerateConfirmMessage =>
      'Все устройства и сервисы, использующие текущий токен, потеряют доступ к API.';

  @override
  String get apiKeysDeleteConfirmTitle => 'Отозвать API-ключ?';

  @override
  String apiKeysDeleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите отозвать ключ «$name»? Это действие нельзя отменить.';
  }

  @override
  String apiKeysDpapiWarningBanner(String name) {
    return 'Токен ключа «$name» автоматически пересоздан из-за смены пароля Windows. Скопируйте новый токен в ваши внешние устройства.';
  }

  @override
  String get apiKeysDpapiBadge => 'Токен сброшен (смена пароля ОС)';

  @override
  String get apiKeysSoleKeyDeleteWarning =>
      'Нельзя удалить единственный API-ключ.';

  @override
  String get createApiKeyDialogTitle => 'Создание API-ключа';

  @override
  String get createApiKeyNameFieldLabel => 'Название ключа';

  @override
  String get requireLocalTokenLabel =>
      'Требовать авторизацию для локальных запросов';

  @override
  String get requireLocalTokenSubtitle =>
      'Запросы с 127.0.0.1 без API-токена будут отклоняться со статусом HTTP 401 Unauthorized';

  @override
  String get showNewTokenDialogTitle => 'Ваш новый API-ключ';

  @override
  String get showNewTokenWarning =>
      'Скопируйте этот токен прямо сейчас. Из соображений безопасности он больше никогда не будет показан в открытом виде.';

  @override
  String get copyTokenButton => 'Скопировать токен';

  @override
  String get savedTokenButton => 'Я сохранил токен';

  @override
  String get deleteSleepSessionTitle => 'Удалить сессию сна';

  @override
  String get deleteSleepSegmentTitle => 'Удалить сегмент сна';

  @override
  String deleteSleepSessionConfirm(String dateRange) {
    return 'Вы уверены, что хотите удалить эту сессию сна ($dateRange)?';
  }

  @override
  String deleteSleepSegmentConfirm(String timeRange) {
    return 'Вы уверены, что хотите удалить этот сегмент сна ($timeRange)?';
  }

  @override
  String get doNotSyncInFuture => 'Не синхронизировать в дальнейшем';

  @override
  String get deleteAction => 'Удалить';

  @override
  String get cancelAction => 'Отмена';

  @override
  String get addSleepSession => 'Добавить сессию сна';

  @override
  String get startTime => 'Начало сна';

  @override
  String get endTime => 'Окончание сна';

  @override
  String get duration => 'Длительность';

  @override
  String get sleepSessionTitleHint => 'Например: Ночной сон';

  @override
  String get sleepSessionDescHint => 'Например: Ручной ввод';

  @override
  String get manualSleepTitleDefault => 'Ночной сон';

  @override
  String get manualSleepDescDefault => 'Добавлено вручную';

  @override
  String get invalidTimeRangeError =>
      'Время окончания должно быть позже времени начала';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get sessionTitleLabel => 'Заголовок';

  @override
  String get sessionDescLabel => 'Описание';

  @override
  String get apiPermissionsActionSetBrightness => 'Изменение яркости';

  @override
  String get apiPermissionsActionSetTemperature =>
      'Изменение цветовой температуры (К)';

  @override
  String get apiPermissionsActionSetMonitorOffset =>
      'Индивидуальное смещение монитора';

  @override
  String get apiPermissionsActionSetBrightnessPreset => 'Пресеты яркости';

  @override
  String get apiPermissionsActionSetTemperaturePreset => 'Пресеты температуры';

  @override
  String get apiPermissionsActionSetUserPreset => 'Пользовательские пресеты';

  @override
  String get apiPermissionsActionCyclePreset =>
      'Циклическое переключение пресетов';

  @override
  String get apiPermissionsActionSetAutoBrightness =>
      'Переключатель авто-яркости';

  @override
  String get apiPermissionsActionSetAutoTemperature =>
      'Переключатель авто-температуры';

  @override
  String get apiPermissionsActionSetSmartCircadian =>
      'Переключатель Smart Circadian';

  @override
  String get apiPermissionsActionSetSmartCircadianSubmodules =>
      'Управление подмодулями ритма';

  @override
  String get apiPermissionsActionSetGameMode => 'Игровой режим (вкл/выкл)';

  @override
  String get apiPermissionsActionSetGameModeBrightness =>
      'Яркость игрового режима';

  @override
  String get apiPermissionsActionManageGameModeWhitelist =>
      'Управление белым списком ПО';

  @override
  String get apiPermissionsActionSetWeatherAdjustment => 'Погодная подстройка';

  @override
  String get apiPermissionsActionSetWeatherTemperatureAdjustment =>
      'Погодная подстройка температуры';

  @override
  String get apiPermissionsActionSetWeatherIntensity =>
      'Интенсивность погодных эффектов';

  @override
  String get apiPermissionsActionSetManualLocation =>
      'Ручной ввод координат геопозиции';

  @override
  String get apiPermissionsActionSetWeatherProvider =>
      'Выбор провайдера погоды';

  @override
  String get apiPermissionsActionTriggerSunSync =>
      'Принудительная синхронизация солнца и погоды';

  @override
  String get apiPermissionsActionPushSleepStatus => 'Передача статуса сна';

  @override
  String get apiPermissionsActionManageWebhooks =>
      'Управление вебхуками (CRUD и DLQ)';

  @override
  String get apiPermissionsActionSetMapAnimations => 'Анимации карты погоды';

  @override
  String get apiPermissionsActionOnSystemResume => 'Обработка возобновления ОС';

  @override
  String get apiPermissionsActionOnHardwareError =>
      'Обработка аппаратных ошибок';

  @override
  String apiKeysGranularActionChip(int count, int total) {
    return 'Разрешено действий: $count из $total';
  }

  @override
  String get tags_solaris_api =>
      'апи, api, control api, solaris control api, http, rest, swagger, порт, локалхост, localhost, lan, сервер, разработчикам';

  @override
  String get tags_api_keys =>
      'api key, токен, доступ, ключи api, права доступа, авторизация, безопасность, bearer, scopes, ключ доступа';

  @override
  String get tags_webhooks =>
      'вебхук, вебхуки, webhook, webhooks, home assistant, node-red, n8n, hmac, события, уведомления, интеграция, автоматизация, dlq';
}
