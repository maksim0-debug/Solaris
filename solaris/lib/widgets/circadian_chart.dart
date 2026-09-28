import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:timezone/timezone.dart' as tz;

class CircadianChartWidget extends ConsumerStatefulWidget {
  const CircadianChartWidget({super.key});

  @override
  ConsumerState<CircadianChartWidget> createState() =>
      _CircadianChartWidgetState();
}

class _CircadianChartWidgetState extends ConsumerState<CircadianChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int? _touchedIndex;

  List<FlSpot>? _cachedPhaseSpots;
  int? _lastPhaseSpotsDay;
  SolarPhasesConfig? _lastPhasesConfig;
  bool? _lastIsTemp;
  double? _lastLat;
  double? _lastLon;
  double? _lastMaxElev;
  double? _lastMinElev;
  tz.Location? _lastTimezone;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static const double _leftTitleWidth = 32.0;
  static const double _bottomTitleHeight = 22.0;
  static const double _containerTop = 20.0;
  static const double _containerRight = 24.0;
  static const double _containerBottom = 6.0;

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedMonitorsProvider);
    final isTemp = ref.watch(editingTemperatureProvider);

    if (isTemp) {
      final tempAsync = ref.watch(temperatureSettingsProvider);
      return tempAsync.maybeWhen(
        data: (tempMap) {
          final tempState =
              tempMap[selectedIds.firstOrNull ?? 'all'] ?? tempMap['all']!;
          final points = tempState.curvePoints;
          return _buildChart(context, points, isTemp);
        },
        orElse: () => const Center(child: CircularProgressIndicator()),
      );
    } else {
      final settingsAsync = ref.watch(settingsProvider);
      return settingsAsync.maybeWhen(
        data: (settingsMap) {
          final selectedSettings =
              settingsMap[selectedIds.firstOrNull ?? 'all'] ??
              settingsMap['all']!;
          final points = selectedSettings.curvePoints;
          return _buildChart(context, points, isTemp);
        },
        orElse: () => const Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _buildChart(BuildContext context, List<FlSpot> points, bool isTemp) {
    final l10n = AppLocalizations.of(context)!;
    final solarAsync = ref.watch(solarStateStreamProvider); // Get solar data
    final weatherAsync = ref.watch(currentWeatherProvider);
    final circadianService = ref.read(circadianServiceProvider);
    final currentTimeAsync = ref.watch(currentTimeProvider);
    final timezoneVal = ref.watch(effectiveTimezoneProvider);
    final now = currentTimeAsync.value ?? tz.TZDateTime.now(timezoneVal);

    final selectedIds = ref.watch(selectedMonitorsProvider);
    final settingsMap = ref.watch(settingsProvider).value;
    final currentSettings =
        settingsMap?[selectedIds.firstOrNull ?? 'all'] ??
        settingsMap?['all'] ??
        SettingsState();

    const dayColor = Color(0xFFFDBA74);
    const nightColor = Colors.indigoAccent;
    const twilightColor = Colors.purpleAccent;

    // Current sun elevation from provider (if data still loading, take 0)
    final currentElevation = solarAsync.maybeWhen(
      data: (state) => state.sunElevation,
      orElse: () => 0.0,
    );

    final mode = currentSettings.circadianMode;
    final isPhasesMode = mode == CircadianMode.solarPhases;
    final sunService = ref.read(sunCalculatorServiceProvider);
    final locationAsync = ref.watch(effectiveLocationProvider);
    final lat = locationAsync.value?.latitude ?? 50.45;
    final lon = locationAsync.value?.longitude ?? 30.52;
    final phases = solarAsync.value?.phases;
    final maxElev =
        solarAsync.value?.maxElevation ??
        (phases != null
            ? sunService.getSunElevation(lat, lon, phases.solarNoon)
            : 60.0);
    final minElev =
        solarAsync.value?.minElevation ??
        (phases != null
            ? sunService.getSunElevation(
                lat,
                lon,
                phases.solarNoon.add(const Duration(hours: 12)),
              )
            : -60.0);

    List<FlSpot> displaySpots = points;
    double markerX = 0.0;
    double currentBrightnessY = points.first.y;

    if (mode == CircadianMode.solarPhases) {
      displaySpots = _getPhaseSpots(
        now: now,
        timezoneVal: timezoneVal,
        phases: phases,
        sunService: sunService,
        circadianService: circadianService,
        config: currentSettings.phasesConfig,
        isTemp: isTemp,
        lat: lat,
        lon: lon,
        maxElev: maxElev,
        minElev: minElev,
        fallbackPoints: points,
      );
      markerX = (now.hour + now.minute / 60.0 + now.second / 3600.0).clamp(
        0.0,
        24.0,
      );
      currentBrightnessY = isTemp
          ? (phases != null
                ? circadianService
                      .calculateTemperatureFromPhases(
                        config: currentSettings.phasesConfig,
                        phases: phases,
                        elevation: currentElevation,
                        maxElevation: maxElev,
                        minElevation: minElev,
                        now: now,
                      )
                      .toDouble()
                : TemperatureConstants.maxDouble)
          : (phases != null
                ? circadianService.calculateBrightnessFromPhases(
                    config: currentSettings.phasesConfig,
                    phases: phases,
                    elevation: currentElevation,
                    maxElevation: maxElev,
                    minElevation: minElev,
                    now: now,
                  )
                : 100.0);
    } else {
      displaySpots = points;
      markerX = circadianService
          .normalizeElevationToStandardRange(
            elevation: currentElevation,
            minElevation: minElev,
            maxElevation: maxElev,
          )
          .clamp(-20.0, 90.0);

      if (markerX >= points.last.x) {
        currentBrightnessY = points.last.y;
      } else if (markerX > points.first.x) {
        for (int i = 0; i < points.length - 1; i++) {
          if (markerX >= points[i].x && markerX <= points[i + 1].x) {
            final t = (markerX - points[i].x) / (points[i + 1].x - points[i].x);
            currentBrightnessY =
                points[i].y + (points[i + 1].y - points[i].y) * t;
            break;
          }
        }
      }
    }

    double? adjustedBrightnessY;
    if (isTemp) {
      if (currentSettings.isWeatherTemperatureAdjustmentEnabled &&
          weatherAsync.value != null &&
          solarAsync.value != null) {
        final drop = circadianService.weatherAdjustmentService
            .calculateWeatherTemperatureDrop(
              weather: weatherAsync.value!,
              now: now,
              phases: solarAsync.value!.phases,
              intensity: currentSettings.weatherAdjustmentIntensity,
            );
        if (drop > 0) {
          adjustedBrightnessY = (currentBrightnessY - drop).clamp(
            displaySpots.first.y,
            6500.0,
          );
        }
      }
    } else {
      if (currentSettings.isWeatherAdjustmentEnabled &&
          weatherAsync.value != null) {
        final baseFactor = circadianService.weatherAdjustmentService
            .calculateWeatherFactor(weatherAsync.value, currentElevation);

        if (baseFactor < 0.99) {
          final penalty =
              (1.0 - baseFactor) *
              currentSettings.activePreset.weatherSensitivity *
              currentSettings.weatherAdjustmentIntensity;
          final finalFactor = 1.0 - penalty;
          adjustedBrightnessY = (currentBrightnessY * finalFactor).clamp(
            displaySpots.first.y,
            100.0,
          );
        }
      }
    }

    // Chart bar data
    final List<LineChartBarData> lineBars = [
      LineChartBarData(
        spots: displaySpots,
        isCurved: !isPhasesMode,
        curveSmoothness: 0.3,
        preventCurveOverShooting: true,
        gradient: isPhasesMode
            ? const LinearGradient(
                colors: [
                  nightColor,
                  twilightColor,
                  dayColor,
                  twilightColor,
                  nightColor,
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              )
            : const LinearGradient(
                colors: [nightColor, twilightColor, dayColor],
                stops: [0.0, 0.2, 0.8],
              ),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: !isPhasesMode,
          getDotPainter: (spot, percent, barData, index) {
            final isTouched = index == _touchedIndex;
            return FlDotCirclePainter(
              radius: isTouched ? 6 : 4,
              color: isTouched ? Colors.white : Colors.white70,
              strokeWidth: isTouched ? 3 : 1,
              strokeColor: isTouched ? dayColor : Colors.white24,
            );
          },
          checkToShowDot: (spot, barData) => !isPhasesMode,
        ),
        belowBarData: BarAreaData(
          show: true,
          cutOffY: isTemp ? TemperatureConstants.minDouble : 0.0,
          applyCutOffY: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              dayColor.withValues(alpha: 0.2),
              twilightColor.withValues(alpha: 0.1),
              nightColor.withValues(alpha: 0.0),
            ],
            stops: const [0.1, 0.6, 1.0],
          ),
        ),
      ),
      // Animated halo around the marker
      LineChartBarData(
        spots: [FlSpot(markerX, currentBrightnessY)],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius:
                10 +
                (_pulseAnimation.value * 8), // Pulsing radius from 10 to 18
            color: dayColor.withValues(
              alpha: 0.15 * (1.0 - _pulseAnimation.value * 0.5),
            ),
            strokeWidth: 0,
          ),
        ),
      ),
      LineChartBarData(
        spots: [FlSpot(markerX, currentBrightnessY)],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius:
                7 + (_pulseAnimation.value * 4), // Pulsing radius from 7 to 11
            color: dayColor.withValues(
              alpha: 0.35 * (1.0 - _pulseAnimation.value * 0.3),
            ),
            strokeWidth: 0,
          ),
        ),
      ),
      // Main sun position marker (larger by 25%)
      LineChartBarData(
        spots: [FlSpot(markerX, currentBrightnessY)],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: adjustedBrightnessY != null
                ? 3.75 // 3 * 1.25
                : 6.25, // 5 * 1.25
            color: adjustedBrightnessY != null ? Colors.white54 : Colors.white,
            strokeWidth: 2,
            strokeColor: adjustedBrightnessY != null
                ? dayColor.withValues(alpha: 0.5)
                : dayColor,
          ),
        ),
      ),
    ];

    if (adjustedBrightnessY != null) {
      // connecting line (only if weather correction exists)
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(markerX, currentBrightnessY),
            FlSpot(markerX, adjustedBrightnessY),
          ],
          isCurved: false,
          color: Colors.white24,
          barWidth: 1,
          dashArray: [4, 4],
          dotData: FlDotData(show: false),
        ),
      );
      // Weather marker halo (animated)
      lineBars.add(
        LineChartBarData(
          spots: [FlSpot(markerX, adjustedBrightnessY)],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 8 + (_pulseAnimation.value * 4),
                  color: Colors.lightBlueAccent.withValues(
                    alpha: 0.2 * (1.0 - _pulseAnimation.value * 0.4),
                  ),
                  strokeWidth: 0,
                ),
          ),
        ),
      );
      // Actual marker with weather (larger by 25%)
      lineBars.add(
        LineChartBarData(
          spots: [FlSpot(markerX, adjustedBrightnessY)],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 6.25, // 5 * 1.25
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.lightBlueAccent,
                ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 2.2,
      child: Container(
        padding: const EdgeInsets.only(
          top: _containerTop,
          right: _containerRight,
          bottom: _containerBottom,
        ),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: isTemp ? 500 : 25,
                  verticalInterval: mode == CircadianMode.solarPhases ? 4 : 10,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                  getDrawingVerticalLine: (value) {
                    if (mode == CircadianMode.solarPhases) {
                      if (value == 12) {
                        return const FlLine(
                          color: Color(0xFFFDBA74),
                          strokeWidth: 1.5,
                          dashArray: [5, 5],
                        );
                      }
                      return const FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      );
                    }
                    // Highlight the horizon line (0 degrees)
                    if (value == 0) {
                      return const FlLine(
                        color: Color(0xFFFDBA74),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      );
                    }
                    return const FlLine(color: Colors.white10, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: _bottomTitleHeight,
                      interval: mode == CircadianMode.solarPhases ? 4 : 10,
                      getTitlesWidget: (value, meta) {
                        if (mode == CircadianMode.solarPhases) {
                          final rounded = value.round();
                          if ((value - rounded).abs() > 0.05 ||
                              rounded % 4 != 0) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              '${rounded.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                color: rounded == 12
                                    ? const Color(0xFFFDBA74)
                                    : Colors.white30,
                                fontWeight: rounded == 12
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 10,
                              ),
                            ),
                          );
                        } else {
                          final rounded = value.round();
                          if ((value - rounded).abs() > 0.05) {
                            return const SizedBox();
                          }
                          final text = switch (rounded) {
                            -20 => l10n.normalizedNadir,
                            0 => l10n.normalizedHorizon,
                            90 => l10n.normalizedNoon,
                            _ => null,
                          };
                          if (text == null) return const SizedBox();
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              text,
                              style: TextStyle(
                                color: rounded == 0
                                    ? const Color(0xFFFDBA74)
                                    : Colors.white60,
                                fontWeight: rounded == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: isTemp ? 500 : 25,
                      reservedSize: _leftTitleWidth + (isTemp ? 20 : 0),
                      getTitlesWidget: (value, meta) {
                        if (!isTemp && (value > 100 || value < 0)) {
                          return const SizedBox();
                        }
                        if (isTemp &&
                            (value > TemperatureConstants.max ||
                                value < TemperatureConstants.min)) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            isTemp
                                ? l10n.chartTemperatureFormat(value.toInt())
                                : l10n.chartPercentFormat(value.toInt()),
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: mode == CircadianMode.solarPhases ? 0 : -20,
                maxX: mode == CircadianMode.solarPhases ? 24 : 90,
                minY: isTemp ? TemperatureConstants.minDouble : 0,
                maxY: isTemp ? TemperatureConstants.maxDouble : 100,
                lineBarsData: lineBars,
                lineTouchData: LineTouchData(
                  enabled: mode != CircadianMode.solarPhases,
                  handleBuiltInTouches: false,
                  touchCallback:
                      (FlTouchEvent event, LineTouchResponse? touchResponse) {
                        if (event is FlPanStartEvent ||
                            event is FlTapDownEvent) {
                          if (touchResponse?.lineBarSpots != null &&
                              touchResponse!.lineBarSpots!.isNotEmpty) {
                            // Do not allow grabbing the current time marker (index 1)
                            if (touchResponse.lineBarSpots!.first.barIndex ==
                                0) {
                              setState(() {
                                _touchedIndex =
                                    touchResponse.lineBarSpots!.first.spotIndex;
                              });
                            }
                          }
                        } else if (event is FlPanUpdateEvent) {
                          if (_touchedIndex != null) {
                            _updatePoint(
                              _touchedIndex!,
                              event.localPosition,
                              context,
                            );
                          }
                        } else if (event is FlPanEndEvent ||
                            event is FlPanCancelEvent ||
                            event is FlTapUpEvent) {
                          if (_touchedIndex != null) {
                            setState(() {
                              _touchedIndex = null;
                            });
                          } else if (event is FlTapUpEvent) {
                            if (touchResponse == null ||
                                touchResponse.lineBarSpots == null ||
                                touchResponse.lineBarSpots!.isEmpty) {
                              _addPointAt(event.localPosition, context);
                            }
                          }
                        } else if (event is FlLongPressStart) {
                          if (touchResponse?.lineBarSpots != null &&
                              touchResponse!.lineBarSpots!.isNotEmpty) {
                            if (touchResponse.lineBarSpots!.first.barIndex ==
                                0) {
                              final indexToRemove =
                                  touchResponse.lineBarSpots!.first.spotIndex;
                              _removePoint(indexToRemove);
                              setState(() {
                                _touchedIndex = null;
                              });
                            }
                          }
                        }
                      },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<FlSpot> _getPhaseSpots({
    required DateTime now,
    required tz.Location timezoneVal,
    required SolarPhaseModel? phases,
    required SunCalculatorService sunService,
    required CircadianService circadianService,
    required SolarPhasesConfig config,
    required bool isTemp,
    required double lat,
    required double lon,
    required double maxElev,
    required double minElev,
    required List<FlSpot> fallbackPoints,
  }) {
    if (phases == null) return fallbackPoints;

    final isCacheValid =
        _cachedPhaseSpots != null &&
        _lastPhaseSpotsDay == now.day &&
        _lastPhasesConfig == config &&
        _lastIsTemp == isTemp &&
        _lastLat == lat &&
        _lastLon == lon &&
        _lastMaxElev == maxElev &&
        _lastMinElev == minElev &&
        _lastTimezone == timezoneVal;

    if (isCacheValid) {
      return _cachedPhaseSpots!;
    }

    final List<FlSpot> spots = [];
    const stepHours = 5.0 / 60.0; // 5-minute sampling interval
    for (double h = 0.0; h <= 24.0001; h += stepHours) {
      final sampleMinutes = (h * 60).round();
      final sampleTime = tz.TZDateTime(
        timezoneVal,
        now.year,
        now.month,
        now.day,
        0,
      ).add(Duration(minutes: sampleMinutes));
      final elev = sunService.getSunElevation(lat, lon, sampleTime);
      final rawY = isTemp
          ? circadianService
                .calculateTemperatureFromPhases(
                  config: config,
                  phases: phases,
                  elevation: elev,
                  maxElevation: maxElev,
                  minElevation: minElev,
                  now: sampleTime,
                )
                .toDouble()
          : circadianService.calculateBrightnessFromPhases(
              config: config,
              phases: phases,
              elevation: elev,
              maxElevation: maxElev,
              minElevation: minElev,
              now: sampleTime,
            );
      final clampedY = isTemp
          ? rawY.clamp(
              TemperatureConstants.minDouble,
              TemperatureConstants.maxDouble,
            )
          : rawY.clamp(0.0, 100.0);
      spots.add(FlSpot(h.clamp(0.0, 24.0), clampedY));
    }

    _cachedPhaseSpots = spots;
    _lastPhaseSpotsDay = now.day;
    _lastPhasesConfig = config;
    _lastIsTemp = isTemp;
    _lastLat = lat;
    _lastLon = lon;
    _lastMaxElev = maxElev;
    _lastMinElev = minElev;
    _lastTimezone = timezoneVal;

    return spots;
  }

  Offset _pixelToChart(Offset localPosition, Size widgetSize) {
    final isTemp = ref.read(editingTemperatureProvider);
    final effectiveLeftWidth = _leftTitleWidth + (isTemp ? 20.0 : 0.0);
    final gridWidth = widgetSize.width - effectiveLeftWidth - _containerRight;
    final gridHeight =
        widgetSize.height -
        _bottomTitleHeight -
        _containerTop -
        _containerBottom;

    if (gridWidth <= 0 || gridHeight <= 0) return const Offset(0, 0);

    final maxY = isTemp ? TemperatureConstants.maxDouble : 100.0;
    final minY = isTemp ? TemperatureConstants.minDouble : 0.0;
    final rangeY = maxY - minY;

    double x =
        -20.0 + ((localPosition.dx - effectiveLeftWidth) / gridWidth) * 110.0;
    double y =
        maxY - (((localPosition.dy - _containerTop) / gridHeight) * rangeY);

    return Offset(x, y);
  }

  void _updatePoint(int index, Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final chartCoords = _pixelToChart(localPosition, renderBox.size);

    final isTemp = ref.read(editingTemperatureProvider);
    const minTemp = TemperatureConstants.minDouble;

    double x = chartCoords.dx;
    double y = chartCoords.dy.clamp(
      isTemp ? minTemp : 0.0,
      isTemp ? TemperatureConstants.max.toDouble() : 100.0,
    );

    final selectedIds = ref.read(selectedMonitorsProvider);

    final currentPoints = isTemp
        ? (ref
                  .read(temperatureSettingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref
                  .read(temperatureSettingsProvider)
                  .value?['all']
                  ?.curvePoints ??
              [])
        : (ref
                  .read(settingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref.read(settingsProvider).value?['all']?.curvePoints ??
              []);

    if (currentPoints.isEmpty) return;

    final newPoints = List<FlSpot>.from(currentPoints);

    if (index == 0 || index == newPoints.length - 1) {
      x = index == 0 ? -20.0 : 90.0;
      newPoints[index] = FlSpot(
        x,
        y,
      ); // Not syncing ends as it's not a time cycle
    } else {
      final double minX = newPoints[index - 1].x + 1.0; // 1-degree minimum gap
      final double maxX = newPoints[index + 1].x - 1.0;
      x = x.clamp(minX, maxX);

      newPoints[index] = FlSpot(x, y);
    }

    if (isTemp) {
      ref
          .read(temperatureSettingsProvider.notifier)
          .updateCurvePoints(newPoints);
    } else {
      ref.read(settingsProvider.notifier).updateCurvePoints(newPoints);
    }
  }

  void _addPointAt(Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final chartCoords = _pixelToChart(localPosition, renderBox.size);

    final isTemp = ref.read(editingTemperatureProvider);
    const minTemp = TemperatureConstants.minDouble;

    double x = chartCoords.dx.clamp(-20.0, 90.0);
    double y = chartCoords.dy.clamp(
      isTemp ? minTemp : 0.0,
      isTemp ? TemperatureConstants.max.toDouble() : 100.0,
    );

    final selectedIds = ref.read(selectedMonitorsProvider);

    final currentPoints = isTemp
        ? (ref
                  .read(temperatureSettingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref
                  .read(temperatureSettingsProvider)
                  .value?['all']
                  ?.curvePoints ??
              [])
        : (ref
                  .read(settingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref.read(settingsProvider).value?['all']?.curvePoints ??
              []);

    if (currentPoints.isEmpty) return;

    bool tooClose = currentPoints.any(
      (p) => (p.x - x).abs() < 2.0,
    ); // Protect against spamming points

    if (!tooClose) {
      if (isTemp) {
        ref
            .read(temperatureSettingsProvider.notifier)
            .addCurvePoint(FlSpot(x, y));
      } else {
        ref.read(settingsProvider.notifier).addCurvePoint(FlSpot(x, y));
      }
    }
  }

  void _removePoint(int index) {
    final isTemp = ref.read(editingTemperatureProvider);
    final selectedIds = ref.read(selectedMonitorsProvider);

    final currentPoints = isTemp
        ? (ref
                  .read(temperatureSettingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref
                  .read(temperatureSettingsProvider)
                  .value?['all']
                  ?.curvePoints ??
              [])
        : (ref
                  .read(settingsProvider)
                  .value?[selectedIds.firstOrNull ?? 'all']
                  ?.curvePoints ??
              ref.read(settingsProvider).value?['all']?.curvePoints ??
              []);

    if (currentPoints.isEmpty) return;
    if (index == 0 || index == currentPoints.length - 1) return;

    if (isTemp) {
      ref.read(temperatureSettingsProvider.notifier).removeCurvePoint(index);
    } else {
      ref.read(settingsProvider.notifier).removeCurvePoint(index);
    }
  }
}
