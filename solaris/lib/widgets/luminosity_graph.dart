import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solar_calculator/solar_calculator.dart';

class LuminosityGraph extends StatelessWidget {
  final SolarPhaseModel phases;
  final double currentElevation;
  final double lat;
  final double lon;

  const LuminosityGraph({
    super.key,
    required this.phases,
    required this.currentElevation,
    required this.lat,
    required this.lon,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 30,
          verticalInterval: 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            );
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
              reservedSize: 30,
              interval: 4,
              getTitlesWidget: (value, meta) {
                if (value % 4 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${value.toInt().toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.bold,
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
              interval: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}°',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 24,
        minY: -90,
        maxY: 90,
        lineBarsData: [
          LineChartBarData(
            spots: _generateSpots(),
            isCurved: true,
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF97316).withOpacity(0.2),
                  const Color(0xFFF97316).withOpacity(0),
                ],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.x.toInt()}:00\n${spot.y.toStringAsFixed(1)}°',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    List<FlSpot> spots = [];
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day); // Полночь

    // Считаем высоту солнца каждые 30 минут (0.5 часа) для идеальной кривой
    for (double hour = 0; hour <= 24; hour += 0.5) {
      final time = startOfDay.add(Duration(minutes: (hour * 60).toInt()));

      // Используем реальную астрономическую формулу пакета
      final calc = SolarCalculator(Instant.fromDateTime(time), lat, lon);
      final elevation = calc.sunHorizontalPosition.elevation;

      spots.add(FlSpot(hour, elevation));
    }
    return spots;
  }
}
