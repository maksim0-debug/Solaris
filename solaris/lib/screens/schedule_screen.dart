import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/luminosity_graph.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final solarAsync = ref.watch(solarStateStreamProvider);
    final locationAsync = ref.watch(locationStreamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Graph and Coordinates
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Luminosity Profile Card
                        SizedBox(
                          height: 480,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.luminosityProfile,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          l10n.dragNodesToAdjust,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _HeaderButton(label: l10n.view24h),
                                        const SizedBox(width: 8),
                                        _HeaderButton(
                                          label: l10n.editCurve,
                                          isPrimary: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                Expanded(
                                  child: solarAsync.when(
                                    data: (state) => LuminosityGraph(
                                      phases: state.phases,
                                      currentElevation: state.sunElevation,
                                      lat:
                                          locationAsync.value?.latitude ??
                                          50.45,
                                      lon:
                                          locationAsync.value?.longitude ??
                                          30.52,
                                    ),
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (e, _) =>
                                        Center(child: Text('Error: $e')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Coordinate Cards
                        solarAsync.maybeWhen(
                          data: (state) => Row(
                            children: [
                              Expanded(
                                child: _CoordinateCard(
                                  label: l10n.azimuth,
                                  value:
                                      '${state.sunAzimuth.toStringAsFixed(1)}°',
                                  trend: state.azimuthTrend,
                                  trendIcon: state.azimuthTrend.startsWith('+')
                                      ? LucideIcons.trendingUp
                                      : (state.azimuthTrend.startsWith('-')
                                            ? LucideIcons.trendingDown
                                            : null),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _CoordinateCard(
                                  label: l10n.elevation,
                                  value:
                                      '${state.sunElevation.toStringAsFixed(1)}°',
                                  trend: state.elevationTrend,
                                  trendIcon:
                                      state.elevationTrend.startsWith('+')
                                      ? LucideIcons.trendingUp
                                      : (state.elevationTrend.startsWith('-')
                                            ? LucideIcons.trendingDown
                                            : null),
                                  trendColor:
                                      state.elevationTrend.startsWith('-')
                                      ? Colors.redAccent
                                      : const Color(0xFFFDBA74),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _CoordinateCard(
                                  label: l10n.zenith,
                                  value:
                                      '${state.sunZenith.toStringAsFixed(1)}°',
                                  trend: l10n.constant,
                                ),
                              ),
                            ],
                          ),
                          orElse: () => const SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Location and Telemetry
                  SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        // Live Location Card
                        AspectRatio(
                          aspectRatio: 1,
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Stack(
                              children: [
                                // Background Image (Stylized Mapbox)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.7, // Слегка приглушаем
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      // Используем ColorFiltered, чтобы убить пестрые цвета спутника
                                      // и подогнать под темную тему приложения
                                      child: ColorFiltered(
                                        colorFilter: const ColorFilter.matrix([
                                          0.2126,
                                          0.7152,
                                          0.0722,
                                          0,
                                          0, // Переводим в ЧБ
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0, 0, 0, 1, 0,
                                        ]),
                                        child: locationAsync.maybeWhen(
                                          data: (pos) => CachedNetworkImage(
                                            imageUrl: getStaticMapUrl(
                                              pos.latitude,
                                              pos.longitude,
                                            ),
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            // Красивый плейсхолдер пока грузится карта
                                            placeholder: (context, url) =>
                                                Container(
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Color(
                                                            0xFFFDBA74,
                                                          ),
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                                      color: const Color(
                                                        0xFF0F172A,
                                                      ),
                                                      child: const Icon(
                                                        LucideIcons.map,
                                                        color: Colors.white10,
                                                        size: 48,
                                                      ),
                                                    ),
                                          ),
                                          orElse: () => Container(
                                            color: const Color(0xFF0F172A),
                                          ), // Состояние загрузки локации
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Gradient Overlay (усиленный для читаемости)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.9),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Pulsing Radar Marker
                                Positioned.fill(
                                  child: Center(
                                    child: _PulsingLocationMarker(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                          const Icon(
                                            LucideIcons.compass,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        locationAsync.maybeWhen(
                                          data: (pos) =>
                                              'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}',
                                          orElse: () => 'Bila Tserkva, UA',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        locationAsync.maybeWhen(
                                          data: (pos) => _formatDMS(
                                            pos.latitude,
                                            pos.longitude,
                                          ),
                                          orElse: () =>
                                              '49.7900° N, 30.1300° E',
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
                        ),
                        const SizedBox(height: 24),
                        // Solar Telemetry Card
                        solarAsync.maybeWhen(
                          data: (state) {
                            final weatherAsync = ref.watch(
                              currentWeatherProvider,
                            );
                            final calcService = ref.watch(
                              sunCalculatorServiceProvider,
                            );

                            return GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.solarTelemetry,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _TelemetryRow(
                                    icon: LucideIcons.sun,
                                    label: l10n.civilTwilight,
                                    value:
                                        '${state.phases.civilTwilightBegin.hour.toString().padLeft(2, '0')}:${state.phases.civilTwilightBegin.minute.toString().padLeft(2, '0')}',
                                  ),
                                  const SizedBox(height: 16),
                                  _TelemetryRow(
                                    icon: LucideIcons.moon,
                                    label: l10n.astronomicalNight,
                                    value:
                                        '${state.phases.astronomicalDusk.hour.toString().padLeft(2, '0')}:${state.phases.astronomicalDusk.minute.toString().padLeft(2, '0')}',
                                  ),
                                  const SizedBox(height: 16),
                                  // Humidity row
                                  _TelemetryRow(
                                    icon: LucideIcons.droplets,
                                    label: l10n.humidity,
                                    value: weatherAsync.maybeWhen(
                                      data: (w) => w != null
                                          ? '${w.humidity.toStringAsFixed(0)}%'
                                          : '--%',
                                      orElse: () => '--%',
                                    ),
                                    iconColor: Colors.blueAccent,
                                  ),
                                  const SizedBox(height: 16),
                                  // Air Temp row
                                  _TelemetryRow(
                                    icon: LucideIcons.thermometer,
                                    label: l10n.airTemp,
                                    value: weatherAsync.maybeWhen(
                                      data: (w) => w != null
                                          ? '${w.temperature.toStringAsFixed(1)}°C'
                                          : '--°C',
                                      orElse: () => '--°C',
                                    ),
                                    iconColor: Colors.white70,
                                  ),
                                  const SizedBox(height: 16),
                                  // Updated Surface Temp row
                                  _TelemetryRow(
                                    icon: LucideIcons.thermometerSun,
                                    label: l10n.surfaceTemp,
                                    value: weatherAsync.maybeWhen(
                                      data: (w) {
                                        if (w == null) return '--°C';
                                        final surfTemp = calcService
                                            .getEstimatedSurfaceTemp(
                                              state.sunElevation,
                                              w.temperature,
                                            );
                                        return '${surfTemp.toStringAsFixed(1)}°C';
                                      },
                                      orElse: () => '--°C',
                                    ),
                                    iconColor: Colors.orange,
                                  ),
                                  const SizedBox(height: 32),
                                  _ProgressBar(
                                    label: l10n.spectralIntensity,
                                    value:
                                        '${state.spectralIntensity.toStringAsFixed(1)} W/m²',
                                    progress: (state.spectralIntensity / 1000.0)
                                        .clamp(0.0, 1.0),
                                  ),
                                  const SizedBox(height: 16),
                                  _ProgressBar(
                                    label: l10n.uvIndex,
                                    value:
                                        '${state.uvIndex.toStringAsFixed(1)}',
                                    progress: (state.uvIndex / 15.0).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.green,
                                        Colors.orange,
                                        Colors.red,
                                        Colors.purple,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox(height: 300),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  String _formatDMS(double lat, double lon) {
    String latDir = lat >= 0 ? "N" : "S";
    String lonDir = lon >= 0 ? "E" : "W";

    double absLat = lat.abs();
    int latDeg = absLat.floor();
    int latMin = ((absLat - latDeg) * 60).floor();
    int latSec = (((absLat - latDeg) * 60 - latMin) * 60).floor();

    double absLon = lon.abs();
    int lonDeg = absLon.floor();
    int lonMin = ((absLon - lonDeg) * 60).floor();
    int lonSec = (((absLon - lonDeg) * 60 - lonMin) * 60).floor();

    return '$latDeg° $latMin\' $latSec" $latDir, $lonDeg° $lonMin\' $lonSec" $lonDir';
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _HeaderButton({required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFFFDBA74)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CoordinateCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final IconData? trendIcon;
  final Color trendColor;

  const _CoordinateCard({
    required this.label,
    required this.value,
    required this.trend,
    this.trendIcon,
    this.trendColor = const Color(0xFFFDBA74),
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (trendIcon != null)
                Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 12,
                  color: trendColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _TelemetryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = Colors.white38,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Gradient? gradient;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.progress,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: gradient != null ? Colors.orange : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient:
                    gradient ??
                    LinearGradient(
                      colors: [
                        const Color(0xFFFDBA74),
                        const Color(0xFFFDBA74).withOpacity(0.5),
                      ],
                    ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingLocationMarker extends StatefulWidget {
  @override
  __PulsingLocationMarkerState createState() => __PulsingLocationMarkerState();
}

class __PulsingLocationMarkerState extends State<_PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
                  color: const Color(
                    0xFFFDBA74,
                  ).withOpacity(1.0 - _controller.value),
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
                color: const Color(0xFFFDBA74).withOpacity(0.2),
              ),
            ),
            // Solid center point
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDBA74),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFDBA74),
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
