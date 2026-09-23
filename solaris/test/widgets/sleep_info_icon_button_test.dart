import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/screens/sleep_screen.dart';

void main() {
  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('SleepInfoIconButton Widget Tests', () {
    testWidgets(
      'renders LucideIcons.info with specified iconSize and constraints',
      (tester) async {
        bool pressed = false;

        await tester.pumpWidget(
          buildTestWidget(
            child: SleepInfoIconButton(
              tooltipMessage: 'Test bio-morning information message',
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.all(2),
              splashRadius: 16,
              onPressed: () => pressed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.info), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.info));
        expect(icon.size, equals(14));

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(
          iconButton.constraints,
          equals(const BoxConstraints(minWidth: 24, minHeight: 24)),
        );
        expect(iconButton.padding, equals(const EdgeInsets.all(2)));
        expect(iconButton.splashRadius, equals(16));

        // Tap triggers onPressed
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(pressed, isTrue);
      },
    );

    testWidgets(
      'has beautiful dark navy card decoration and maxWidth constraint in Tooltip',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const SleepInfoIconButton(
              tooltipMessage:
                  'Adapts the circadian schedule to your actual wake-up time.',
              maxWidth: 350,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(
          tooltip.constraints,
          equals(const BoxConstraints(maxWidth: 350)),
        );
        expect(tooltip.waitDuration, equals(const Duration(milliseconds: 150)));

        final decoration = tooltip.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(
          decoration!.color,
          equals(const Color(0xFF0F172A).withValues(alpha: 0.96)),
        );
        expect(decoration.borderRadius, equals(BorderRadius.circular(10)));
        expect(decoration.boxShadow, isNotEmpty);
        expect(tooltip.textStyle?.fontFamily, equals('Outfit'));
        expect(tooltip.textStyle?.color, equals(Colors.white));
      },
    );

    testWidgets('supports custom maxWidth and preferBelow flags', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const SleepInfoIconButton(
            tooltipMessage: 'Custom tooltip text',
            maxWidth: 320,
            preferBelow: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.constraints, equals(const BoxConstraints(maxWidth: 320)));
      expect(tooltip.preferBelow, isFalse);
    });

    testWidgets(
      'handles null onPressed gracefully and activates tooltip on tap',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const SleepInfoIconButton(
              tooltipMessage: 'Non-interactive tooltip message',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(IconButton), findsOneWidget);
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('formats rich text with quotes and plus signs properly', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const SleepInfoIconButton(
            tooltipMessage: 'Click "+ Add" to create a permanent schedule',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.richMessage, isA<TextSpan>());
      final span = tooltip.richMessage as TextSpan;
      expect(span.children, isNotNull);
      expect(span.children!.length, equals(3));

      final prefixSpan = span.children![0] as TextSpan;
      expect(prefixSpan.text, equals('Click '));

      final highlightedSpan = span.children![1] as TextSpan;
      expect(highlightedSpan.text, equals('"+ Add"'));
      expect(highlightedSpan.style?.color, equals(const Color(0xFFC4B5FD)));
      expect(highlightedSpan.style?.fontWeight, equals(FontWeight.w600));

      final suffixSpan = span.children![2] as TextSpan;
      expect(suffixSpan.text, equals(' to create a permanent schedule'));
    });

    testWidgets('formats rich text with Ukrainian guillemets «+...» properly', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const SleepInfoIconButton(
            tooltipMessage: 'Натисніть «+ Додати» щоб створити новий розклад',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.richMessage, isA<TextSpan>());
      final span = tooltip.richMessage as TextSpan;
      expect(span.children, isNotNull);
      expect(span.children!.length, equals(3));

      final prefixSpan = span.children![0] as TextSpan;
      expect(prefixSpan.text, equals('Натисніть '));

      final highlightedSpan = span.children![1] as TextSpan;
      expect(highlightedSpan.text, equals('«+ Додати»'));
      expect(highlightedSpan.style?.color, equals(const Color(0xFFC4B5FD)));
      expect(highlightedSpan.style?.fontWeight, equals(FontWeight.w600));

      final suffixSpan = span.children![2] as TextSpan;
      expect(suffixSpan.text, equals(' щоб створити новий розклад'));
    });

    testWidgets(
      'returns unsegmented TextSpan when no highlight patterns match',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const SleepInfoIconButton(
              tooltipMessage: 'Просте повідомлення без кнопок дій',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.richMessage, isA<TextSpan>());
        final span = tooltip.richMessage as TextSpan;
        expect(span.text, equals('Просте повідомлення без кнопок дій'));
        expect(span.children, isNull);
      },
    );

    testWidgets(
      'showSleepInfoDialog displays modal with title, message, and close button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showSleepInfoDialog(
                        context,
                        title: 'Інформація про порт',
                        message:
                            'Детальний опис налаштувань Solaris Control API',
                      ),
                      child: const Text('Open Dialog'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Інформація про порт'), findsOneWidget);
        expect(
          find.text('Детальний опис налаштувань Solaris Control API'),
          findsOneWidget,
        );
        expect(find.byIcon(LucideIcons.x), findsOneWidget);

        // Close via [X] button
        await tester.tap(find.byIcon(LucideIcons.x));
        await tester.pumpAndSettle();

        expect(find.text('Інформація про порт'), findsNothing);
      },
    );
  });
}
