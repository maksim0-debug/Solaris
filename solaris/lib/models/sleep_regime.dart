import 'package:equatable/equatable.dart';
import 'night_group.dart';

enum SleepRegimeType {
  earlyBird, // Morning person
  nightOwl, // Night person
  consistent, // Balanced / Normal
  irregular, // No clear pattern
  floating; // Shift work / constantly changing

  String get label => switch (this) {
    SleepRegimeType.earlyBird => 'Early Bird',
    SleepRegimeType.nightOwl => 'Night Owl',
    SleepRegimeType.consistent => 'Consistent',
    SleepRegimeType.irregular => 'Irregular',
    SleepRegimeType.floating => 'Floating',
  };
}

class SleepRegime extends Equatable {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final int averageBedtimeNormalized;
  final String averageBedtimeFormatted;
  final int averageWakeTimeNormalized;
  final String averageWakeTimeFormatted;
  final String windowStart;
  final String windowEnd;
  final List<DateTime> anomalyDates;
  final RegimeShift? shiftFromPrevious;
  final bool isCurrent;
  final int dayCount;
  final List<NightGroup> nights;
  final bool isFloating;

  const SleepRegime({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.averageBedtimeNormalized,
    required this.averageBedtimeFormatted,
    required this.averageWakeTimeNormalized,
    required this.averageWakeTimeFormatted,
    required this.windowStart,
    required this.windowEnd,
    required this.anomalyDates,
    this.shiftFromPrevious,
    required this.isCurrent,
    required this.dayCount,
    required this.nights,
    required this.isFloating,
  });

  @override
  List<Object?> get props => [
    id,
    startDate,
    endDate,
    averageBedtimeNormalized,
    averageBedtimeFormatted,
    averageWakeTimeNormalized,
    averageWakeTimeFormatted,
    windowStart,
    windowEnd,
    anomalyDates,
    shiftFromPrevious,
    isCurrent,
    dayCount,
    nights,
    isFloating,
  ];
}

class RegimeShift extends Equatable {
  final bool isLater;
  final Duration shiftDuration;

  const RegimeShift({required this.isLater, required this.shiftDuration});

  @override
  List<Object?> get props => [isLater, shiftDuration];
}
