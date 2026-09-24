import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/crash_report.dart';
import 'package:solaris/widgets/crash_dialog.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets('CrashDialog renders properly and displays traceback details', (
    tester,
  ) async {
    final report = CrashReport(
      timestamp: DateTime(2026, 9, 24, 14, 30, 0),
      errorType: 'AssertionError',
      message: 'Failed assertion: booleanCondition == true',
      stackTrace:
          'package:solaris/screens/dashboard.dart:120:5\npackage:flutter/widgets.dart:50:2',
      context: 'WidgetLifecycleDispatcher',
      osVersion: 'Windows 11',
      dartVersion: '3.13.1',
      pid: 9999,
      recentLogs: ['[2026-09-24 14:29:59.000] [INFO] Render cycle 42'],
      logFilePath: r'C:\Users\User\AppData\Roaming\Solaris\logs\crash.log',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('uk'), Locale('ru')],
        locale: const Locale('en'),
        home: Scaffold(body: CrashDialog(report: report)),
      ),
    );

    await tester.pumpAndSettle();

    // Verify error type and message are displayed
    expect(find.text('AssertionError'), findsOneWidget);
    expect(
      find.text('Failed assertion: booleanCondition == true'),
      findsOneWidget,
    );
    expect(find.text('WidgetLifecycleDispatcher'), findsOneWidget);

    // Verify traceback expand toggle
    expect(find.text('Show Traceback Details'), findsOneWidget);
    await tester.tap(find.text('Show Traceback Details'));
    await tester.pumpAndSettle();

    expect(find.text('Hide Traceback'), findsOneWidget);
    expect(
      find.textContaining('package:solaris/screens/dashboard.dart'),
      findsOneWidget,
    );

    // Verify action buttons exist
    expect(find.text('Open Log File'), findsOneWidget);
    expect(find.text('Open Logs Folder'), findsOneWidget);
    expect(find.text('Copy Error'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('CrashDialog renders properly in Ukrainian locale', (
    tester,
  ) async {
    final report = CrashReport(
      timestamp: DateTime(2026, 9, 24, 14, 30, 0),
      errorType: 'FormatException',
      message: 'Некоректний формат профілю калібрування',
      stackTrace: 'package:solaris/calibration.dart:10:1',
      context: 'CalibrationPipeline',
      osVersion: 'Windows 11',
      dartVersion: '3.13.1',
      pid: 1234,
      recentLogs: ['[2026-09-24 14:29:59.000] [INFO] Init OK'],
      logFilePath: r'C:\Users\User\AppData\Roaming\Solaris\logs\crash.log',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('uk'), Locale('ru')],
        locale: const Locale('uk'),
        home: Scaffold(body: CrashDialog(report: report)),
      ),
    );

    await tester.pumpAndSettle();

    // Verify localized Ukrainian headers & buttons
    expect(find.text('Непередбачена помилка'), findsOneWidget);
    expect(find.text('Показати деталі стек-трейсу'), findsOneWidget);
    expect(find.text('Скопіювати помилку'), findsOneWidget);
    expect(find.text('Відкрити файл логів'), findsOneWidget);
    expect(find.text('Відкрити папку з логами'), findsOneWidget);

    await tester.tap(find.text('Показати деталі стек-трейсу'));
    await tester.pumpAndSettle();

    expect(find.text('Сховати стек-трейс'), findsOneWidget);
  });
}
