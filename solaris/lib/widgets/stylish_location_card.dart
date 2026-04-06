import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/weather_overlay.dart';

import 'package:solaris/widgets/deep_link_target.dart';

class StylishLocationCard extends ConsumerWidget {
  final GlobalKey<DeepLinkTargetState>? anchorKey;
  const StylishLocationCard({super.key, this.anchorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(effectiveLocationProvider);
    final solarAsync = ref.watch(solarStateStreamProvider);
    final weatherAsync = ref.watch(currentWeatherProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return solarAsync.maybeWhen(
      data: (solarState) {
        // Determine style and colors based on settings or sun elevation
        final settings = settingsAsync.value?['all'] ?? SettingsState();
        final bool isNight = switch (settings.mapStyleMode) {
          MapStyleMode.auto => solarState.sunElevation < -6,
          MapStyleMode.day => false,
          MapStyleMode.night => true,
        };

        final String mapStyle = isNight ? kMapboxNightStyle : kMapboxDayStyle;

        final Color accentColor = isNight
            ? Colors.blueAccent
            : const Color(0xFFFDBA74);

        return AspectRatio(
          aspectRatio: 1,
          child: GlassCard(
            padding: EdgeInsets.zero,
            glowColor: accentColor,
            child: Stack(
              children: [
                // Background Image (Stylized Mapbox)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: locationAsync.maybeWhen(
                      data: (pos) => CachedNetworkImage(
                        imageUrl: getStaticMapUrl(
                          pos.latitude,
                          pos.longitude,
                          style: mapStyle,
                        ),
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 500),
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: accentColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF0F172A),
                          child: const Icon(
                            LucideIcons.map,
                            color: Colors.white10,
                            size: 48,
                          ),
                        ),
                      ),
                      orElse: () => Container(color: const Color(0xFF0F172A)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: settingsAsync.maybeWhen(
                      data: (settingsMap) {
                        final settings = settingsMap['all'] ?? SettingsState();
                        final weather = weatherAsync.value;
                        if (weather == null) return const SizedBox.shrink();
                        return WeatherOverlay(
                          weatherCode: weather.weatherCode,
                          cloudCover: weather.cloudCover,
                          showRain: settings.showRainAnimation,
                          showSnow: settings.showSnowAnimation,
                          showThunder: settings.showThunderAnimation,
                          showClouds: settings.showCloudAnimation,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Gradient Overlay for contrast
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pulsing Radar Marker
                Positioned.fill(
                  child: Center(
                    child: PulsingLocationMarker(color: accentColor),
                  ),
                ),

                // Card Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _WeatherSettingsButton(
                            accentColor: accentColor,
                            anchorKey: anchorKey,
                          ),
                          Icon(
                            LucideIcons.compass,
                            size: 20,
                            color: accentColor,
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          locationAsync.maybeWhen(
                            data: (pos) => l10n.latLonFormat(
                              pos.latitude.toStringAsFixed(4),
                              pos.longitude.toStringAsFixed(4),
                            ),
                            orElse: () => l10n.detectingLocation,
                          ),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class PulsingLocationMarker extends ConsumerStatefulWidget {
  final Color color;
  const PulsingLocationMarker({super.key, required this.color});

  @override
  ConsumerState<PulsingLocationMarker> createState() =>
      _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends ConsumerState<PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Initial start if visible
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch visibility to stop/start animation
    final visibility = ref.watch(appLifecycleProvider);

    if (visibility == AppVisibilityState.visible) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Expanding circle (pulse)
            Container(
              width: 40 + (_controller.value * 40),
              height: 40 + (_controller.value * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withOpacity(1.0 - _controller.value),
                  width: 1.5,
                ),
              ),
            ),
            // Inner glow
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.2),
              ),
            ),
            // Solid center point
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeatherSettingsButton extends ConsumerStatefulWidget {
  final Color accentColor;
  final GlobalKey<DeepLinkTargetState>? anchorKey;
  const _WeatherSettingsButton({required this.accentColor, this.anchorKey});

  @override
  ConsumerState<_WeatherSettingsButton> createState() => _WeatherSettingsButtonState();
}

class _WeatherSettingsButtonState extends ConsumerState<_WeatherSettingsButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _togglePopover() {
    if (_isOpen) {
      _closePopover();
    } else {
      _showPopover();
    }
  }

  void _showPopover() {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible barrier to close on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _closePopover,
              behavior: HitTestBehavior.opaque,
              child: Container(),
            ),
          ),
          Positioned(
            width: 280,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-14, -315), // Adjusted offset to align better with the card
              child: Material(
                color: Colors.transparent,
                child: Consumer(
                  builder: (context, ref, child) {
                    final settingsAsync = ref.watch(settingsProvider);
                    final solarAsync = ref.watch(solarStateStreamProvider);

                    return settingsAsync.maybeWhen(
                      data: (settingsMap) {
                        final settings =
                            settingsMap['all'] ?? SettingsState();
                        final solarState = solarAsync.value;

                        final bool isNight = switch (settings.mapStyleMode) {
                          MapStyleMode.auto =>
                            (solarState?.sunElevation ?? 0) < -6,
                          MapStyleMode.day => false,
                          MapStyleMode.night => true,
                        };

                        final Color dynamicAccentColor = isNight
                            ? Colors.blueAccent
                            : const Color(0xFFFDBA74);

                        return GlassCard(
                          glowColor: dynamicAccentColor,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.map,
                                      color: dynamicAccentColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.mapSettings,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(LucideIcons.x,
                                        size: 14, color: Colors.white54),
                                    onPressed: _closePopover,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Map Style Section
                              _MapStyleDropdown(
                                currentMode: settings.mapStyleMode,
                                onSelected: (mode) => ref
                                    .read(settingsProvider.notifier)
                                    .updateMapStyleMode(mode),
                                accentColor: dynamicAccentColor,
                                l10n: l10n,
                              ),
                              const Divider(color: Colors.white12, height: 24),
                              // Weather Animations Section
                              Row(
                                children: [
                                  Icon(LucideIcons.cloudRain,
                                      color:
                                          dynamicAccentColor.withOpacity(0.7),
                                      size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.weatherAnimations,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _WeatherToggleRow(
                                label: l10n.showRain,
                                value: settings.showRainAnimation,
                                onChanged: (val) => ref
                                    .read(settingsProvider.notifier)
                                    .updateShowRainAnimation(val),
                                accentColor: dynamicAccentColor,
                              ),
                              _WeatherToggleRow(
                                label: l10n.showSnow,
                                value: settings.showSnowAnimation,
                                onChanged: (val) => ref
                                    .read(settingsProvider.notifier)
                                    .updateShowSnowAnimation(val),
                                accentColor: dynamicAccentColor,
                              ),
                              _WeatherToggleRow(
                                label: l10n.showThunder,
                                value: settings.showThunderAnimation,
                                onChanged: (val) => ref
                                    .read(settingsProvider.notifier)
                                    .updateShowThunderAnimation(val),
                                accentColor: dynamicAccentColor,
                              ),
                              _WeatherToggleRow(
                                label: l10n.showClouds,
                                value: settings.showCloudAnimation,
                                onChanged: (val) => ref
                                    .read(settingsProvider.notifier)
                                    .updateShowCloudAnimation(val),
                                accentColor: dynamicAccentColor,
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closePopover() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeepLinkTarget(
      key: widget.anchorKey,
      id: 'weather_animations',
      onDeepLink: () {
        if (!_isOpen) _togglePopover();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: IconButton(
          onPressed: _togglePopover,
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isOpen ? widget.accentColor.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.settings,
              size: 16,
              color: _isOpen ? widget.accentColor : widget.accentColor.withOpacity(0.8),
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 16,
          tooltip: _isOpen ? null : AppLocalizations.of(context)!.mapSettings,
        ),
      ),
    );
  }
}

class _MapStyleDropdown extends StatefulWidget {
  final MapStyleMode currentMode;
  final ValueChanged<MapStyleMode> onSelected;
  final Color accentColor;
  final AppLocalizations l10n;

  const _MapStyleDropdown({
    required this.currentMode,
    required this.onSelected,
    required this.accentColor,
    required this.l10n,
  });

  @override
  State<_MapStyleDropdown> createState() => _MapStyleDropdownState();
}

class _MapStyleDropdownState extends State<_MapStyleDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currentLabel = switch (widget.currentMode) {
      MapStyleMode.auto => widget.l10n.mapStyleAuto,
      MapStyleMode.day => widget.l10n.mapStyleDay,
      MapStyleMode.night => widget.l10n.mapStyleNight,
    };

    final currentIcon = switch (widget.currentMode) {
      MapStyleMode.auto => LucideIcons.refreshCw,
      MapStyleMode.day => LucideIcons.sun,
      MapStyleMode.night => LucideIcons.moon,
    };

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isExpanded ? widget.accentColor.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(currentIcon, size: 16, color: widget.accentColor),
                const SizedBox(width: 12),
                Text(
                  currentLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
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
        if (_isExpanded) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _MapStyleOption(
                  label: widget.l10n.mapStyleAuto,
                  icon: LucideIcons.refreshCw,
                  isSelected: widget.currentMode == MapStyleMode.auto,
                  onTap: () {
                    widget.onSelected(MapStyleMode.auto);
                    setState(() => _isExpanded = false);
                  },
                  accentColor: widget.accentColor,
                ),
                _MapStyleOption(
                  label: widget.l10n.mapStyleDay,
                  icon: LucideIcons.sun,
                  isSelected: widget.currentMode == MapStyleMode.day,
                  onTap: () {
                    widget.onSelected(MapStyleMode.day);
                    setState(() => _isExpanded = false);
                  },
                  accentColor: widget.accentColor,
                ),
                _MapStyleOption(
                  label: widget.l10n.mapStyleNight,
                  icon: LucideIcons.moon,
                  isSelected: widget.currentMode == MapStyleMode.night,
                  onTap: () {
                    widget.onSelected(MapStyleMode.night);
                    setState(() => _isExpanded = false);
                  },
                  accentColor: widget.accentColor,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WeatherToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;

  const _WeatherToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13, // Slightly larger for better readability
            fontWeight: FontWeight.w500,
          ),
        ),
        Transform.scale(
          scale: 0.75, // Better balance
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
            activeTrackColor: accentColor.withOpacity(0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white10,
          ),
        ),
      ],
    );
  }
}

class _MapStyleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;

  const _MapStyleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color:
              isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : Colors.white54,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                LucideIcons.check,
                size: 16,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }
}
