import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/setting_item.dart';
import 'package:solaris/services/settings_search_service.dart';
import 'package:solaris/providers.dart';
import 'package:flutter/services.dart';

class SettingsSearchOverlay extends ConsumerStatefulWidget {
  const SettingsSearchOverlay({super.key});

  @override
  ConsumerState<SettingsSearchOverlay> createState() => _SettingsSearchOverlayState();
}

class _SettingsSearchOverlayState extends ConsumerState<SettingsSearchOverlay> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  List<SettingItem> _results = [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final service = ref.read(settingsSearchServiceProvider(context));
      final results = service.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  void _close() {
    _animationController.reverse().then((_) {
      ref.read(isSearchVisibleProvider.notifier).setVisible(false);
    });
  }

  void _handleResultClick(SettingItem item) {
    ref.read(activeScreenProvider.notifier).setScreen(item.screen);
    if (item.anchorId != null) {
      ref.read(searchAnchorProvider.notifier).setAnchor(item.anchorId);
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
        children: [
          // Semi-transparent backdrop
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withOpacity(0.4),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Search UI
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 600,
                  constraints: const BoxConstraints(maxHeight: 500),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Input Area
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    onChanged: _onSearchChanged,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: l10n.searchPlaceholder,
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (val) {
                                      if (_results.isNotEmpty) {
                                        _handleResultClick(_results.first);
                                      }
                                    },
                                  ),
                                ),
                                if (_isSearching)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFDBA74),
                                    ),
                                  )
                                else if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(LucideIcons.x, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    color: Colors.white30,
                                  ),
                              ],
                            ),
                          ),
                          
                          const Divider(height: 1, color: Colors.white12),
                          
                          // Results Area
                          Flexible(
                            child: _results.isEmpty && _searchController.text.isNotEmpty && !_isSearching
                                ? _NoResultsWidget(query: _searchController.text)
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _results.length,
                                    itemBuilder: (context, index) {
                                      final item = _results[index];
                                      return _SearchResultTile(
                                        item: item,
                                        onTap: () => _handleResultClick(item),
                                      );
                                    },
                                  ),
                          ),
                          
                          // Footer / Keyboard Hint
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                            ),
                            child: Row(
                              children: [
                                _ShortcutKeyHint(label: 'Enter', description: l10n.selectMonitor),
                                const SizedBox(width: 16),
                                _ShortcutKeyHint(label: 'Esc', description: l10n.close),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _SearchResultTile extends StatefulWidget {
  final SettingItem item;
  final VoidCallback onTap;

  const _SearchResultTile({required this.item, required this.onTap});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovering ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getScreenColor(widget.item.screen).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getScreenIcon(widget.item.screen),
                  color: _getScreenColor(widget.item.screen),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: _isHovering ? Colors.white54 : Colors.white12,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScreenColor(AppScreen screen) {
    switch (screen) {
      case AppScreen.dashboard: return const Color(0xFFFDBA74);
      case AppScreen.schedule: return const Color(0xFF38BDF8);
      case AppScreen.settings: return const Color(0xFF94A3B8);
      case AppScreen.location: return const Color(0xFF4ADE80);
      case AppScreen.sleep: return const Color(0xFFA78BFA);
    }
  }

  IconData _getScreenIcon(AppScreen screen) {
    switch (screen) {
      case AppScreen.dashboard: return LucideIcons.layoutGrid;
      case AppScreen.schedule: return LucideIcons.activity;
      case AppScreen.settings: return LucideIcons.settings;
      case AppScreen.location: return LucideIcons.mapPin;
      case AppScreen.sleep: return LucideIcons.moon;
    }
  }
}

class _NoResultsWidget extends StatelessWidget {
  final String query;
  const _NoResultsWidget({required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.searchX, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            l10n.noResultsFound(query),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutKeyHint extends StatelessWidget {
  final String label;
  final String description;

  const _ShortcutKeyHint({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          description,
          style: TextStyle(
            color: Colors.white24,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
