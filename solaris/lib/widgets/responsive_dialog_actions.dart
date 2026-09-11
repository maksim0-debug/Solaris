import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ParentData for [RenderResponsiveDialogActions].
class ResponsiveDialogActionsParentData
    extends ContainerBoxParentData<RenderBox> {}

/// A robust responsive dialog action bar that arranges [leading] and [actions] in a single
/// horizontal row when space permits, and seamlessly falls back to an intentional, elegant
/// multi-row or stacked layout when localized text or display scaling exceeds the available width.
///
/// ### Expected Action Ordering (API Contract):
/// Actions are expected in order of increasing visual prominence:
/// - Single action: `[primaryAction]` (e.g. `[Close]` or `[OK]`).
/// - Two actions: `[secondaryAction, primaryAction]` (e.g. `[Later, Download]`, `[Cancel, Save]`, `[OK, Check for updates]`).
///
/// In 2-row layout when [leading] and two actions are present, the primary CTA ([actions.last])
/// is prominently placed on the top row, while [leading] and the secondary action share the bottom row.
///
/// In 2-row layout when [leading] and a single action are present (e.g. legal links and a Close button),
/// [leading] is placed on Row 1 (left-aligned) and the action is placed on Row 2 (right-aligned),
/// ensuring dismiss buttons remain at the bottom of the dialog.
class ResponsiveDialogActions extends MultiChildRenderObjectWidget {
  final Widget? leading;
  final List<Widget> actions;
  final double spacing;
  final double runSpacing;

  ResponsiveDialogActions({
    super.key,
    this.leading,
    required this.actions,
    this.spacing = 8.0,
    this.runSpacing = 10.0,
  }) : super(children: [?leading, ...actions]);

  @override
  RenderResponsiveDialogActions createRenderObject(BuildContext context) {
    return RenderResponsiveDialogActions(
      hasLeading: leading != null,
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderResponsiveDialogActions renderObject,
  ) {
    renderObject
      ..hasLeading = leading != null
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class RenderResponsiveDialogActions extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ResponsiveDialogActionsParentData
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ResponsiveDialogActionsParentData
        > {
  bool _hasLeading;
  double _spacing;
  double _runSpacing;

  RenderResponsiveDialogActions({
    required bool hasLeading,
    required double spacing,
    required double runSpacing,
  }) : _hasLeading = hasLeading,
       _spacing = spacing,
       _runSpacing = runSpacing;

  bool get hasLeading => _hasLeading;
  set hasLeading(bool value) {
    if (_hasLeading != value) {
      _hasLeading = value;
      markNeedsLayout();
    }
  }

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing != value) {
      _runSpacing = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ResponsiveDialogActionsParentData) {
      child.parentData = ResponsiveDialogActionsParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double maxChildWidth = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final w = child.getMinIntrinsicWidth(height);
      if (w > maxChildWidth) maxChildWidth = w;
      child =
          (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
    }
    return maxChildWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double totalWidth = 0;
    int count = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      totalWidth += child.getMaxIntrinsicWidth(height);
      count++;
      child =
          (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
    }
    if (count > 1) {
      totalWidth += (count - 1) * spacing;
    }
    return totalWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final maxWidth = computeMaxIntrinsicWidth(double.infinity);
    if (maxWidth <= width) {
      double maxHeight = 0;
      RenderBox? child = firstChild;
      while (child != null) {
        final h = child.getMaxIntrinsicHeight(width);
        if (h > maxHeight) maxHeight = h;
        child =
            (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
      }
      return maxHeight;
    } else {
      if (_hasLeading && childCount == 3) {
        final leading = firstChild!;
        final secondary =
            (leading.parentData as ResponsiveDialogActionsParentData)
                .nextSibling!;
        final primary =
            (secondary.parentData as ResponsiveDialogActionsParentData)
                .nextSibling!;

        final leadingW = leading.getMaxIntrinsicWidth(double.infinity);
        final secondaryW = secondary.getMaxIntrinsicWidth(double.infinity);
        if (leadingW + spacing + secondaryW <= width) {
          final primaryH = primary.getMaxIntrinsicHeight(width);
          final leadingH = leading.getMaxIntrinsicHeight(width);
          final secondaryH = secondary.getMaxIntrinsicHeight(width);
          return primaryH + runSpacing + math.max(leadingH, secondaryH);
        } else {
          final primaryH = primary.getMaxIntrinsicHeight(width);
          final secondaryH = secondary.getMaxIntrinsicHeight(width);
          final leadingH = leading.getMaxIntrinsicHeight(width);
          return primaryH + runSpacing + secondaryH + runSpacing + leadingH;
        }
      } else if (_hasLeading && childCount == 2) {
        final leading = firstChild!;
        final action = (leading.parentData as ResponsiveDialogActionsParentData)
            .nextSibling!;
        final leadingH = leading.getMaxIntrinsicHeight(width);
        final actionH = action.getMaxIntrinsicHeight(width);
        return leadingH + runSpacing + actionH;
      }

      double totalHeight = 0;
      int count = 0;
      RenderBox? child = firstChild;
      while (child != null) {
        totalHeight += child.getMaxIntrinsicHeight(width);
        count++;
        child =
            (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
      }
      if (count > 1) totalHeight += (count - 1) * runSpacing;
      return totalHeight;
    }
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final maxLayoutWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);

    final childrenList = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints(maxWidth: maxLayoutWidth),
        parentUsesSize: true,
      );
      childrenList.add(child);
      child =
          (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
    }

    // Check if single-row horizontal layout fits
    double totalHorizontalWidth = 0;
    double maxChildHeight = 0;
    for (final c in childrenList) {
      totalHorizontalWidth += c.size.width;
      if (c.size.height > maxChildHeight) {
        maxChildHeight = c.size.height;
      }
    }
    totalHorizontalWidth += (childrenList.length - 1) * spacing;

    final fitsInOneRow = totalHorizontalWidth <= maxLayoutWidth;

    if (fitsInOneRow) {
      // MODE 1: SINGLE ROW
      if (_hasLeading) {
        // Leading child placed on far left
        final leadingChild = childrenList.first;
        final leadingData =
            leadingChild.parentData! as ResponsiveDialogActionsParentData;
        leadingData.offset = Offset(
          0,
          (maxChildHeight - leadingChild.size.height) / 2,
        );

        // Actions placed on far right
        double curX = maxLayoutWidth;
        for (int i = childrenList.length - 1; i >= 1; i--) {
          final action = childrenList[i];
          final actionData =
              action.parentData! as ResponsiveDialogActionsParentData;
          curX -= action.size.width;
          actionData.offset = Offset(
            curX,
            (maxChildHeight - action.size.height) / 2,
          );
          curX -= spacing;
        }
      } else {
        // All children placed on the right
        double curX = maxLayoutWidth;
        for (int i = childrenList.length - 1; i >= 0; i--) {
          final action = childrenList[i];
          final actionData =
              action.parentData! as ResponsiveDialogActionsParentData;
          curX -= action.size.width;
          actionData.offset = Offset(
            curX,
            (maxChildHeight - action.size.height) / 2,
          );
          curX -= spacing;
        }
      }
      size = constraints.constrain(Size(maxLayoutWidth, maxChildHeight));
    } else {
      // MODE 2: INTENTIONAL STACKED LAYOUT
      if (_hasLeading && childrenList.length == 3) {
        final leading = childrenList[0];
        final secondary = childrenList[1];
        final primary = childrenList[2];

        final row2Width = leading.size.width + spacing + secondary.size.width;
        if (row2Width <= maxLayoutWidth) {
          // 2-row layout: Primary on top (right-aligned), Secondary + Leading on bottom
          final primaryData =
              primary.parentData! as ResponsiveDialogActionsParentData;
          final leadingData =
              leading.parentData! as ResponsiveDialogActionsParentData;
          final secondaryData =
              secondary.parentData! as ResponsiveDialogActionsParentData;

          primaryData.offset = Offset(maxLayoutWidth - primary.size.width, 0);

          final y2 = primary.size.height + runSpacing;
          final h2 = math.max(leading.size.height, secondary.size.height);

          leadingData.offset = Offset(0, y2 + (h2 - leading.size.height) / 2);
          secondaryData.offset = Offset(
            maxLayoutWidth - secondary.size.width,
            y2 + (h2 - secondary.size.height) / 2,
          );

          size = constraints.constrain(Size(maxLayoutWidth, y2 + h2));
          return;
        }
      } else if (_hasLeading && childrenList.length == 2) {
        final leading = childrenList[0];
        final action = childrenList[1];

        final leadingData =
            leading.parentData! as ResponsiveDialogActionsParentData;
        final actionData =
            action.parentData! as ResponsiveDialogActionsParentData;

        // Row 1: Leading link left-aligned
        leadingData.offset = Offset.zero;

        // Row 2: Action button right-aligned at the bottom
        final y2 = leading.size.height + runSpacing;
        actionData.offset = Offset(maxLayoutWidth - action.size.width, y2);

        size = constraints.constrain(
          Size(maxLayoutWidth, y2 + action.size.height),
        );
        return;
      }

      // Fallback for extreme constraints: clean vertical column of all actions
      if (_hasLeading && childrenList.length == 3) {
        final leading = childrenList[0];
        final secondary = childrenList[1];
        final primary = childrenList[2];

        final primaryData =
            primary.parentData! as ResponsiveDialogActionsParentData;
        final secondaryData =
            secondary.parentData! as ResponsiveDialogActionsParentData;
        final leadingData =
            leading.parentData! as ResponsiveDialogActionsParentData;

        // Row 1: Primary action top-right (preserves visual hierarchy from 2-row layout)
        primaryData.offset = Offset(maxLayoutWidth - primary.size.width, 0);

        // Row 2: Secondary action middle-right
        final y2 = primary.size.height + runSpacing;
        secondaryData.offset = Offset(
          maxLayoutWidth - secondary.size.width,
          y2,
        );

        // Row 3: Leading link bottom-left
        final y3 = y2 + secondary.size.height + runSpacing;
        leadingData.offset = Offset(0, y3);

        size = constraints.constrain(
          Size(maxLayoutWidth, y3 + leading.size.height),
        );
        return;
      }

      double curY = 0;
      for (final c in childrenList) {
        final data = c.parentData! as ResponsiveDialogActionsParentData;
        data.offset = Offset(maxLayoutWidth - c.size.width, curY);
        curY += c.size.height + runSpacing;
      }
      size = constraints.constrain(Size(maxLayoutWidth, curY - runSpacing));
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (childCount == 0) return;

    final children = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      children.add(child);
      child =
          (child.parentData as ResponsiveDialogActionsParentData).nextSibling;
    }

    // Sort children by visual reading order: top-to-bottom (Y), then left-to-right (X)
    children.sort((a, b) {
      final aData = a.parentData! as ResponsiveDialogActionsParentData;
      final bData = b.parentData! as ResponsiveDialogActionsParentData;
      final dyDiff = (aData.offset.dy - bData.offset.dy).abs();
      // If within 4 pixels vertically, consider them on the same horizontal row
      if (dyDiff > 4.0) {
        return aData.offset.dy.compareTo(bData.offset.dy);
      }
      return aData.offset.dx.compareTo(bData.offset.dx);
    });

    for (final c in children) {
      visitor(c);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
