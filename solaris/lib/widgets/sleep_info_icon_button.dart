import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// An informative icon button designed for Solaris sleep controls.
///
/// Features a rich dark-navy tooltip card with regex-based highlight formatting
/// for quoted action terms, an adaptive icon button, and seamless handling
/// for both interactive actions and informative tap/hover inspection.
class SleepInfoIconButton extends StatefulWidget {
  final String tooltipMessage;
  final VoidCallback? onPressed;
  final double iconSize;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final double splashRadius;
  final bool? preferBelow;
  final double maxWidth;

  const SleepInfoIconButton({
    super.key,
    required this.tooltipMessage,
    this.onPressed,
    this.iconSize = 16,
    this.constraints = const BoxConstraints(minWidth: 32, minHeight: 32),
    this.padding = const EdgeInsets.all(4),
    this.splashRadius = 18,
    this.preferBelow,
    this.maxWidth = 350,
  });

  @override
  State<SleepInfoIconButton> createState() => _SleepInfoIconButtonState();
}

class _SleepInfoIconButtonState extends State<SleepInfoIconButton> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  static final RegExp _richHighlightRegex = RegExp(r'(«\+[^»]+»|"\+[^"]+")');

  InlineSpan _buildRichMessage(String text) {
    final matches = _richHighlightRegex.allMatches(text);
    if (matches.isEmpty) {
      return TextSpan(text: text);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(children: spans);
  }

  void _handlePress() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      _tooltipKey.currentState?.ensureTooltipVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        key: _tooltipKey,
        richMessage: _buildRichMessage(widget.tooltipMessage),
        waitDuration: const Duration(milliseconds: 150),
        preferBelow: widget.preferBelow,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.45,
          fontFamily: 'Outfit',
        ),
        child: IconButton(
          mouseCursor: SystemMouseCursors.click,
          icon: Icon(
            LucideIcons.info,
            size: widget.iconSize,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          onPressed: _handlePress,
          constraints: widget.constraints,
          padding: widget.padding,
          splashRadius: widget.splashRadius,
        ),
      ),
    );
  }
}
