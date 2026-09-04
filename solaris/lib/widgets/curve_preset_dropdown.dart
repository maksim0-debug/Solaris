import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';

class CurvePresetOption {
  final String id;
  final String title;
  final bool isSystem;

  const CurvePresetOption({
    required this.id,
    required this.title,
    required this.isSystem,
  });
}

class CurvePresetDropdown extends StatefulWidget {
  final String? currentId;
  final List<CurvePresetOption> systemOptions;
  final List<CurvePresetOption> userOptions;
  final ValueChanged<String> onSelected;
  final AppLocalizations l10n;
  final IconData icon;
  final Color accentColor;

  const CurvePresetDropdown({
    super.key,
    required this.currentId,
    required this.systemOptions,
    required this.userOptions,
    required this.onSelected,
    required this.l10n,
    this.icon = LucideIcons.activity,
    this.accentColor = const Color(0xFFFDBA74),
  });

  @override
  State<CurvePresetDropdown> createState() => _CurvePresetDropdownState();
}

class _CurvePresetDropdownState extends State<CurvePresetDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isOpen) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final triggerOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final screenSize = MediaQuery.of(context).size;

    final menuWidth = size.width.clamp(240.0, 320.0);

    // Calculate space below and above to decide whether to open downwards or upwards
    final spaceBelow = screenSize.height - triggerOffset.dy - size.height - 16;
    final spaceAbove = triggerOffset.dy - 16;

    final bool showAbove = spaceBelow < 300 && spaceAbove > spaceBelow;
    final double maxCalculatedHeight = (showAbove ? spaceAbove : spaceBelow)
        .clamp(180.0, 420.0);

    final Alignment targetAnchor = showAbove
        ? Alignment.topRight
        : Alignment.bottomRight;
    final Alignment followerAnchor = showAbove
        ? Alignment.bottomRight
        : Alignment.topRight;
    final Offset followerOffset = Offset(0, showAbove ? -6 : 6);
    final Alignment scaleAlignment = showAbove
        ? Alignment.bottomRight
        : Alignment.topRight;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Fullscreen barrier for click-outside dismissal
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child: const SizedBox.expand(),
              ),
            ),
            // Floating Dropdown Menu
            Positioned(
              width: menuWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: targetAnchor,
                followerAnchor: followerAnchor,
                offset: followerOffset,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    alignment: scaleAlignment,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: 240,
                          maxWidth: 320,
                          maxHeight: maxCalculatedHeight,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: RawScrollbar(
                            thumbColor: Colors.white.withValues(alpha: 0.25),
                            radius: const Radius.circular(4),
                            thickness: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildMenuItems(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
    _animationController.forward();
  }

  void _closeDropdown({bool immediate = false}) {
    if (!_isOpen && _overlayEntry == null) return;

    if (immediate) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOpen = false;
      return;
    }

    _animationController.reverse().then((_) {
      if (mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        setState(() {
          _isOpen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Find current option
    CurvePresetOption? currentOption;
    for (final opt in widget.systemOptions) {
      if (opt.id == widget.currentId) {
        currentOption = opt;
        break;
      }
    }
    if (currentOption == null) {
      for (final opt in widget.userOptions) {
        if (opt.id == widget.currentId) {
          currentOption = opt;
          break;
        }
      }
    }

    // Fallback if none found
    currentOption ??= widget.systemOptions.isNotEmpty
        ? widget.systemOptions.first
        : const CurvePresetOption(id: '', title: '—', isSystem: true);

    final selectedTitle = currentOption.title;
    final isCurrentSystem = currentOption.isSystem;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: widget.l10n.selectPreset,
        child: InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isOpen
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isOpen
                    ? widget.accentColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Category Badge Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentSystem
                        ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                        : const Color(0xFFA855F7).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCurrentSystem
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFFA855F7).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    isCurrentSystem
                        ? widget.l10n.presetSystemPrefix
                        : widget.l10n.presetUserPrefix,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCurrentSystem
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFFE9D5FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> items = [];

    // 1. Header: System Presets
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 13,
              color: Color(0xFF818CF8),
            ),
            const SizedBox(width: 6),
            Text(
              widget.l10n.presetSystemPrefix.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );

    // System options
    for (final option in widget.systemOptions) {
      final isSelected = option.id == widget.currentId;
      items.add(
        _MenuItemTile(
          option: option,
          isSelected: isSelected,
          activeColor: const Color(0xFF6366F1),
          activeTextColor: const Color(0xFFA5B4FC),
          iconData: LucideIcons.sparkles,
          onTap: () {
            widget.onSelected(option.id);
            _closeDropdown();
          },
        ),
      );
    }

    // Divider
    items.add(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );

    // 2. Header: User Presets
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            const Icon(LucideIcons.user, size: 13, color: Color(0xFFC084FC)),
            const SizedBox(width: 6),
            Text(
              widget.l10n.presetUserPrefix.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.userOptions.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    } else {
      for (final option in widget.userOptions) {
        final isSelected = option.id == widget.currentId;
        items.add(
          _MenuItemTile(
            option: option,
            isSelected: isSelected,
            activeColor: const Color(0xFFA855F7),
            activeTextColor: const Color(0xFFE9D5FF),
            iconData: LucideIcons.user,
            onTap: () {
              widget.onSelected(option.id);
              _closeDropdown();
            },
          ),
        );
      }
    }

    return items;
  }
}

class _MenuItemTile extends StatefulWidget {
  final CurvePresetOption option;
  final bool isSelected;
  final Color activeColor;
  final Color activeTextColor;
  final IconData iconData;
  final VoidCallback onTap;

  const _MenuItemTile({
    required this.option,
    required this.isSelected,
    required this.activeColor,
    required this.activeTextColor,
    required this.iconData,
    required this.onTap,
  });

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.activeColor.withValues(alpha: 0.18)
                  : (_isHovered
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
                  ? Border.all(
                      color: widget.activeColor.withValues(alpha: 0.4),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.iconData,
                  size: 14,
                  color: widget.isSelected
                      ? widget.activeTextColor
                      : Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.option.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: widget.isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (widget.isSelected)
                  Icon(
                    LucideIcons.check,
                    size: 15,
                    color: widget.activeTextColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
