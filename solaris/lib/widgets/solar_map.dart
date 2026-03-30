import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solaris/services/terminator_service.dart';
import 'package:solaris/providers.dart';

class SolarMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;

  const SolarMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 1.0,
  });

  @override
  State<SolarMap> createState() => _SolarMapState();
}

class _SolarMapState extends State<SolarMap> {
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
    const token = String.fromEnvironment('MAPBOX_TOKEN');
    // Using the same style as in LocationScreen for consistency
    const style = kMapboxLargeMapStyle;
    final urlTemplate =
        'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}@2x?access_token=$token';

    return FlutterMap(
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
  }
}
