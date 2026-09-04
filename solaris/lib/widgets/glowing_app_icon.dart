import 'dart:io';
import 'package:flutter/material.dart';
import '../services/accent_color_extractor.dart';
import '../services/icon_cache_service.dart';

/// Renders a high-resolution application icon extracted from Windows (.exe)
/// with an automatic glowing shadow based on the dominant palette.
class GlowingAppIcon extends StatefulWidget {
  final String name; // exeName (e.g. 'Code.exe' or 'Photoshop.exe')
  final String? exePath;
  final String? fallbackLetter;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  /// Creates a beautiful glowing icon with glassmorphism blur and a fallback letter.
  const GlowingAppIcon({
    super.key,
    required this.name,
    this.exePath,
    this.fallbackLetter,
    this.size = 36.0,
    this.borderRadius = 10.0,
    this.onTap,
  });

  /// Clears in-memory static cache for a specific application.
  static void clearCacheFor(String name, {String? exePath}) {
    _GlowingAppIconState.clearCacheFor(name, exePath: exePath);
  }

  @visibleForTesting
  static bool isFailed(String name, {String? exePath}) =>
      _GlowingAppIconState.isFailed(name, exePath: exePath);

  @visibleForTesting
  static void resetStaticCaches() => _GlowingAppIconState.resetStaticCaches();

  @override
  State<GlowingAppIcon> createState() => _GlowingAppIconState();
}

class _GlowingAppIconState extends State<GlowingAppIcon> {
  // Static in-memory caches to prevent lag and placeholder flicker on scroll
  static final Map<String, String> _resolvedIconPaths = {};
  static final Map<String, Color> _resolvedAccentColors = {};
  static final Map<String, DateTime> _failedIcons = {};
  static const Duration _failedCooldown = Duration(seconds: 45);

  static String _getCacheKey(String name, String? exePath) {
    if (exePath != null && exePath.trim().isNotEmpty) {
      return exePath.trim().toLowerCase();
    }
    return name.trim().toLowerCase();
  }

  static bool isFailed(String name, {String? exePath}) {
    final timestamp = _failedIcons[_getCacheKey(name, exePath)];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _failedCooldown;
  }

  static void resetStaticCaches() {
    _resolvedIconPaths.clear();
    _resolvedAccentColors.clear();
    _failedIcons.clear();
  }

  static void clearCacheFor(String name, {String? exePath}) {
    final key = _getCacheKey(name, exePath);
    final oldPath =
        _resolvedIconPaths.remove(key) ??
        _resolvedIconPaths.remove(name.trim().toLowerCase());
    _resolvedAccentColors.remove(key);
    _resolvedAccentColors.remove(name.trim().toLowerCase());
    _failedIcons.remove(key);
    _failedIcons.remove(name.trim().toLowerCase());
    if (oldPath != null) {
      try {
        FileImage(File(oldPath)).evict();
      } catch (_) {}
    }
  }

  String? _iconPath;
  Color? _accentColor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCacheOrLoad();
  }

  @override
  void didUpdateWidget(GlowingAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _getCacheKey(widget.name, widget.exePath);
    final oldKey = _getCacheKey(oldWidget.name, oldWidget.exePath);
    if (oldKey != key ||
        oldWidget.exePath != widget.exePath ||
        _iconPath != _resolvedIconPaths[key]) {
      _checkCacheOrLoad();
    }
  }

  void _checkCacheOrLoad() {
    final key = _getCacheKey(widget.name, widget.exePath);
    final cachedPath = _resolvedIconPaths[key];
    final cachedColor = _resolvedAccentColors[key];
    final failedAt = _failedIcons[key];
    final bool isRecentlyFailed =
        failedAt != null &&
        DateTime.now().difference(failedAt) < _failedCooldown;

    if (cachedPath != null) {
      _iconPath = cachedPath;
      _accentColor = cachedColor;
      _isLoading = false;
    } else if (isRecentlyFailed) {
      _iconPath = null;
      _accentColor = null;
      _isLoading = false;
    } else {
      _iconPath = null;
      _accentColor = null;
      _isLoading = true;
      _loadIcon();
    }
  }

  int _loadGeneration = 0;

  Future<void> _loadIcon() async {
    final int generation = ++_loadGeneration;
    final String currentName = widget.name;
    final String? currentExePath = widget.exePath;
    final String key = _getCacheKey(currentName, currentExePath);

    // Only set loading if we don't have cached values for this widget instance already
    if (!_isLoading || _iconPath != null) {
      setState(() {
        _isLoading = true;
        _accentColor = null;
        _iconPath = null;
      });
    }

    try {
      final cache = await IconCacheService.instance;
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      String? path = await cache.getCachedIconPath(
        currentName,
        exePath: currentExePath,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      if (path != null) {
        _resolvedIconPaths[key] = path;
        _failedIcons.remove(key);

        // Reuse extracted color if we already processed this app's palette
        Color? accentColor = _resolvedAccentColors[key];
        if (accentColor == null) {
          accentColor = await AccentColorExtractor.extractAccentColor(path);
          _resolvedAccentColors[key] = accentColor;
        }

        if (!mounted || generation != _loadGeneration) {
          return;
        }

        setState(() {
          _iconPath = path;
          _accentColor = accentColor;
          _isLoading = false;
        });
      } else {
        _failedIcons[key] = DateTime.now();
        if (!mounted || generation != _loadGeneration) {
          return;
        }
        setState(() {
          _iconPath = null;
          _accentColor = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      _failedIcons[key] = DateTime.now();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _iconPath = null;
          _accentColor = null;
          _isLoading = false;
        });
      }
    }
  }

  (Color, Color, String) _getFallbackStyling() {
    final String cleanFallback = widget.fallbackLetter?.trim() ?? '';
    final String cleanName = widget.name.trim();
    final String fallbackSource = cleanFallback.isNotEmpty
        ? cleanFallback
        : cleanName;
    final firstLetter = fallbackSource.characters.isNotEmpty
        ? fallbackSource.characters.first.toUpperCase()
        : '?';

    // Stable deterministic cross-session hash
    int colorHash = 0;
    for (final codeUnit in fallbackSource.codeUnits) {
      colorHash = (colorHash * 31 + codeUnit) & 0x7FFFFFFF;
    }

    final hue1 = (colorHash % 360).toDouble();
    final hue2 = ((colorHash + 40) % 360).toDouble();

    final color1 = HSLColor.fromAHSL(1.0, hue1, 0.7, 0.5).toColor();
    final color2 = HSLColor.fromAHSL(1.0, hue2, 0.7, 0.3).toColor();

    return (color1, color2, firstLetter);
  }

  Widget _buildFallbackInner(Color color1, Color color2, String firstLetter) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.size * 0.48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final (color1, color2, firstLetter) = _getFallbackStyling();
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildFallbackInner(color1, color2, firstLetter),
    );
  }

  Widget _buildImage() {
    final Color glowColor = _accentColor ?? const Color(0xFF6366F1);
    final double pixelRatio =
        MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final int targetCacheDimension = (widget.size * pixelRatio).round().clamp(
      16,
      512,
    );
    final (fallbackColor1, fallbackColor2, fallbackLetter) =
        _getFallbackStyling();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          // Elegant glow from the extracted logo accent color
          if (_accentColor != null)
            BoxShadow(
              color: _accentColor!.withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: glowColor.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.file(
          File(_iconPath!),
          key: ValueKey(_iconPath!),
          width: widget.size,
          height: widget.size,
          cacheWidth: targetCacheDimension,
          cacheHeight: targetCacheDimension,
          filterQuality: FilterQuality.high,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final pathToDelete = _iconPath;
            final failedKey = _getCacheKey(widget.name, widget.exePath);
            _resolvedIconPaths.remove(failedKey);
            _resolvedAccentColors.remove(failedKey);
            _failedIcons[failedKey] = DateTime.now();
            if (pathToDelete != null) {
              try {
                File(pathToDelete).deleteSync();
              } catch (_) {}
              try {
                FileImage(File(pathToDelete)).evict();
              } catch (_) {}
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _iconPath != null) {
                setState(() {
                  _iconPath = null;
                });
              }
            });
            return _buildFallbackInner(
              fallbackColor1,
              fallbackColor2,
              fallbackLetter,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _iconPath != null ? _buildImage() : _buildFallback();

    // Isolate shadow blur rasterization to prevent parent layer repaints on scroll
    content = RepaintBoundary(child: content);

    if (widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: widget.onTap, child: content),
      );
    }

    return content;
  }
}
