import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackNavigationHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onBack;
  final bool enabled;

  const BackNavigationHandler({
    required this.child,
    required this.onBack,
    this.enabled = true,
    super.key,
  });

  @override
  State<BackNavigationHandler> createState() => _BackNavigationHandlerState();
}

class _BackNavigationHandlerState extends State<BackNavigationHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    // 0x08 = kBackMouseButton (mouse back side button / XButton1)
    if ((event.buttons & kBackMouseButton) != 0 || event.buttons == 8) {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        child: widget.child,
      ),
    );
  }
}
