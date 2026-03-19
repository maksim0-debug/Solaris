import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solaris/providers.dart';

class CircadianChartWidget extends ConsumerStatefulWidget {
  const CircadianChartWidget({super.key});

  @override
  ConsumerState<CircadianChartWidget> createState() => _CircadianChartWidgetState();
}

class _CircadianChartWidgetState extends ConsumerState<CircadianChartWidget> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final points = settings.curvePoints;

    // Define main colors
    const dayColor = Color(0xFFFDBA74); // Orange
    const nightColor = Colors.indigoAccent; // Blue
    const twilightColor = Colors.purpleAccent; // Purple

    // Find current brightness on the curve for the marker
    final currentHour = now.hour + (now.minute / 60.0);
    double? currentBrightnessY;
    
    // Simple interpolation for the marker
    for (int i = 0; i < points.length - 1; i++) {
      if (currentHour >= points[i].x && currentHour <= points[i + 1].x) {
        final t = (currentHour - points[i].x) / (points[i+1].x - points[i].x);
        currentBrightnessY = points[i].y + (points[i+1].y - points[i].y) * t;
        break;
      }
    }

    return AspectRatio(
      aspectRatio: 2.2,
      child: Container(
        padding: const EdgeInsets.only(top: 20, right: 24, bottom: 6),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 25,
              verticalInterval: 4,
              getDrawingHorizontalLine: (value) => const FlLine(
                color: Colors.white10,
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => const FlLine(
                color: Colors.white10,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 4,
                  getTitlesWidget: (value, meta) {
                    final hour = value.toInt();
                    if (hour < 0 || hour > 24) return const SizedBox();
                    final timeStr = DateFormat('HH:00').format(DateTime(now.year, now.month, now.day, hour));
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        timeStr,
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  reservedSize: 32,
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
            minX: 0,
            maxX: 24,
            minY: 0,
            maxY: 105,
            
            lineBarsData: [
              // The main curve
              LineChartBarData(
                spots: points,
                isCurved: true,
                curveSmoothness: 0.3,
                gradient: const LinearGradient(
                  colors: [nightColor, twilightColor, dayColor, twilightColor, nightColor],
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
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
              
              // Current time marker
              if (currentBrightnessY != null)
                LineChartBarData(
                  spots: [FlSpot(currentHour, currentBrightnessY)],
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
                if (touchResponse == null || touchResponse.lineBarSpots == null) {
                  if (event is FlTapUpEvent) {
                    // Try to add a point on tap if not touching anything
                    _addPointAt(event.localPosition, context);
                  }
                  return;
                }

                final spotIndex = touchResponse.lineBarSpots!.first.spotIndex;

                if (event is FlPanStartEvent || event is FlTapDownEvent) {
                  setState(() {
                    _touchedIndex = spotIndex;
                  });
                } else if (event is FlPanUpdateEvent) {
                  if (_touchedIndex != null) {
                    _updatePoint(_touchedIndex!, event.localPosition, context);
                  }
                } else if (event is FlPanEndEvent || event is FlTapUpEvent) {
                  setState(() {
                    _touchedIndex = null;
                  });
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Colors.transparent,
                getTooltipItems: (touchedSpots) => [], // Hide tooltip items
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updatePoint(int index, Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    
    // Convert local position to chart coordinates
    // We need to account for the padding in Container
    const topPadding = 20.0;
    const rightPadding = 24.0;
    const bottomPadding = 6.0;
    const leftPadding = 32.0; // Estimate for titles

    final width = size.width - leftPadding - rightPadding;
    final height = size.height - topPadding - bottomPadding;

    double x = ((localPosition.dx - leftPadding) / width) * 24;
    double y = 105 - ((localPosition.dy - topPadding) / height) * 105;

    x = x.clamp(0.0, 24.0);
    y = y.clamp(0.0, 100.0);

    final currentPoints = ref.read(settingsProvider).curvePoints;
    final newPoints = List<FlSpot>.from(currentPoints);

    // If moving 0, move 24 too (sync midnight)
    if (newPoints[index].x == 0) {
      newPoints[index] = FlSpot(0, y);
      final index24 = newPoints.indexWhere((p) => p.x == 24);
      if (index24 != -1) newPoints[index24] = FlSpot(24, y);
    } else if (newPoints[index].x == 24) {
      newPoints[index] = FlSpot(24, y);
      final index0 = newPoints.indexWhere((p) => p.x == 0);
      if (index0 != -1) newPoints[index0] = FlSpot(0, y);
    } else {
      newPoints[index] = FlSpot(x, y);
    }

    ref.read(settingsProvider.notifier).updateCurvePoints(newPoints);
  }

  void _addPointAt(Offset localPosition, BuildContext context) {
    // Only add if not too close to existing points
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    
    const topPadding = 20.0;
    const rightPadding = 24.0;
    const bottomPadding = 6.0;
    const leftPadding = 32.0;

    final width = size.width - leftPadding - rightPadding;
    final height = size.height - topPadding - bottomPadding;

    double x = ((localPosition.dx - leftPadding) / width) * 24;
    double y = 105 - ((localPosition.dy - topPadding) / height) * 105;

    x = x.clamp(0.0, 24.0);
    y = y.clamp(0.0, 100.0);

    // Simple proximity check
    final currentPoints = ref.read(settingsProvider).curvePoints;
    bool tooClose = currentPoints.any((p) => (p.x - x).abs() < 0.5);
    
    if (!tooClose) {
      ref.read(settingsProvider.notifier).addCurvePoint(FlSpot(x, y));
    }
  }

  void _removePoint(int index) {
    ref.read(settingsProvider.notifier).removeCurvePoint(index);
  }
}
