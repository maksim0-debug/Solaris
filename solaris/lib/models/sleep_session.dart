import 'package:equatable/equatable.dart';

enum SleepPhase {
  deep,
  light,
  rem,
  awake,
  unknown;

  static SleepPhase fromGoogleFit(int? type) {
    return switch (type) {
      4 => SleepPhase.light,
      5 => SleepPhase.deep,
      6 => SleepPhase.rem,
      1 => SleepPhase.awake,
      _ => SleepPhase.unknown,
    };
  }
}

class SleepSession extends Equatable {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String? title;
  final String? description;
  final List<SleepSegment> segments;

  final String source;
  final bool isPermanent;

  const SleepSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.title,
    this.description,
    this.segments = const [],
    this.source = 'google_fit',
    this.isPermanent = false,
  });

  Duration get duration => endTime.difference(startTime);

  SleepSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    String? title,
    String? description,
    List<SleepSegment>? segments,
    String? source,
    bool? isPermanent,
  }) {
    return SleepSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      description: description ?? this.description,
      segments: segments ?? this.segments,
      source: source ?? this.source,
      isPermanent: isPermanent ?? this.isPermanent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'title': title,
    'description': description,
    'segments': segments.map((s) => s.toJson()).toList(),
    'source': source,
    'isPermanent': isPermanent,
  };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
    id: json['id'] as String,
    startTime: DateTime.parse(json['startTime'] as String).toUtc(),
    endTime: DateTime.parse(json['endTime'] as String).toUtc(),
    title: json['title'] as String?,
    description: json['description'] as String?,
    segments:
        (json['segments'] as List?)
            ?.map((s) => SleepSegment.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
    source: json['source'] as String? ?? 'google_fit',
    isPermanent: json['isPermanent'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    id,
    startTime,
    endTime,
    title,
    description,
    segments,
    source,
    isPermanent,
  ];
}

class SleepSegment extends Equatable {
  final DateTime startTime;
  final DateTime endTime;
  final SleepPhase phase;

  const SleepSegment({
    required this.startTime,
    required this.endTime,
    required this.phase,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'phase': phase.name,
  };

  factory SleepSegment.fromJson(Map<String, dynamic> json) => SleepSegment(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    phase: SleepPhase.values.firstWhere(
      (e) => e.name == json['phase'],
      orElse: () => SleepPhase.unknown,
    ),
  );

  @override
  List<Object?> get props => [startTime, endTime, phase];
}
