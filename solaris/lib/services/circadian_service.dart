import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/solar_phase_model.dart';

class CircadianService {
  /// Вычисляет целевую яркость исключительно на основе высоты солнца (elevation)
  double calculateTargetBrightness(
    SolarPhaseModel phases,
    double elevation,
    DateTime now, {
    double curveSharpness = 1.0,
    List<FlSpot>? curvePoints,
  }) {
    if (curvePoints != null && curvePoints.isNotEmpty) {
      return _calculateFromElevation(curvePoints, elevation);
    }
    // Фолбэк, если точки не загрузились - используем дефолтные значения из графика
    // -20 elevation -> 15% brightness, 30+ elevation -> 100% brightness
    if (elevation < -6) return 15.0;
    if (elevation > 20) return 100.0;
    return 60.0;
  }

  double _calculateFromElevation(List<FlSpot> points, double currentElevation) {
    if (points.isEmpty) return 15.0;

    // Ограничители, если солнце ушло за пределы графика
    if (currentElevation <= points.first.x) return points.first.y;
    if (currentElevation >= points.last.x) return points.last.y;

    // Линейная интерполяция между двумя ближайшими точками по высоте солнца
    for (int i = 0; i < points.length - 1; i++) {
      if (currentElevation >= points[i].x && currentElevation <= points[i + 1].x) {
        final p1 = points[i];
        final p2 = points[i + 1];
        if (p2.x == p1.x) return p1.y; // Защита от деления на ноль
        
        final t = (currentElevation - p1.x) / (p2.x - p1.x);
        return p1.y + (p2.y - p1.y) * t;
      }
    }
    
    return points.last.y;
  }
}
