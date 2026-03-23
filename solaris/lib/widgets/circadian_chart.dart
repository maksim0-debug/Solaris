import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';

class CircadianChartWidget extends ConsumerStatefulWidget {
  const CircadianChartWidget({super.key});

  @override
  ConsumerState<CircadianChartWidget> createState() => _CircadianChartWidgetState();
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
    final settingsAsync = ref.watch(settingsProvider);
    final selectedIds = ref.watch(selectedMonitorsProvider);
    
    return settingsAsync.maybeWhen(
      data: (settingsMap) {
        final selectedSettings =
            settingsMap[selectedIds.first] ?? settingsMap['all']!;
        final points = selectedSettings.curvePoints;
        return _buildChart(context, points);
      },
      orElse: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> points) {
    final solarAsync = ref.watch(solarStateStreamProvider); // Получаем данные о солнце

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
        if (currentElevation >= points[i].x && currentElevation <= points[i + 1].x) {
          final t = (currentElevation - points[i].x) / (points[i + 1].x - points[i].x);
          currentBrightnessY = points[i].y + (points[i + 1].y - points[i].y) * t;
          break;
        }
      }
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
              horizontalInterval: 25,
              verticalInterval: 10,
              getDrawingHorizontalLine: (value) => const FlLine(
                color: Colors.white10,
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) {
                // Выделяем линию горизонта (0 градусов)
                if (value == 0) {
                  return const FlLine(color: Color(0xFFFDBA74), strokeWidth: 1.5, dashArray: [5, 5]);
                }
                return const FlLine(color: Colors.white10, strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                          color: value == 0 ? const Color(0xFFFDBA74) : Colors.white30, 
                          fontWeight: value == 0 ? FontWeight.bold : FontWeight.normal,
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
                  interval: 25,
                  reservedSize: _leftTitleWidth,
                  getTitlesWidget: (value, meta) {
                    if (value > 100) return const SizedBox();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '${value.toInt()}%',
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: -20, // От -20 градусов (ночь)
            maxX: 90,  // До +90 градусов (зенит)
            minY: 0,
            maxY: 105,
            lineBarsData: [
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
                spots: [FlSpot(currentElevation.clamp(-20.0, 90.0), currentBrightnessY)],
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 5,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: dayColor,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                if (event is FlPanStartEvent || event is FlTapDownEvent) {
                  if (touchResponse?.lineBarSpots != null && touchResponse!.lineBarSpots!.isNotEmpty) {
                    // Не позволяем хватать маркер текущего времени (это второй график, index 1)
                    if (touchResponse.lineBarSpots!.first.barIndex == 0) {
                      setState(() {
                        _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
                      });
                    }
                  }
                } 
                else if (event is FlPanUpdateEvent) {
                  if (_touchedIndex != null) {
                    _updatePoint(_touchedIndex!, event.localPosition, context);
                  }
                } 
                else if (event is FlPanEndEvent || event is FlPanCancelEvent || event is FlTapUpEvent) {
                  if (_touchedIndex != null) {
                    setState(() { _touchedIndex = null; });
                  } else if (event is FlTapUpEvent) {
                    if (touchResponse == null || touchResponse.lineBarSpots == null || touchResponse.lineBarSpots!.isEmpty) {
                      _addPointAt(event.localPosition, context);
                    }
                  }
                }
                else if (event is FlLongPressStart) {
                  if (touchResponse?.lineBarSpots != null && touchResponse!.lineBarSpots!.isNotEmpty) {
                    if (touchResponse.lineBarSpots!.first.barIndex == 0) {
                      final indexToRemove = touchResponse.lineBarSpots!.first.spotIndex;
                      _removePoint(indexToRemove);
                      setState(() { _touchedIndex = null; });
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

  Offset _pixelToChart(Offset localPosition, Size size) {
    final double gridWidth = size.width - _leftTitleWidth - _containerRight;
    final double gridHeight = size.height - _containerTop - _containerBottom - _bottomTitleHeight;

    if (gridWidth <= 0 || gridHeight <= 0) return const Offset(0, 0);

    // Расчет для оси X: от -20 до 90 (всего 110 единиц)
    double x = -20.0 + ((localPosition.dx - _leftTitleWidth) / gridWidth) * 110.0;
    // Расчет для оси Y: от 0 до 105
    double y = 105.0 - (((localPosition.dy - _containerTop) / gridHeight) * 105.0);

    return Offset(x, y);
  }

  void _updatePoint(int index, Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final chartCoords = _pixelToChart(localPosition, renderBox.size);

    double x = chartCoords.dx;
    double y = chartCoords.dy.clamp(0.0, 100.0);

    final selectedIds = ref.read(selectedMonitorsProvider);
    final settingsMap =
        ref.read(settingsProvider).value ?? {'all': SettingsState()};
    final currentPoints =
        settingsMap[selectedIds.first]?.curvePoints ??
        settingsMap['all']!.curvePoints;
    final newPoints = List<FlSpot>.from(currentPoints);

    if (index == 0 || index == newPoints.length - 1) {
      x = index == 0 ? -20.0 : 90.0;
      newPoints[index] = FlSpot(x, y); // Мы больше не синхронизируем концы, так как это не цикл времени
    } else {
      final double minX = newPoints[index - 1].x + 1.0; // Зазор в 1 градус
      final double maxX = newPoints[index + 1].x - 1.0;
      x = x.clamp(minX, maxX);
      
      newPoints[index] = FlSpot(x, y);
    }

    ref.read(settingsProvider.notifier).updateCurvePoints(newPoints);
  }

  void _addPointAt(Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final chartCoords = _pixelToChart(localPosition, renderBox.size);

    double x = chartCoords.dx.clamp(-20.0, 90.0);
    double y = chartCoords.dy.clamp(0.0, 100.0);

    final selectedIds = ref.read(selectedMonitorsProvider);
    final settingsMap =
        ref.read(settingsProvider).value ?? {'all': SettingsState()};
    final currentSettings =
        settingsMap[selectedIds.first] ?? settingsMap['all']!;
    final currentPoints = currentSettings.curvePoints;
    bool tooClose = currentPoints.any((p) => (p.x - x).abs() < 2.0); // Защита от спама точками

    if (!tooClose) {
      ref.read(settingsProvider.notifier).addCurvePoint(FlSpot(x, y));
    }
  }

  void _removePoint(int index) {
    final selectedIds = ref.read(selectedMonitorsProvider);
    final settingsMap =
        ref.read(settingsProvider).value ?? {'all': SettingsState()};
    final currentPoints =
        settingsMap[selectedIds.first]?.curvePoints ??
        settingsMap['all']!.curvePoints;
    if (index == 0 || index == currentPoints.length - 1) return;
    ref.read(settingsProvider.notifier).removeCurvePoint(index);
  }
}
