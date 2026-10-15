import 'package:equatable/equatable.dart';

class MonitorRegulationEntry<T> {
  const MonitorRegulationEntry({
    required this.id,
    required this.name,
    required this.target,
    required this.signature,
    this.appliedValue,
    this.offset = 0,
    this.minimum = 0,
  });

  final String id;
  final String name;
  final T? target;
  final List<Object?> signature;
  final double? appliedValue;
  final double offset;
  final double minimum;
}

class RegulationGroup<T> {
  RegulationGroup(Iterable<MonitorRegulationEntry<T>> members)
    : members = List.unmodifiable(members);

  final List<MonitorRegulationEntry<T>> members;
  MonitorRegulationEntry<T> get representative => members.first;
}

class _CalculationKey extends Equatable {
  const _CalculationKey(this.values);
  final List<Object?> values;
  @override
  List<Object?> get props => values;
}

/// Groups complete effective calculations, never just equal final percentages.
List<RegulationGroup<T>> groupRegulations<T>(
  Iterable<MonitorRegulationEntry<T>> entries,
) {
  final groups = <_CalculationKey, List<MonitorRegulationEntry<T>>>{};
  for (final entry in entries) {
    // Unavailable calculations cannot establish equality across displays.
    final key = _CalculationKey(
      entry.target == null ? [null, entry.id] : entry.signature,
    );
    groups.putIfAbsent(key, () => []).add(entry);
  }
  return List.unmodifiable(groups.values.map(RegulationGroup<T>.new));
}
