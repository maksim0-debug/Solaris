import 'package:flutter/material.dart';

class DeepLinkTarget extends StatefulWidget {
  final String id;
  final Widget child;
  final VoidCallback? onDeepLink;
  const DeepLinkTarget({
    super.key,
    required this.id,
    required this.child,
    this.onDeepLink,
  });

  @override
  State<DeepLinkTarget> createState() => DeepLinkTargetState();
}

class DeepLinkTargetState extends State<DeepLinkTarget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void highlight() {
    _controller.forward(from: 0);
    widget.onDeepLink?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (_controller.value > 0)
                BoxShadow(
                  color: const Color(0xFFFDBA74).withOpacity(0.3 * _glowAnimation.value),
                  blurRadius: 30 * _glowAnimation.value,
                  spreadRadius: 5 * _glowAnimation.value,
                ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
