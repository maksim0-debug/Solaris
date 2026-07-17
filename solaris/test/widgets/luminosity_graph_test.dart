import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/widgets/luminosity_graph.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  testWidgets('LuminosityGraph generates spots correct for NY timezone', (WidgetTester tester) async {
    final nyLocation = tz.getLocation('America/New_York');
    
    // NY sunrise on 2026-07-18 is around 05:45 local time
    final sunrise = tz.TZDateTime(nyLocation, 2026, 7, 18, 5, 45);
    final sunset = tz.TZDateTime(nyLocation, 2026, 7, 18, 20, 20);
    final noon = tz.TZDateTime(nyLocation, 2026, 7, 18, 13, 0);

    final phases = SolarPhaseModel(
      sunrise: sunrise,
      sunset: sunset,
      goldenHourMorning: sunrise,
      goldenHourMorningEnd: sunrise.add(const Duration(hours: 1)),
      goldenHourEvening: sunset.subtract(const Duration(hours: 1)),
      goldenHourEveningEnd: sunset,
      civilTwilightBegin: sunrise.subtract(const Duration(minutes: 30)),
      civilTwilightEnd: sunset.add(const Duration(minutes: 30)),
      astronomicalDawn: sunrise.subtract(const Duration(hours: 1)),
      civilDusk: sunset.add(const Duration(minutes: 30)),
      solarNoon: noon,
      astronomicalDusk: sunset.add(const Duration(hours: 1)),
    );

    // NY coordinates
    const lat = 40.7128;
    const lon = -74.0060;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 500,
            child: LuminosityGraph(
              phases: phases,
              currentElevation: 10,
              lat: lat,
              lon: lon,
            ),
          ),
        ),
      ),
    );

    // Find the LineChart widget
    final lineChartFinder = find.byType(LineChart);
    expect(lineChartFinder, findsOneWidget);

    final LineChart lineChart = tester.widget(lineChartFinder);
    // In fl_chart, LineChart has a 'data' field. Let's make sure it's accessible.
    final spots = lineChart.data.lineBarsData[0].spots;

    // The spots list should have 49 items (0 to 24 with 0.5 step)
    expect(spots.length, 49);

    // The maximum elevation spot should correspond to solar noon (around 12:00 or 13:00 local NY time)
    double maxElevation = -999;
    double maxElevationHour = -1;
    for (final spot in spots) {
      if (spot.y > maxElevation) {
        maxElevation = spot.y;
        maxElevationHour = spot.x;
      }
    }

    // Solar noon is at 13:00 NY local time on this day, so peak should be around 13.0
    expect(maxElevationHour, closeTo(13.0, 0.6));
  });
}
