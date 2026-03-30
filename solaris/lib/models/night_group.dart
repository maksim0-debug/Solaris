import 'package:equatable/equatable.dart';
import 'sleep_session.dart';

/// Groups one or more [SleepSession]s that belong to the same "night".
class NightGroup extends Equatable {
  final DateTime date; // Representative date of the night
  final SleepSession aggregatedSession;
  final List<SleepSession> allSessions;
  final bool isOutdated;

  const NightGroup({
    required this.date,
    required this.aggregatedSession,
    this.allSessions = const [],
    this.isOutdated = false,
  });

  @override
  List<Object?> get props => [date, aggregatedSession, allSessions, isOutdated];
}
