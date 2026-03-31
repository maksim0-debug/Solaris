import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/stylish_location_card.dart';
import 'package:solaris/widgets/solar_map.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _updateControllers(double? lat, double? lon) {
    if (lat != null && _latController.text != lat.toString()) {
      _latController.text = lat.toStringAsFixed(4);
    }
    if (lon != null && _lonController.text != lon.toString()) {
      _lonController.text = lon.toStringAsFixed(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(effectiveLocationProvider);
    final settingsAsync = ref.watch(locationSettingsProvider);

    // Update controllers when manual location is first loaded or changed outside
    ref.listen(locationSettingsProvider, (prev, next) {
      next.whenData((settings) {
        if (settings.useManual) {
          _updateControllers(settings.manualLatitude, settings.manualLongitude);
        }
      });
    });

    // Populate controllers initially if settings are already loaded
    if (settingsAsync.hasValue && settingsAsync.value!.useManual) {
      final settings = settingsAsync.value!;
      if (_latController.text.isEmpty && settings.manualLatitude != null) {
        _latController.text = settings.manualLatitude!.toStringAsFixed(4);
      }
      if (_lonController.text.isEmpty && settings.manualLongitude != null) {
        _lonController.text = settings.manualLongitude!.toStringAsFixed(4);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.locationAutomation.toUpperCase(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              if (settingsAsync.value?.useManual == true)
                TextButton.icon(
                  onPressed: () => ref
                      .read(locationSettingsProvider.notifier)
                      .setAutoLocation(),
                  icon: const Icon(LucideIcons.refreshCcw, size: 16),
                  label: Text(l10n.reset),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFDBA74),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.locationSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Side
              Expanded(
                flex: 2,
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.celestialMap,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  l10n.celestialMapSubtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                            settingsAsync.maybeWhen(
                              data: (settings) => _AutoDetectToggle(
                                isActive: !settings.useManual,
                                onToggle: (val) {
                                  if (val) {
                                    ref
                                        .read(locationSettingsProvider.notifier)
                                        .setAutoLocation();
                                  } else {
                                    final pos = locationAsync.value;
                                    if (pos != null) {
                                      ref
                                          .read(
                                            locationSettingsProvider.notifier,
                                          )
                                          .setManualLocation(
                                            pos.latitude,
                                            pos.longitude,
                                          );
                                    }
                                  }
                                },
                              ),
                              orElse: () => const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          locationAsync.when(
                            data: (pos) => AspectRatio(
                              aspectRatio: 16 / 9,
                              child: SolarMap(
                                latitude: pos.latitude,
                                longitude: pos.longitude,
                                zoom:
                                    1.5, // Minimum zoom to avoid repetition and see enough area
                              ),
                            ),
                            loading: () => const AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, __) => AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Center(child: Text('Error: $e')),
                            ),
                          ),
                          // Overlay location info
                          Positioned(
                            bottom: 24,
                            left: 24,
                            child: locationAsync.maybeWhen(
                              data: (pos) => GlassCard(
                                blur: 10,
                                opacity: 0.1,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.currentAnchor,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFDBA74),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Global Coordinates", // Simplified for now as we don't have reverse geocoding here
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° W",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              orElse: () => const SizedBox(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Controls Side
              Expanded(
                child: Column(
                  children: [
                    const StylishLocationCard(),
                    const SizedBox(height: 24),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.manualCoordinateEntry,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _CoordinateInput(
                            label: l10n.latitude,
                            controller: _latController,
                            hint: "00.0000",
                          ),
                          const SizedBox(height: 16),
                          _CoordinateInput(
                            label: l10n.longitude,
                            controller: _lonController,
                            hint: "00.0000",
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                final lat = double.tryParse(
                                  _latController.text,
                                );
                                final lon = double.tryParse(
                                  _lonController.text,
                                );
                                if (lat != null && lon != null) {
                                  ref
                                      .read(locationSettingsProvider.notifier)
                                      .setManualLocation(lat, lon);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDBA74),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleType(12),
                                elevation: 8,
                                shadowColor: const Color(
                                  0xFFFDBA74,
                                ).withOpacity(0.5),
                              ),
                              child: Text(
                                l10n.updatePosition,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.satellite,
                              color: Color(0xFFFDBA74),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.precisionGps,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.gpsSubtitle,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      l10n.statusConnected,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.greenAccent,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoDetectToggle extends StatelessWidget {
  const _AutoDetectToggle({required this.isActive, required this.onToggle});
  final bool isActive;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => onToggle(!isActive),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFDBA74).withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: Text(
          l10n.autoDetect(isActive ? l10n.active.toUpperCase() : l10n.disabled.toUpperCase()),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFFFDBA74) : Colors.white38,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _CoordinateInput extends StatelessWidget {
  const _CoordinateInput({
    required this.label,
    required this.controller,
    required this.hint,
  });
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// Helper to create RoundedRectangleType for ElevatedButton (custom shape)
class RoundedRectangleType extends RoundedRectangleBorder {
  RoundedRectangleType(double radius)
    : super(borderRadius: BorderRadius.circular(radius));
}
