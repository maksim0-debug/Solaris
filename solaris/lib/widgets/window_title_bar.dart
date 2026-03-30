import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/theme/app_theme.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.background,
      child: Stack(
        children: [
          // Drag area
          const DragToMoveArea(child: SizedBox.expand()),
          // Content
          Row(
            children: [
              const SizedBox(width: 16),
              // App Icon (Sun)
              const Icon(LucideIcons.sun, color: AppTheme.accent, size: 20),
              const SizedBox(width: 12),
              // App Title
              Text(
                'SOLARIS',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Window Controls
              const _WindowButtons(),
            ],
          ),
          // Bottom border/separator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WindowButton(
          icon: LucideIcons.minus,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: _isMaximized ? LucideIcons.copy : LucideIcons.square,
          onPressed: () async {
            if (_isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: LucideIcons.x,
          isClose: true,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(icon, size: 16, color: Colors.white60),
        hoverColor: isClose ? Colors.red.withOpacity(0.8) : Colors.white10,
        splashRadius: 24,
        onPressed: onPressed,
      ),
    );
  }
}
