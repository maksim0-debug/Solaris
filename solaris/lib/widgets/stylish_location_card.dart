import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/weather_overlay.dart';

class StylishLocationCard extends ConsumerWidget {
  const StylishLocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(effectiveLocationProvider);
    final solarAsync = ref.watch(solarStateStreamProvider);
    final weatherAsync = ref.watch(currentWeatherProvider);

    return solarAsync.maybeWhen(
      data: (solarState) {
        final elevation = solarState.sunElevation;
        // Determine style and colors based on elevation
        final bool isNight = elevation < -6;

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

                if (weatherAsync.value != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: WeatherOverlay(
                        weatherCode: weatherAsync.value!.weatherCode,
                        cloudCover: weatherAsync.value!.cloudCover,
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              l10n.liveLocation,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.compass,
                            size: 20,
                            color:
                                accentColor, // The compass icon now matches the theme
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        locationAsync.maybeWhen(
                          data: (pos) => l10n.latLonFormat(
                            pos.latitude.toStringAsFixed(4),
                            pos.longitude.toStringAsFixed(4),
                          ),
                          orElse: () => l10n.detectingLocation,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        locationAsync.maybeWhen(
                          data: (pos) => _formatDMS(pos.latitude, pos.longitude, l10n),
                          orElse: () => l10n.coordinatesUnavailable,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
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

  String _formatDMS(double lat, double lon, AppLocalizations l10n) {
    String latDir = lat >= 0 ? l10n.north : l10n.south;
    String lonDir = lon >= 0 ? l10n.east : l10n.west;

    double absLat = lat.abs();
    int latDeg = absLat.floor();
    int latMin = ((absLat - latDeg) * 60).floor();
    int latSec = (((absLat - latDeg) * 60 - latMin) * 60).floor();

    double absLon = lon.abs();
    int lonDeg = absLon.floor();
    int lonMin = ((absLon - lonDeg) * 60).floor();
    int lonSec = (((absLon - lonDeg) * 60 - lonMin) * 60).floor();

    return l10n.dmsFormat(
      latDeg,
      latMin,
      latSec,
      latDir,
      lonDeg,
      lonMin,
      lonSec,
      lonDir,
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
