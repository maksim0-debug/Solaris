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
  String get active => 'Активно';

  @override
  String get nightShift => 'Ночной режим';

  @override
  String get disabled => 'Выключено';

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
  String engineVersion(String version) {
    return 'Движок Solaris v$version';
  }

  @override
  String get allMonitors => 'Все мониторы';

  @override
  String get luminosityProfile => 'Профиль освещенности';

  @override
  String get sunPosition => 'Положение солнца';

  @override
  String get liveLocation => 'ТЕКУЩЕЕ МЕСТО';

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
}
