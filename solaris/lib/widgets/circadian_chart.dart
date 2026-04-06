import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/settings_state.dart';



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
    final solarAsync = ref.watch(
      solarStateStreamProvider,
    ); // Get solar data
    final weatherAsync = ref.watch(currentWeatherProvider);
    final circadianService = ref.read(circadianServiceProvider);

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

    // Calculate marker Y position
    double currentBrightnessY = points.first.y;
    if (currentElevation >= points.last.x) {
      currentBrightnessY = points.last.y;
    } else if (currentElevation > points.first.x) {
      for (int i = 0; i < points.length - 1; i++) {
        if (currentElevation >= points[i].x &&
            currentElevation <= points[i + 1].x) {
          final t =
              (currentElevation - points[i].x) /
              (points[i + 1].x - points[i].x);
          currentBrightnessY =
              points[i].y + (points[i + 1].y - points[i].y) * t;
          break;
        }
      }
    }

    double? adjustedBrightnessY;
    if (!isTemp &&
        currentSettings.isWeatherAdjustmentEnabled &&
        weatherAsync.value != null) {
      final baseFactor = circadianService.weatherAdjustmentService
          .calculateWeatherFactor(weatherAsync.value, currentElevation);

      if (baseFactor < 0.99) {
        final penalty = (1.0 - baseFactor) *
            currentSettings.activePreset.weatherSensitivity *
            currentSettings.weatherAdjustmentIntensity;
        final finalFactor = 1.0 - penalty;
        adjustedBrightnessY = (currentBrightnessY * finalFactor).clamp(
          points.first.y,
          isTemp ? 6500.0 : 100.0,
        );
      }
    }

    // Линии бара
    final List<LineChartBarData> lineBars = [
      LineChartBarData(
        spots: points,
        isCurved: true,
        curveSmoothness: 0.3,
        gradient: const LinearGradient(
          colors: [nightColor, twilightColor, dayColor],
          stops: [0.0, 0.2, 0.8],
        ),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isTouched = index == _touchedIndex;
            return FlDotCirclePainter(
              radius: isTouched ? 6 : 4,
              color: isTouched ? Colors.white : Colors.white70,
              strokeWidth: isTouched ? 3 : 1,
              strokeColor: isTouched ? dayColor : Colors.white24,
            );
          },
          checkToShowDot: (spot, barData) => true,
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              dayColor.withOpacity(0.2),
              twilightColor.withOpacity(0.1),
              nightColor.withOpacity(0.0),
            ],
            stops: const [0.1, 0.6, 1.0],
          ),
        ),
      ),
      // Animated halo around the marker
      LineChartBarData(
        spots: [
          FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY),
        ],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 10 + (_pulseAnimation.value * 8), // Пульсация от 10 до 18
            color: dayColor.withOpacity(0.15 * (1.0 - _pulseAnimation.value * 0.5)),
            strokeWidth: 0,
          ),
        ),
      ),
      LineChartBarData(
        spots: [
          FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY),
        ],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 7 + (_pulseAnimation.value * 4), // Пульсация от 7 до 11
            color: dayColor.withOpacity(0.35 * (1.0 - _pulseAnimation.value * 0.3)),
            strokeWidth: 0,
          ),
        ),
      ),
      // Main sun position marker (larger by 25%)
      LineChartBarData(
        spots: [
          FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY),
        ],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: adjustedBrightnessY != null 
                ? 3.75 // 3 * 1.25
                : 6.25, // 5 * 1.25
            color: adjustedBrightnessY != null ? Colors.white54 : Colors.white,
            strokeWidth: 2,
            strokeColor: adjustedBrightnessY != null
                ? dayColor.withOpacity(0.5)
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
            FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY),
            FlSpot(currentElevation.clamp(-20.0, 90.0), adjustedBrightnessY),
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
          spots: [
            FlSpot(currentElevation.clamp(-20.0, 90.0), adjustedBrightnessY),
          ],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 8 + (_pulseAnimation.value * 4),
                  color: Colors.lightBlueAccent.withOpacity(0.2 * (1.0 - _pulseAnimation.value * 0.4)),
                  strokeWidth: 0,
                ),
          ),
        ),
      );
      // Actual marker with weather (larger by 25%)
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(currentElevation.clamp(-20.0, 90.0), adjustedBrightnessY),
          ],
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
                  verticalInterval: 10,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                  getDrawingVerticalLine: (value) {
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
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    // Show degrees (-20°, 0°, 20°, 40°...)
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        l10n.chartDegreesFormat(value.toInt()),
                        style: TextStyle(
                          color: value == 0
                              ? const Color(0xFFFDBA74)
                              : Colors.white30,
                          fontWeight: value == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: isTemp ? 500 : 25,
                  reservedSize: _leftTitleWidth + (isTemp ? 20 : 0),
                  getTitlesWidget: (value, meta) {
                    if (!isTemp && value > 100) return const SizedBox();
                    if (isTemp && value > 7000) return const SizedBox();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        isTemp ? l10n.chartTemperatureFormat(value.toInt()) : l10n.chartPercentFormat(value.toInt()),
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
            minX: -20, // От -20 градусов (ночь)
            maxX: 90, // До +90 градусов (зенит)
            minY: isTemp
                ? 3000
                : 0, // From 3000K for temp (padding for 3300K floor)
            maxY: isTemp ? 7000 : 105, // Up to 7000K or 105%
            lineBarsData: lineBars,
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback:
                  (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (event is FlPanStartEvent || event is FlTapDownEvent) {
                      if (touchResponse?.lineBarSpots != null &&
                          touchResponse!.lineBarSpots!.isNotEmpty) {
                        // Do not allow grabbing the current time marker (index 1)
                        if (touchResponse.lineBarSpots!.first.barIndex == 0) {
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
                        if (touchResponse.lineBarSpots!.first.barIndex == 0) {
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

  Offset _pixelToChart(Offset localPosition, Size widgetSize) {
    final gridWidth = widgetSize.width - _leftTitleWidth - _containerRight;
    final gridHeight =
        widgetSize.height -
        _bottomTitleHeight -
        _containerTop -
        _containerBottom;

    if (gridWidth <= 0 || gridHeight <= 0) return const Offset(0, 0);

    final isTemp = ref.read(editingTemperatureProvider);
    final maxY = isTemp ? 7000.0 : 105.0;
    final minY = isTemp ? 3000.0 : 0.0;
    final rangeY = maxY - minY;

    double x =
        -20.0 + ((localPosition.dx - _leftTitleWidth) / gridWidth) * 110.0;
    double y =
        maxY - (((localPosition.dy - _containerTop) / gridHeight) * rangeY);

    return Offset(x, y);
  }

  void _updatePoint(int index, Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final chartCoords = _pixelToChart(localPosition, renderBox.size);

    final isTemp = ref.read(editingTemperatureProvider);

    double x = chartCoords.dx;
    double y = chartCoords.dy.clamp(
      isTemp ? 3300.0 : 0.0,
      isTemp ? 6500.0 : 100.0,
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
      final double minX = newPoints[index - 1].x + 1.0; // Зазор в 1 градус
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

    double x = chartCoords.dx.clamp(-20.0, 90.0);
    double y = chartCoords.dy.clamp(
      isTemp ? 1000.0 : 0.0,
      isTemp ? 7000.0 : 100.0,
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
