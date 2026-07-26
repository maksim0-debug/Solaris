import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';

void main() {
  group('Phase 3: Per-Action Permissions Localization Test Suite', () {
    test('English (en) 25 per-action keys and granular chip verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(l10n.apiPermissionsActionSetBrightness, equals('Set Brightness'));
      expect(l10n.apiPermissionsActionSetTemperature, equals('Set Color Temperature (K)'));
      expect(l10n.apiPermissionsActionSetMonitorOffset, equals('Monitor Offset Adjustment'));
      expect(l10n.apiPermissionsActionSetBrightnessPreset, equals('Brightness Presets'));
      expect(l10n.apiPermissionsActionSetTemperaturePreset, equals('Temperature Presets'));
      expect(l10n.apiPermissionsActionSetUserPreset, equals('Custom User Presets'));
      expect(l10n.apiPermissionsActionCyclePreset, equals('Cycle Presets Forward/Backward'));
      expect(l10n.apiPermissionsActionSetAutoBrightness, equals('Auto-Brightness Engine Toggle'));
      expect(l10n.apiPermissionsActionSetAutoTemperature, equals('Auto-Temperature Engine Toggle'));
      expect(l10n.apiPermissionsActionSetSmartCircadian, equals('Smart Circadian Master Toggle'));
      expect(l10n.apiPermissionsActionSetSmartCircadianSubmodules, equals('Circadian Submodules Control'));
      expect(l10n.apiPermissionsActionSetGameMode, equals('Game Mode Master Switch'));
      expect(l10n.apiPermissionsActionSetGameModeBrightness, equals('Game Mode Brightness Level'));
      expect(l10n.apiPermissionsActionManageGameModeWhitelist, equals('Game Mode App Whitelist Management'));
      expect(l10n.apiPermissionsActionSetWeatherAdjustment, equals('Weather Adjustments Toggle'));
      expect(l10n.apiPermissionsActionSetWeatherTemperatureAdjustment, equals('Weather Temperature Adjustments Toggle'));
      expect(l10n.apiPermissionsActionSetWeatherIntensity, equals('Weather Effect Intensity Level'));
      expect(l10n.apiPermissionsActionSetManualLocation, equals('Manual Location Coordinates Entry'));
      expect(l10n.apiPermissionsActionSetWeatherProvider, equals('Weather Provider Selection'));
      expect(l10n.apiPermissionsActionTriggerSunSync, equals('Force Solar & Weather Data Sync'));
      expect(l10n.apiPermissionsActionPushSleepStatus, equals('Push External Sleep Status'));
      expect(l10n.apiPermissionsActionManageWebhooks, equals('Webhook Management (CRUD & DLQ)'));
      expect(l10n.apiPermissionsActionSetMapAnimations, equals('Map Visual Weather Animations'));
      expect(l10n.apiPermissionsActionOnSystemResume, equals('System Resume Event Handling'));
      expect(l10n.apiPermissionsActionOnHardwareError, equals('Hardware Error Event Handling'));

      expect(l10n.apiKeysGranularActionChip(12, 25), equals('12 of 25 Actions Allowed'));
    });

    test('Russian (ru) 25 per-action keys and granular chip verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      expect(l10n.apiPermissionsActionSetBrightness, equals('Изменение яркости'));
      expect(l10n.apiPermissionsActionSetTemperature, equals('Изменение цветовой температуры (К)'));
      expect(l10n.apiPermissionsActionSetMonitorOffset, equals('Индивидуальное смещение монитора'));
      expect(l10n.apiPermissionsActionSetBrightnessPreset, equals('Пресеты яркости'));
      expect(l10n.apiPermissionsActionSetTemperaturePreset, equals('Пресеты температуры'));
      expect(l10n.apiPermissionsActionSetUserPreset, equals('Пользовательские пресеты'));
      expect(l10n.apiPermissionsActionCyclePreset, equals('Циклическое переключение пресетов'));
      expect(l10n.apiPermissionsActionSetAutoBrightness, equals('Переключатель авто-яркости'));
      expect(l10n.apiPermissionsActionSetAutoTemperature, equals('Переключатель авто-температуры'));
      expect(l10n.apiPermissionsActionSetSmartCircadian, equals('Переключатель Smart Circadian'));
      expect(l10n.apiPermissionsActionSetSmartCircadianSubmodules, equals('Управление подмодулями ритма'));
      expect(l10n.apiPermissionsActionSetGameMode, equals('Игровой режим (вкл/выкл)'));
      expect(l10n.apiPermissionsActionSetGameModeBrightness, equals('Яркость игрового режима'));
      expect(l10n.apiPermissionsActionManageGameModeWhitelist, equals('Управление белым списком ПО'));
      expect(l10n.apiPermissionsActionSetWeatherAdjustment, equals('Погодная подстройка'));
      expect(l10n.apiPermissionsActionSetWeatherTemperatureAdjustment, equals('Погодная подстройка температуры'));
      expect(l10n.apiPermissionsActionSetWeatherIntensity, equals('Интенсивность погодных эффектов'));
      expect(l10n.apiPermissionsActionSetManualLocation, equals('Ручной ввод координат геопозиции'));
      expect(l10n.apiPermissionsActionSetWeatherProvider, equals('Выбор провайдера погоды'));
      expect(l10n.apiPermissionsActionTriggerSunSync, equals('Принудительная синхронизация солнца и погоды'));
      expect(l10n.apiPermissionsActionPushSleepStatus, equals('Передача статуса сна'));
      expect(l10n.apiPermissionsActionManageWebhooks, equals('Управление вебхуками (CRUD и DLQ)'));
      expect(l10n.apiPermissionsActionSetMapAnimations, equals('Анимации карты погоды'));
      expect(l10n.apiPermissionsActionOnSystemResume, equals('Обработка возобновления ОС'));
      expect(l10n.apiPermissionsActionOnHardwareError, equals('Обработка аппаратных ошибок'));

      expect(l10n.apiKeysGranularActionChip(12, 25), equals('Разрешено действий: 12 из 25'));
    });

    test('Ukrainian (uk) 25 per-action keys and granular chip verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

      expect(l10n.apiPermissionsActionSetBrightness, equals('Зміна яскравості'));
      expect(l10n.apiPermissionsActionSetTemperature, equals('Зміна колірної температури (К)'));
      expect(l10n.apiPermissionsActionSetMonitorOffset, equals('Індивідуальне зміщення монітора'));
      expect(l10n.apiPermissionsActionSetBrightnessPreset, equals('Пресети яскравості'));
      expect(l10n.apiPermissionsActionSetTemperaturePreset, equals('Пресети температури'));
      expect(l10n.apiPermissionsActionSetUserPreset, equals('Користувацькі пресети'));
      expect(l10n.apiPermissionsActionCyclePreset, equals('Циклічне перемикання пресетів'));
      expect(l10n.apiPermissionsActionSetAutoBrightness, equals('Перемикач авто-яскравості'));
      expect(l10n.apiPermissionsActionSetAutoTemperature, equals('Перемикач авто-температури'));
      expect(l10n.apiPermissionsActionSetSmartCircadian, equals('Перемикач Smart Circadian'));
      expect(l10n.apiPermissionsActionSetSmartCircadianSubmodules, equals('Управління підмодулями ритму'));
      expect(l10n.apiPermissionsActionSetGameMode, equals('Ігровий режим (увімк/вимк)'));
      expect(l10n.apiPermissionsActionSetGameModeBrightness, equals('Яскравість ігрового режиму'));
      expect(l10n.apiPermissionsActionManageGameModeWhitelist, equals('Управління білим списком ПЗ'));
      expect(l10n.apiPermissionsActionSetWeatherAdjustment, equals('Погодне коригування'));
      expect(l10n.apiPermissionsActionSetWeatherTemperatureAdjustment, equals('Погодне коригування температури'));
      expect(l10n.apiPermissionsActionSetWeatherIntensity, equals('Інтенсивність погодних ефектів'));
      expect(l10n.apiPermissionsActionSetManualLocation, equals('Ручне введення координат геопозиції'));
      expect(l10n.apiPermissionsActionSetWeatherProvider, equals('Вибір провайдера погоди'));
      expect(l10n.apiPermissionsActionTriggerSunSync, equals('Примусова синхронізація сонця та погоди'));
      expect(l10n.apiPermissionsActionPushSleepStatus, equals('Передача статусу сну'));
      expect(l10n.apiPermissionsActionManageWebhooks, equals('Управління вебхуками (CRUD та DLQ)'));
      expect(l10n.apiPermissionsActionSetMapAnimations, equals('Анімації карти погоди'));
      expect(l10n.apiPermissionsActionOnSystemResume, equals('Обробка відновлення ОС'));
      expect(l10n.apiPermissionsActionOnHardwareError, equals('Обробка апаратних помилок'));

      expect(l10n.apiKeysGranularActionChip(12, 25), equals('Дозволено дій: 12 з 25'));
    });
  });
}
