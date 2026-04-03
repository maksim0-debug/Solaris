import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solaris/env/env.dart';
import 'package:solaris/services/terminator_service.dart';
import 'package:solaris/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/widgets/map_health_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/models/map_health_report.dart';

class SolarMap extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;
  final void Function(LatLng latLng)? onLongPress;

  const SolarMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 1.0,
    this.onLongPress,
  });

  @override
  ConsumerState<SolarMap> createState() => _SolarMapState();
}

class _SolarMapState extends ConsumerState<SolarMap> {
  final TerminatorService _terminatorService = TerminatorService();
  final MapController _mapController = MapController();
  List<LatLng> _terminatorPoints = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTerminator();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTerminator();
    });
  }

  @override
  void didUpdateWidget(SolarMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _mapController.move(
        LatLng(widget.latitude, widget.longitude),
        widget.zoom,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _updateTerminator() {
    if (!mounted) return;
    setState(() {
      _terminatorPoints = _terminatorService.getTerminatorPoints(
        DateTime.now().toUtc(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = Env.mapboxToken;
    final healthAsync = ref.watch(mapHealthProvider);
    
    // Using the same style as in LocationScreen for consistency
    const style = kMapboxLargeMapStyle;
    final urlTemplate =
        'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}@2x?access_token=$token';

    final mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.latitude, widget.longitude),
        initialZoom: widget.zoom,
        minZoom: 1.5,
        maxZoom: 18.0,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onLongPress: (tapPosition, latLng) {
          widget.onLongPress?.call(latLng);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: urlTemplate,
          userAgentPackageName: 'com.example.solaris',
        ),
        if (_terminatorPoints.isNotEmpty)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _terminatorPoints,
                color: Colors.black.withOpacity(0.5),
                isFilled: true,
                borderColor: Colors.transparent,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(widget.latitude, widget.longitude),
              width: 80,
              height: 80,
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFFDBA74),
                size: 30,
              ),
            ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        mapWidget,
        Positioned(
          top: 12,
          right: 12,
          child: healthAsync.maybeWhen(
            data: (MapHealthReport report) => report.hasIssues
                ? GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => MapHealthDialog(report: report),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDBA74).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.alertTriangle,
                              color: Color(0xFFFDBA74), size: 16),
                          SizedBox(width: 8),
                          Text(
                            "MAP ISSUES",
                            style: TextStyle(
                              color: Color(0xFFFDBA74),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
        ),
      ],
    );
  }
}
