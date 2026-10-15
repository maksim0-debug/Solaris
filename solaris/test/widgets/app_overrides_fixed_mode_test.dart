import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/screens/app_overrides_screen.dart';

class _Settings extends SettingsNotifier {
  @override
  Future<Map<String, SettingsState>> build() async => {
    'all': SettingsState(
      appOverrides: const [
        AppOverrideRule(
          exeName: 'fixed-mode-test.exe',
          appDisplayName: 'Editor',
        ),
      ],
    ),
  };

  @override
  void updateAppOverride(AppOverrideRule rule) {
    state = AsyncData({
      'all': state.value!['all']!.copyWith(appOverrides: [rule]),
    });
  }
}

class _Temperature extends TemperatureSettingsNotifier {
  @override
  Future<Map<String, TemperatureState>> build() async => {
    'all': TemperatureState(),
  };
}

void main() {
  testWidgets(
    'selecting Fixed saves displayed brightness and temperature without moving either slider',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          temperatureSettingsProvider.overrideWith(_Temperature.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsProvider.future);
      await container.read(temperatureSettingsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AppOverridesScreen()),
          ),
        ),
      );
      await tester.pump();
      final fixedButtons = find.text('Fixed');
      expect(fixedButtons, findsNWidgets(2));
      await tester.tap(fixedButtons.at(1));
      await tester.pump();
      var rule = container
          .read(settingsProvider)
          .value!['all']!
          .appOverrides
          .single;
      expect(rule.temperatureMode, AppOverrideMode.fixed);
      expect(rule.fixedTemperature, 6500);
      expect(rule.brightnessMode, AppOverrideMode.global);
      expect(find.text('6500K'), findsOneWidget);
      await tester.tap(fixedButtons.first);
      await tester.pump();
      rule = container
          .read(settingsProvider)
          .value!['all']!
          .appOverrides
          .single;
      expect(rule.fixedBrightness, 80);
      expect(rule.fixedTemperature, 6500);
      expect(find.text('80%'), findsOneWidget);
      expect(AppOverrideRule.fromJson(rule.toJson()), rule);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
