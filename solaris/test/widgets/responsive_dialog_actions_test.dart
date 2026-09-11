import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/widgets/responsive_dialog_actions.dart';

void main() {
  group('ResponsiveDialogActions Widget Tests', () {
    testWidgets(
      'lays out leading and actions in single row when sufficient width',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 500,
                  child: ResponsiveDialogActions(
                    leading: const Text('Leading Link'),
                    actions: const [Text('Action 1'), Text('Action 2')],
                  ),
                ),
              ),
            ),
          ),
        );

        final leadingFinder = find.text('Leading Link');
        final action1Finder = find.text('Action 1');
        final action2Finder = find.text('Action 2');

        expect(leadingFinder, findsOneWidget);
        expect(action1Finder, findsOneWidget);
        expect(action2Finder, findsOneWidget);

        final leadingTopLeft = tester.getTopLeft(leadingFinder);
        final action1TopLeft = tester.getTopLeft(action1Finder);
        final action2TopLeft = tester.getTopLeft(action2Finder);

        // In single row mode, Y coordinates are aligned on the same row
        expect(leadingTopLeft.dy, equals(action1TopLeft.dy));
        expect(action1TopLeft.dy, equals(action2TopLeft.dy));

        // Leading is on the far left (x around 0 relative to box)
        // Action 1 is to the left of Action 2
        expect(action1TopLeft.dx, lessThan(action2TopLeft.dx));
        expect(leadingTopLeft.dx, lessThan(action1TopLeft.dx));
      },
    );

    testWidgets(
      'transitions to stacked layout without overflow when width is constrained',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200, // Constrained width
                  child: ResponsiveDialogActions(
                    leading: const SizedBox(
                      width: 120,
                      height: 30,
                      child: Text('Leading'),
                    ),
                    actions: const [
                      SizedBox(width: 60, height: 30, child: Text('OK')),
                      SizedBox(
                        width: 150,
                        height: 30,
                        child: Text('Very Long Action Button'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final leadingFinder = find.text('Leading');
        final okFinder = find.text('OK');
        final longActionFinder = find.text('Very Long Action Button');

        expect(leadingFinder, findsOneWidget);
        expect(okFinder, findsOneWidget);
        expect(longActionFinder, findsOneWidget);

        final leadingTopLeft = tester.getTopLeft(leadingFinder);
        final okTopLeft = tester.getTopLeft(okFinder);
        final longActionTopLeft = tester.getTopLeft(longActionFinder);

        // Primary long action is placed on Row 1 (top)
        // Leading and OK are placed on Row 2 (underneath it)
        expect(longActionTopLeft.dy, lessThan(leadingTopLeft.dy));
        expect(longActionTopLeft.dy, lessThan(okTopLeft.dy));
        expect(leadingTopLeft.dy, equals(okTopLeft.dy));

        // Leading is on the left of Row 2, OK is on the right of Row 2
        expect(leadingTopLeft.dx, lessThan(okTopLeft.dx));
      },
    );

    testWidgets('handles tap events on both leading and actions', (
      WidgetTester tester,
    ) async {
      bool leadingTapped = false;
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: ResponsiveDialogActions(
                  leading: TextButton(
                    onPressed: () => leadingTapped = true,
                    child: const Text('GitHub'),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => actionTapped = true,
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('GitHub'));
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(leadingTapped, isTrue);
      expect(actionTapped, isTrue);
    });

    testWidgets(
      'handles unbounded width gracefully without crashing (defensive programming)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: UnconstrainedBox(
                  child: ResponsiveDialogActions(
                    leading: const Text('Defensive Leading'),
                    actions: const [Text('OK')],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Defensive Leading'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
      },
    );

    testWidgets(
      'lays out 2 children (leading + 1 action) with leading on Row 1 and action right-aligned on Row 2 when constrained',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  child: ResponsiveDialogActions(
                    leading: const SizedBox(
                      width: 100,
                      height: 30,
                      child: Text('Privacy Policy'),
                    ),
                    actions: const [
                      SizedBox(width: 100, height: 30, child: Text('Close')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final privacyFinder = find.text('Privacy Policy');
        final closeFinder = find.text('Close');

        final privacyTopLeft = tester.getTopLeft(privacyFinder);
        final closeTopLeft = tester.getTopLeft(closeFinder);

        // Privacy is on row 1, Close is on row 2 (bottom right)
        expect(privacyTopLeft.dy, lessThan(closeTopLeft.dy));

        // Privacy Policy (leading) is left-aligned
        final containerTopLeft = tester.getTopLeft(
          find.byType(ResponsiveDialogActions),
        );
        expect(privacyTopLeft.dx, equals(containerTopLeft.dx));

        // Close is right-aligned
        expect(closeTopLeft.dx, greaterThan(privacyTopLeft.dx));
      },
    );

    testWidgets(
      'maintains visual hierarchy in extreme fallback column (3 children)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width:
                      150, // Extremely constrained: row2 (120 + 8 + 60 = 188) does not fit
                  child: ResponsiveDialogActions(
                    leading: const SizedBox(
                      width: 120,
                      height: 30,
                      child: Text('Leading'),
                    ),
                    actions: const [
                      SizedBox(width: 60, height: 30, child: Text('OK')),
                      SizedBox(
                        width: 140,
                        height: 30,
                        child: Text('Primary Action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final leadingFinder = find.text('Leading');
        final okFinder = find.text('OK');
        final primaryFinder = find.text('Primary Action');

        final leadingTopLeft = tester.getTopLeft(leadingFinder);
        final okTopLeft = tester.getTopLeft(okFinder);
        final primaryTopLeft = tester.getTopLeft(primaryFinder);

        // Primary is on Row 1 (top)
        // OK (secondary) is on Row 2 (middle)
        // Leading is on Row 3 (bottom)
        expect(primaryTopLeft.dy, lessThan(okTopLeft.dy));
        expect(okTopLeft.dy, lessThan(leadingTopLeft.dy));

        // Leading remains left-aligned at X=0
        final containerTopLeft = tester.getTopLeft(
          find.byType(ResponsiveDialogActions),
        );
        expect(leadingTopLeft.dx, equals(containerTopLeft.dx));
      },
    );

    testWidgets(
      'visits children in visual reading order for semantics (WCAG 2.1)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width:
                      200, // 2-row layout: Primary on Row 1, Leading + OK on Row 2
                  child: ResponsiveDialogActions(
                    leading: const SizedBox(
                      width: 120,
                      height: 30,
                      child: Text('Leading'),
                    ),
                    actions: const [
                      SizedBox(width: 60, height: 30, child: Text('OK')),
                      SizedBox(
                        width: 150,
                        height: 30,
                        child: Text('Primary Action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderResponsiveDialogActions>(
          find.byType(ResponsiveDialogActions),
        );

        final visitedBoxes = <RenderBox>[];
        renderBox.visitChildrenForSemantics((child) {
          visitedBoxes.add(child as RenderBox);
        });

        expect(visitedBoxes.length, equals(3));
        // First visited is Primary Action (Row 1)
        // Second visited is Leading (Row 2 left)
        // Third visited is OK (Row 2 right)
        final firstData =
            visitedBoxes[0].parentData! as ResponsiveDialogActionsParentData;
        final secondData =
            visitedBoxes[1].parentData! as ResponsiveDialogActionsParentData;
        final thirdData =
            visitedBoxes[2].parentData! as ResponsiveDialogActionsParentData;

        expect(firstData.offset.dy, lessThan(secondData.offset.dy));
        expect(secondData.offset.dy, equals(thirdData.offset.dy));
        expect(secondData.offset.dx, lessThan(thirdData.offset.dx));
      },
    );

    testWidgets('handles tap events in stacked layout mode', (
      WidgetTester tester,
    ) async {
      bool leadingTapped = false;
      bool action1Tapped = false;
      bool action2Tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200, // triggers stacked layout
                child: ResponsiveDialogActions(
                  leading: TextButton(
                    onPressed: () => leadingTapped = true,
                    child: const Text('Stacked Leading'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => action1Tapped = true,
                      child: const Text('Stacked Action 1'),
                    ),
                    ElevatedButton(
                      onPressed: () => action2Tapped = true,
                      child: const Text('Stacked Action 2'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Stacked Leading'));
      await tester.tap(find.text('Stacked Action 1'));
      await tester.tap(find.text('Stacked Action 2'));
      await tester.pump();

      expect(leadingTapped, isTrue);
      expect(action1Tapped, isTrue);
      expect(action2Tapped, isTrue);
    });
  });
}
