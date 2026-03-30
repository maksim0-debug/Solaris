import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/settings_state.dart';

class CircadianChartWidget extends ConsumerStatefulWidget {
  const CircadianChartWidget({super.key});

  @override
  ConsumerState<CircadianChartWidget> createState() =>
      _CircadianChartWidgetState();
}

class _CircadianChartWidgetState extends ConsumerState<CircadianChartWidget> {
  int? _touchedIndex;

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
          final tempState = tempMap[selectedIds.firstOrNull ?? 'all'] ?? tempMap['all']!;
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
              settingsMap[selectedIds.firstOrNull ?? 'all'] ?? settingsMap['all']!;
          final points = selectedSettings.curvePoints;
          return _buildChart(context, points, isTemp);
        },
        orElse: () => const Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _buildChart(BuildContext context, List<FlSpot> points, bool isTemp) {
    final solarAsync = ref.watch(
      solarStateStreamProvider,
    ); // Получаем данные о солнце
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

    // Текущая высота солнца из провайдера (если данные еще грузятся, берем 0)
    final currentElevation = solarAsync.maybeWhen(
      data: (state) => state.sunElevation,
      orElse: () => 0.0,
    );

    // Рассчитываем позицию маркера по Y
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
        final penalty =
            (1.0 - baseFactor) *
            currentSettings.activePreset.weatherSensitivity;
        final finalFactor = 1.0 - penalty;
        adjustedBrightnessY = (currentBrightnessY * finalFactor).clamp(
          points.first.y,
          isTemp ? 7000.0 : 100.0,
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
      // Пульсирующий маркер текущего положения солнца
      LineChartBarData(
        spots: [
          FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY),
        ],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: adjustedBrightnessY != null ? 3 : 5,
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
      // Добавляем соединительную пунктирную линию
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
      // Добавляем актуальный маркер с учетом погоды
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(currentElevation.clamp(-20.0, 90.0), adjustedBrightnessY),
          ],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 5,
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
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: isTemp ? 1000 : 25,
              verticalInterval: 10,
              getDrawingHorizontalLine: (value) =>
                  const FlLine(color: Colors.white10, strokeWidth: 1),
              getDrawingVerticalLine: (value) {
                // Выделяем линию горизонта (0 градусов)
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
                    // Показывать градусы (-20°, 0°, 20°, 40°...)
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        '${value.toInt()}°',
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
                  interval: isTemp ? 1000 : 25,
                  reservedSize: _leftTitleWidth + (isTemp ? 20 : 0),
                  getTitlesWidget: (value, meta) {
                    if (!isTemp && value > 100) return const SizedBox();
                    if (isTemp && value > 7000) return const SizedBox();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        isTemp ? '${value.toInt()}K' : '${value.toInt()}%',
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
                ? 1000
                : 0, // От 1000K для температуры или 0% для яркости
            maxY: isTemp ? 7000 : 105, // До 7000K или 105%
            lineBarsData: lineBars,
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback:
                  (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (event is FlPanStartEvent || event is FlTapDownEvent) {
                      if (touchResponse?.lineBarSpots != null &&
                          touchResponse!.lineBarSpots!.isNotEmpty) {
                        // Не позволяем хватать маркер текущего времени (это второй график, index 1)
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
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Colors.transparent,
                getTooltipItems: (touchedSpots) => [],
              ),
            ),
          ),
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
    final minY = isTemp ? 1000.0 : 0.0;
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
        : (ref.read(settingsProvider).value?[selectedIds.firstOrNull ?? 'all']?.curvePoints ??
              ref.read(settingsProvider).value?['all']?.curvePoints ??
              []);

    if (currentPoints.isEmpty) return;

    final newPoints = List<FlSpot>.from(currentPoints);

    if (index == 0 || index == newPoints.length - 1) {
      x = index == 0 ? -20.0 : 90.0;
      newPoints[index] = FlSpot(
        x,
        y,
      ); // Мы больше не синхронизируем концы, так как это не цикл времени
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
        : (ref.read(settingsProvider).value?[selectedIds.firstOrNull ?? 'all']?.curvePoints ??
              ref.read(settingsProvider).value?['all']?.curvePoints ??
              []);

    if (currentPoints.isEmpty) return;

    bool tooClose = currentPoints.any(
      (p) => (p.x - x).abs() < 2.0,
    ); // Защита от спама точками

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
        : (ref.read(settingsProvider).value?[selectedIds.firstOrNull ?? 'all']?.curvePoints ??
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
