import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations_en.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:solaris/utils/status_helper.dart';
import 'package:solaris/l10n/app_localizations_uk.dart';
import 'package:solaris/l10n/app_localizations_ru.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  final service = SunCalculatorService();
  DateTime time(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 13, hour, minute);
  final phases = SolarPhaseModel(
    sunrise: time(6),
    sunset: time(18),
    goldenHourMorning: time(5, 30),
    goldenHourMorningEnd: time(6, 30),
    goldenHourEvening: time(17, 30),
    goldenHourEveningEnd: time(18, 30),
    civilTwilightBegin: time(5),
    nextDayCivilTwilightBegin: (time(5)).add(const Duration(days: 1)),
    civilTwilightEnd: time(19),
    astronomicalDawn: time(4),
    civilDusk: time(19),
    solarNoon: time(12),
    astronomicalDusk: time(20),
  );

  SolarState stateAt(DateTime now) {
    final next = service.getNextEvent(phases, now)!;
    return SolarState(
      phases: phases,
      currentPhase: service.getCurrentPhase(phases, now),
      timeUntilNextEvent: next.duration,
      nextEventType: next.type,
      sunElevation: 0,
      sunAzimuth: 0,
      sunZenith: 90,
      sunProgress: 0,
      uvIndex: 0,
      spectralIntensity: 0,
      azimuthTrend: 'constant',
      elevationTrend: 'constant',
      zenithTrend: 'constant',
    );
  }

  for (final scenario in [
    (
      name: 'morning before sunrise',
      now: time(5, 45),
      next: SolarEventType.sunrise,
    ),
    (
      name: 'evening before sunset',
      now: time(17, 45),
      next: SolarEventType.sunset,
    ),
  ]) {
    test('${scenario.name}: card counts down to golden hour end', () {
      final state = stateAt(scenario.now);
      final l10n = AppLocalizationsEn();
      final status = StatusHelper.getStatus(
        state,
        l10n,
        false,
        false,
        scenario.now,
      );

      expect(state.currentPhase, CurrentDayPhase.goldenHour);
      expect(status.title, l10n.phaseGoldenHour);
      expect(status.subtitle, l10n.statusManual.toUpperCase());
      expect(state.nextEventType, scenario.next);
      expect(state.timeUntilNextEvent, const Duration(minutes: 15));
      expect(
        StatusHelper.getRemainingDuration(state, scenario.now),
        const Duration(minutes: 45),
      );
    });
  }

  for (final hour in [6, 18]) {
    test('golden hour after $hour:00 lasts until its own end', () {
      final now = time(hour, 15);
      final state = stateAt(now);
      expect(state.currentPhase, CurrentDayPhase.goldenHour);
      expect(
        state.nextEventType,
        hour == 6
            ? SolarEventType.goldenHourMorningEnd
            : SolarEventType.goldenHourEveningEnd,
      );
      expect(
        StatusHelper.getRemainingDuration(state, now),
        const Duration(minutes: 15),
      );
      expect(
        StatusHelper.getRemainingDuration(state, time(hour, 30)),
        Duration.zero,
      );
      expect(
        StatusHelper.getRemainingDuration(state, time(hour, 31)),
        Duration.zero,
      );
      expect(
        stateAt(time(hour, 30)).currentPhase,
        isNot(CurrentDayPhase.goldenHour),
      );
    });
  }

  test('phases without internal events end at the next event', () {
    for (final now in [time(4), time(5, 15), time(8), time(12), time(18, 45)]) {
      final state = stateAt(now);
      expect(state.currentPhase, isNot(CurrentDayPhase.goldenHour));
      expect(
        StatusHelper.getRemainingDuration(state, now),
        state.timeUntilNextEvent,
      );
    }
  });

  test('solar noon does not reset the zenith countdown', () {
    final beforeNoon = stateAt(time(11, 30));
    expect(beforeNoon.nextEventType, SolarEventType.solarNoon);
    expect(beforeNoon.timeUntilNextEvent, const Duration(minutes: 30));
    expect(
      StatusHelper.getRemainingDuration(beforeNoon, time(11, 30)),
      const Duration(minutes: 90),
    );
    final afterNoon = stateAt(time(12, 30));
    expect(afterNoon.currentPhase, CurrentDayPhase.zenith);
    expect(
      StatusHelper.getRemainingDuration(afterNoon, time(12, 30)),
      const Duration(minutes: 30),
    );
  });

  test('expired overnight state displays zero while awaiting fresh phases', () {
    final night = stateAt(time(23));
    expect(
      StatusHelper.getRemainingDuration(
        night,
        phases.nextDayCivilTwilightBegin,
      ),
      Duration.zero,
    );
  });

  test(
    'exhausted timelines return no event instead of throwing or inventing dawn',
    () {
      for (final now in [
        phases.nextDayCivilTwilightBegin,
        phases.nextDayCivilTwilightBegin.add(const Duration(hours: 1)),
        DateTime(2026, 11, 13, 7),
      ]) {
        expect(service.getNextEvent(phases, now), isNull);
        expect(service.getTimeUntilPhaseEnd(phases, now), Duration.zero);
        expect(service.getTimeUntilNextEvent(phases, now), Duration.zero);
      }
    },
  );

  test('phase date checks detect month, year, and backward clock jumps', () {
    expect(phases.isForDate(time(0)), isTrue);
    expect(phases.isForDate(time(23, 59)), isTrue);
    for (final now in [
      DateTime(2026, 10, 14),
      DateTime(2026, 11, 13),
      DateTime(2027, 10, 13),
      DateTime(2026, 9, 13),
      DateTime(2025, 10, 13),
    ]) {
      expect(phases.isForDate(now), isFalse, reason: '$now');
      expect(StatusHelper.getUpcomingEvent(stateAt(time(23)), now), isNull);
      expect(
        StatusHelper.getRemainingDuration(stateAt(time(23)), now),
        Duration.zero,
      );
    }
  });

  test(
    'both countdowns advance with the UI clock despite a delayed snapshot',
    () {
      final snapshot = stateAt(time(5, 45));
      expect(snapshot.timeUntilNextEvent, const Duration(minutes: 15));
      final next = StatusHelper.getUpcomingEvent(snapshot, time(5, 55))!;
      expect(next.type, SolarEventType.sunrise);
      expect(next.duration, const Duration(minutes: 5));
      expect(
        StatusHelper.getRemainingDuration(snapshot, time(5, 55)),
        const Duration(minutes: 35),
      );

      // Once sunrise passes, the header must select the next event as well.
      final afterSunrise = StatusHelper.getUpcomingEvent(
        snapshot,
        time(6, 10),
      )!;
      expect(afterSunrise.type, SolarEventType.goldenHourMorningEnd);
      expect(afterSunrise.duration, const Duration(minutes: 20));
      expect(
        StatusHelper.getRemainingDuration(snapshot, time(6, 10)),
        afterSunrise.duration,
      );
    },
  );

  test('next event recalculates after the clock moves backward', () {
    final snapshot = stateAt(time(6, 15));
    expect(snapshot.nextEventType, SolarEventType.goldenHourMorningEnd);
    final next = StatusHelper.getUpcomingEvent(snapshot, time(5, 45))!;
    expect(next.type, SolarEventType.sunrise);
    expect(next.duration, const Duration(minutes: 15));
  });

  test('zenith ends at 13:00 and daytime lasts until golden hour', () {
    final state = stateAt(time(13));
    expect(state.currentPhase, CurrentDayPhase.day);
    expect(state.nextEventType, SolarEventType.goldenHourEvening);
    expect(
      StatusHelper.getRemainingDuration(state, time(13)),
      const Duration(hours: 4, minutes: 30),
    );
    for (final l10n in [
      AppLocalizationsEn(),
      AppLocalizationsUk(),
      AppLocalizationsRu(),
    ]) {
      for (final auto in [false, true]) {
        final status = StatusHelper.getStatus(
          state,
          l10n,
          auto,
          false,
          time(13),
        );
        expect(status.title, l10n.phaseDay);
        expect(
          status.description,
          auto ? l10n.descDayAuto : l10n.descDayManual,
        );
        expect(l10n.eventTwilightEnd, isNot(l10n.phaseTwilight));
      }
    }
  });

  test('phase intervals include their start and exclude their end', () {
    final transitions = [
      (
        at: time(5),
        before: CurrentDayPhase.deepNight,
        after: CurrentDayPhase.dawn,
      ),
      (
        at: time(5, 30),
        before: CurrentDayPhase.dawn,
        after: CurrentDayPhase.goldenHour,
      ),
      (
        at: time(6, 30),
        before: CurrentDayPhase.goldenHour,
        after: CurrentDayPhase.morningSpike,
      ),
      (
        at: time(11),
        before: CurrentDayPhase.morningSpike,
        after: CurrentDayPhase.zenith,
      ),
      (
        at: time(13),
        before: CurrentDayPhase.zenith,
        after: CurrentDayPhase.day,
      ),
      (
        at: time(17, 30),
        before: CurrentDayPhase.day,
        after: CurrentDayPhase.goldenHour,
      ),
      (
        at: time(18, 30),
        before: CurrentDayPhase.goldenHour,
        after: CurrentDayPhase.twilight,
      ),
      (
        at: time(19),
        before: CurrentDayPhase.twilight,
        after: CurrentDayPhase.deepNight,
      ),
    ];
    for (final transition in transitions) {
      expect(
        service.getCurrentPhase(
          phases,
          transition.at.subtract(const Duration(microseconds: 1)),
        ),
        transition.before,
      );
      expect(service.getCurrentPhase(phases, transition.at), transition.after);
      expect(
        service.getCurrentPhase(
          phases,
          transition.at.add(const Duration(microseconds: 1)),
        ),
        transition.after,
      );
    }
  });

  test('every minute counts down to the next actual phase change', () {
    final boundaries = [
      time(5),
      time(5, 30),
      time(6, 30),
      time(11),
      time(13),
      time(17, 30),
      time(18, 30),
      time(19),
      phases.nextDayCivilTwilightBegin,
    ];
    for (var minute = 0; minute < 24 * 60; minute++) {
      final now = time(0).add(Duration(minutes: minute));
      final expectedEnd = boundaries.firstWhere((end) => end.isAfter(now));
      final state = stateAt(now);
      expect(
        StatusHelper.getRemainingDuration(state, now),
        expectedEnd.difference(now),
        reason: 'phase=${state.currentPhase.name}, now=$now',
      );
      expect(
        state.timeUntilNextEvent,
        lessThanOrEqualTo(expectedEnd.difference(now)),
      );
    }
  });

  test(
    'night uses calculated next-day dawn across the Kyiv DST change',
    () async {
      tz_data.initializeTimeZones();
      final zone = tz.getLocation('Europe/Kyiv');
      for (final day in [13, 24]) {
        final date = tz.TZDateTime(zone, 2026, 10, day);
        final today = await service.calculatePhases(50.45, 30.52, date, zone);
        final tomorrow = await service.calculatePhases(
          50.45,
          30.52,
          tz.TZDateTime(zone, 2026, 10, day + 1),
          zone,
        );
        final now = tz.TZDateTime(zone, 2026, 10, day, 23);
        expect(today.nextDayCivilTwilightBegin, tomorrow.civilTwilightBegin);
        expect(
          today.nextDayCivilTwilightBegin,
          isNot(today.civilTwilightBegin.add(const Duration(days: 1))),
        );
        final next = service.getNextEvent(today, now)!;
        expect(next.type, SolarEventType.civilTwilightBegin);
        expect(next.duration, tomorrow.civilTwilightBegin.difference(now));
        expect(service.getTimeUntilPhaseEnd(today, now), next.duration);
        expect(
          service.getTimeUntilPhaseEnd(today, today.civilTwilightEnd),
          tomorrow.civilTwilightBegin.difference(today.civilTwilightEnd),
        );
        if (day == 24) {
          expect(
            today.civilTwilightBegin.timeZoneOffset,
            const Duration(hours: 3),
          );
          expect(
            tomorrow.civilTwilightBegin.timeZoneOffset,
            const Duration(hours: 2),
          );
        }
      }
    },
  );
}
