import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';

void main() {
  group('API Permissions Localization (Phase 5 - Zero Trust Exhaustive Test Suite)', () {
    test('English (en) complete string & key verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(l10n.apiPermissionsDialogTitle, equals('API Permissions & Access Control'));
      expect(l10n.apiPermissionsReadOnlyLabel, equals('Read-Only Mode'));
      expect(
        l10n.apiPermissionsReadOnlyHint,
        equals('When enabled, all state-changing API requests (POST/PUT/DELETE) will be blocked with HTTP 403 Forbidden.'),
      );
      expect(l10n.apiPermissionsDataSharingSection, equals('Data Sharing Permissions (Read Operations)'));
      expect(l10n.apiPermissionsAllowMonitors, equals('Monitors & Brightness State'));
      expect(l10n.apiPermissionsAllowSolar, equals('Solar & Astronomical Data'));
      expect(l10n.apiPermissionsAllowWeather, equals('Weather Adjustments & Provider Info'));
      expect(l10n.apiPermissionsAllowSleep, equals('Sleep & Circadian Rhythm Metrics'));
      expect(l10n.apiPermissionsAllowCircadian, equals('Smart Circadian System State'));
      expect(l10n.apiPermissionsControlCategoriesSection, equals('Action Control Categories (Control)'));
      expect(l10n.apiPermissionsCategoryMonitors, equals('Monitors (Brightness, Temp, Offsets)'));
      expect(l10n.apiPermissionsCategoryPresets, equals('Presets & Brightness Profiles'));
      expect(l10n.apiPermissionsCategoryCircadian, equals('Circadian Rhythm & Auto-Adjustments'));
      expect(l10n.apiPermissionsCategoryGaming, equals('Game Mode & App Whitelists'));
      expect(l10n.apiPermissionsCategoryEnvironment, equals('Environment & Weather Adjustments'));
      expect(l10n.apiPermissionsCategorySleep, equals('Sleep Actions & Status Pushes'));
      expect(l10n.apiPermissionsCategorySystem, equals('System Actions (Webhooks, Animations)'));
      expect(l10n.apiPermissionsConfigureButton, equals('Configure API Permissions...'));
      expect(l10n.apiPermissionsSummaryReadOnly, equals('Read-Only Mode Active'));

      // Pluralization checks for EN
      expect(l10n.apiPermissionsSummaryCustom(0), equals('0 categories allowed'));
      expect(l10n.apiPermissionsSummaryCustom(1), equals('1 category allowed'));
      expect(l10n.apiPermissionsSummaryCustom(2), equals('2 categories allowed'));
      expect(l10n.apiPermissionsSummaryCustom(5), equals('5 categories allowed'));
      expect(l10n.apiPermissionsSummaryCustom(7), equals('7 categories allowed'));
    });

    test('Russian (ru) complete string, key & pluralization verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      expect(l10n.apiPermissionsDialogTitle, equals('Права доступа API и гранулярный контроль'));
      expect(l10n.apiPermissionsReadOnlyLabel, equals('Режим «Только чтение» (Read-Only)'));
      expect(
        l10n.apiPermissionsReadOnlyHint,
        equals('Если включено, все управляющие API-запросы (POST/PUT/DELETE) блокируются с кодом HTTP 403 Forbidden.'),
      );
      expect(l10n.apiPermissionsDataSharingSection, equals('Разрешения на передачу данных (Чтение)'));
      expect(l10n.apiPermissionsAllowMonitors, equals('Мониторы и состояние яркости'));
      expect(l10n.apiPermissionsAllowSolar, equals('Солнечные и астрономические данные'));
      expect(l10n.apiPermissionsAllowWeather, equals('Погодные корректировки и данные провайдера'));
      expect(l10n.apiPermissionsAllowSleep, equals('Метрики сна и циркадного ритма'));
      expect(l10n.apiPermissionsAllowCircadian, equals('Состояние системы Smart Circadian'));
      expect(l10n.apiPermissionsControlCategoriesSection, equals('Разрешенные категории команд (Управление)'));
      expect(l10n.apiPermissionsCategoryMonitors, equals('Мониторы (яркость, температура, смещения)'));
      expect(l10n.apiPermissionsCategoryPresets, equals('Пресеты и профили яркости'));
      expect(l10n.apiPermissionsCategoryCircadian, equals('Циркадный ритм и авто-настройки'));
      expect(l10n.apiPermissionsCategoryGaming, equals('Игровой режим и белые списки ПО'));
      expect(l10n.apiPermissionsCategoryEnvironment, equals('Окружение и погодные настройки'));
      expect(l10n.apiPermissionsCategorySleep, equals('Действия сна и обновление статуса'));
      expect(l10n.apiPermissionsCategorySystem, equals('Системные действия (вебхуки, анимации)'));
      expect(l10n.apiPermissionsConfigureButton, equals('Настроить права API...'));
      expect(l10n.apiPermissionsSummaryReadOnly, equals('Режим «Только чтение» активен'));

      // Regression check for continueButton in RU
      expect(l10n.continueButton, equals('Продолжить'));

      // Comprehensive Slavic pluralization checks for Russian
      expect(l10n.apiPermissionsSummaryCustom(0), equals('Разрешено 0 категорий'));
      expect(l10n.apiPermissionsSummaryCustom(1), equals('Разрешена 1 категория'));
      expect(l10n.apiPermissionsSummaryCustom(2), equals('Разрешено 2 категории'));
      expect(l10n.apiPermissionsSummaryCustom(3), equals('Разрешено 3 категории'));
      expect(l10n.apiPermissionsSummaryCustom(4), equals('Разрешено 4 категории'));
      expect(l10n.apiPermissionsSummaryCustom(5), equals('Разрешено 5 категорий'));
      expect(l10n.apiPermissionsSummaryCustom(7), equals('Разрешено 7 категорий'));
      expect(l10n.apiPermissionsSummaryCustom(21), equals('Разрешена 21 категория'));
      expect(l10n.apiPermissionsSummaryCustom(22), equals('Разрешено 22 категории'));
      expect(l10n.apiPermissionsSummaryCustom(25), equals('Разрешено 25 категорий'));
    });

    test('Ukrainian (uk) complete string, key & pluralization verification', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

      expect(l10n.apiPermissionsDialogTitle, equals('Права доступу API та гранулярний контроль'));
      expect(l10n.apiPermissionsReadOnlyLabel, equals('Режим «Лише читання» (Read-Only)'));
      expect(
        l10n.apiPermissionsReadOnlyHint,
        equals('Якщо увімкнено, усі керуючі API-запити (POST/PUT/DELETE) блокуються з кодом HTTP 403 Forbidden.'),
      );
      expect(l10n.apiPermissionsDataSharingSection, equals('Дозволи на передачу даних (Читання)'));
      expect(l10n.apiPermissionsAllowMonitors, equals('Монітори та стан яскравості'));
      expect(l10n.apiPermissionsAllowSolar, equals('Сонячні та астрономічні дані'));
      expect(l10n.apiPermissionsAllowWeather, equals('Погодні коригування та дані провайдера'));
      expect(l10n.apiPermissionsAllowSleep, equals('Метрики сну та циркадного ритму'));
      expect(l10n.apiPermissionsAllowCircadian, equals('Стан системи Smart Circadian'));
      expect(l10n.apiPermissionsControlCategoriesSection, equals('Дозволені категорії команд (Управління)'));
      expect(l10n.apiPermissionsCategoryMonitors, equals('Монітори (яскравість, температура, зсуви)'));
      expect(l10n.apiPermissionsCategoryPresets, equals('Пресети та профілі яскравості'));
      expect(l10n.apiPermissionsCategoryCircadian, equals('Циркадний ритм та авто-налаштування'));
      expect(l10n.apiPermissionsCategoryGaming, equals('Ігровий режим та білі списки ПЗ'));
      expect(l10n.apiPermissionsCategoryEnvironment, equals('Довкілля та погодні налаштування'));
      expect(l10n.apiPermissionsCategorySleep, equals('Дії сну та оновлення статусу'));
      expect(l10n.apiPermissionsCategorySystem, equals('Системні дії (вебхуки, анімації)'));
      expect(l10n.apiPermissionsConfigureButton, equals('Налаштувати права API...'));
      expect(l10n.apiPermissionsSummaryReadOnly, equals('Режим «Лише читання» активний'));

      // Comprehensive Slavic pluralization checks for Ukrainian
      expect(l10n.apiPermissionsSummaryCustom(0), equals('Дозволено 0 категорій'));
      expect(l10n.apiPermissionsSummaryCustom(1), equals('Дозволено 1 категорію'));
      expect(l10n.apiPermissionsSummaryCustom(2), equals('Дозволено 2 категорії'));
      expect(l10n.apiPermissionsSummaryCustom(3), equals('Дозволено 3 категорії'));
      expect(l10n.apiPermissionsSummaryCustom(4), equals('Дозволено 4 категорії'));
      expect(l10n.apiPermissionsSummaryCustom(5), equals('Дозволено 5 категорій'));
      expect(l10n.apiPermissionsSummaryCustom(6), equals('Дозволено 6 категорій'));
      expect(l10n.apiPermissionsSummaryCustom(21), equals('Дозволено 21 категорію'));
      expect(l10n.apiPermissionsSummaryCustom(22), equals('Дозволено 22 категорії'));
      expect(l10n.apiPermissionsSummaryCustom(25), equals('Дозволено 25 категорій'));
    });

    test('Zero-Trust non-null and non-empty property invariants check', () async {
      for (final locale in [const Locale('en'), const Locale('ru'), const Locale('uk')]) {
        final l10n = await AppLocalizations.delegate.load(locale);

        final String title = l10n.apiPermissionsDialogTitle;
        final String roLabel = l10n.apiPermissionsReadOnlyLabel;
        final String roHint = l10n.apiPermissionsReadOnlyHint;
        final String dataSec = l10n.apiPermissionsDataSharingSection;
        final String allowMon = l10n.apiPermissionsAllowMonitors;
        final String allowSol = l10n.apiPermissionsAllowSolar;
        final String allowWea = l10n.apiPermissionsAllowWeather;
        final String allowSle = l10n.apiPermissionsAllowSleep;
        final String allowCir = l10n.apiPermissionsAllowCircadian;
        final String catSec = l10n.apiPermissionsControlCategoriesSection;
        final String catMon = l10n.apiPermissionsCategoryMonitors;
        final String catPre = l10n.apiPermissionsCategoryPresets;
        final String catCir = l10n.apiPermissionsCategoryCircadian;
        final String catGam = l10n.apiPermissionsCategoryGaming;
        final String catEnv = l10n.apiPermissionsCategoryEnvironment;
        final String catSle = l10n.apiPermissionsCategorySleep;
        final String catSys = l10n.apiPermissionsCategorySystem;
        final String cfgBtn = l10n.apiPermissionsConfigureButton;
        final String sumRo = l10n.apiPermissionsSummaryReadOnly;

        expect(title.isNotEmpty, isTrue, reason: 'apiPermissionsDialogTitle should not be empty for $locale');
        expect(roLabel.isNotEmpty, isTrue, reason: 'apiPermissionsReadOnlyLabel should not be empty for $locale');
        expect(roHint.isNotEmpty, isTrue, reason: 'apiPermissionsReadOnlyHint should not be empty for $locale');
        expect(dataSec.isNotEmpty, isTrue, reason: 'apiPermissionsDataSharingSection should not be empty for $locale');
        expect(allowMon.isNotEmpty, isTrue, reason: 'apiPermissionsAllowMonitors should not be empty for $locale');
        expect(allowSol.isNotEmpty, isTrue, reason: 'apiPermissionsAllowSolar should not be empty for $locale');
        expect(allowWea.isNotEmpty, isTrue, reason: 'apiPermissionsAllowWeather should not be empty for $locale');
        expect(allowSle.isNotEmpty, isTrue, reason: 'apiPermissionsAllowSleep should not be empty for $locale');
        expect(allowCir.isNotEmpty, isTrue, reason: 'apiPermissionsAllowCircadian should not be empty for $locale');
        expect(catSec.isNotEmpty, isTrue, reason: 'apiPermissionsControlCategoriesSection should not be empty for $locale');
        expect(catMon.isNotEmpty, isTrue, reason: 'apiPermissionsCategoryMonitors should not be empty for $locale');
        expect(catPre.isNotEmpty, isTrue, reason: 'apiPermissionsCategoryPresets should not be empty for $locale');
        expect(catCir.isNotEmpty, isTrue, reason: 'apiPermissionsCategoryCircadian should not be empty for $locale');
        expect(catGam.isNotEmpty, isTrue, reason: 'apiPermissionsCategoryGaming should not be empty for $locale');
        expect(catEnv.isNotEmpty, isTrue, reason: 'apiPermissionsCategoryEnvironment should not be empty for $locale');
        expect(catSle.isNotEmpty, isTrue, reason: 'apiPermissionsCategorySleep should not be empty for $locale');
        expect(catSys.isNotEmpty, isTrue, reason: 'apiPermissionsCategorySystem should not be empty for $locale');
        expect(cfgBtn.isNotEmpty, isTrue, reason: 'apiPermissionsConfigureButton should not be empty for $locale');
        expect(sumRo.isNotEmpty, isTrue, reason: 'apiPermissionsSummaryReadOnly should not be empty for $locale');
      }
    });
  });
}
