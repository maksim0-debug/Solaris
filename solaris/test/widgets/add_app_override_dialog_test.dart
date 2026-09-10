import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/widgets/add_app_override_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const namesChannel = MethodChannel('com.solaris.monitor/names');

  final mockProcesses = <Map<String, String>>[
    {'exe': 'antigravity.exe', 'title': 'Antigravity IDE'},
    {'exe': 'chrome.exe', 'title': 'Google Chrome'},
    {'exe': 'ayugram.exe', 'title': 'AyuGram'},
    {'exe': 'code.exe', 'title': 'VS Code'},
    {'exe': 'blender.exe', 'title': 'Blender 4.2'},
    {'exe': 'slack.exe', 'title': 'Slack'},
    {'exe': 'discord.exe', 'title': 'Discord'},
    {'exe': 'spotify.exe', 'title': 'Spotify Music'},
  ];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(namesChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getRunningProcesses') {
            return mockProcesses;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(namesChannel, null);
  });

  Widget createTestWidget({
    List<AppOverrideRule> existingRules = const [],
    Locale locale = const Locale('uk'),
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AddAppOverrideDialog.show(
                    context,
                    existingRules: existingRules,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Renders AddAppOverrideDialog and displays running processes list',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog title and subtitle
      expect(find.text('Вибір додатку'), findsOneWidget);
      expect(
        find.text('Оберіть активний процес або додайте власний файл'),
        findsOneWidget,
      );

      // Verify process count badge in tab
      expect(find.textContaining('Запущені процеси'), findsOneWidget);
      expect(find.text('Власний додаток'), findsOneWidget);

      // Verify processes are rendered
      expect(find.text('antigravity.exe'), findsOneWidget);
      expect(find.text('chrome.exe'), findsOneWidget);
      expect(find.text('ayugram.exe'), findsOneWidget);
    },
  );

  testWidgets('Filtering processes by search query', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Type "chrome" into search field
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'chrome');
    await tester.pumpAndSettle();

    // Only chrome.exe should remain visible
    expect(find.text('chrome.exe'), findsOneWidget);
    expect(find.text('antigravity.exe'), findsNothing);
    expect(find.text('ayugram.exe'), findsNothing);

    // Tap clear button
    await tester.tap(find.byTooltip('Очистити пошук'));
    await tester.pumpAndSettle();

    // All processes should be visible again
    expect(find.text('chrome.exe'), findsOneWidget);
    expect(find.text('antigravity.exe'), findsOneWidget);
  });

  testWidgets(
    'Selecting a process shows bottom preview bar with editable name',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap on chrome.exe
      await tester.tap(find.text('chrome.exe'));
      await tester.pumpAndSettle();

      // Expect the name field prefilled with "Google Chrome"
      expect(find.widgetWithText(TextField, 'Google Chrome'), findsOneWidget);
    },
  );

  testWidgets('Switching to manual entry tab renders custom exe inputs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap on the "Власний додаток" tab
    await tester.tap(find.text('Власний додаток'));
    await tester.pumpAndSettle();

    // Expect manual input labels and hint
    expect(
      find.text(
        'Вкажіть назву файлу .exe для налаштування правила, навіть якщо застосунок зараз не запущений',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Ім'я виконуваного файлу (наприклад app.exe)"),
      findsOneWidget,
    );
    expect(find.text('Назва додатку'), findsOneWidget);
  });

  testWidgets('Renders localized plural processes count in English locale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('8 processes'), findsOneWidget);
  });

  testWidgets('Double-tap on process tile closes dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('antigravity.exe'), findsOneWidget);

    // Double tap on process tile
    await tester.tap(find.text('antigravity.exe').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('antigravity.exe').first);
    await tester.pumpAndSettle();

    // Dialog should be closed
    expect(find.text('antigravity.exe'), findsNothing);
    expect(find.text('Open Dialog'), findsOneWidget);
  });

  testWidgets('Rapid triple-click does not pop parent route', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Rapid clicks
    await tester.tap(find.text('antigravity.exe').first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('antigravity.exe').first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('antigravity.exe').first);
    await tester.pumpAndSettle();

    // The host screen must still be intact
    expect(find.text('Open Dialog'), findsOneWidget);
  });
}
