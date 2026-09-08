import 'package:flutter/foundation.dart';

import '../domain/models/focus_area.dart';
import '../domain/models/focus_area_input.dart';
import '../domain/models/focus_area_target.dart';

@immutable
class WeekdayTargetFormData {
  const WeekdayTargetFormData({required this.enabled, required this.minutes});

  final bool enabled;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is WeekdayTargetFormData &&
      enabled == other.enabled &&
      minutes == other.minutes;

  @override
  int get hashCode => Object.hash(enabled, minutes);
}

@immutable
class FocusAreaFormData {
  const FocusAreaFormData({
    required this.name,
    required this.priority,
    required this.targets,
    this.description,
    this.targetEndDate,
  });

  factory FocusAreaFormData.empty() => const FocusAreaFormData(
    name: '',
    priority: 1,
    targets: [
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
      WeekdayTargetFormData(enabled: false, minutes: 60),
    ],
  );

  factory FocusAreaFormData.fromArea(FocusArea area, DateTime today) {
    final targets = List.generate(7, (index) {
      final target = _currentTarget(area.targets, index + 1, today);
      return WeekdayTargetFormData(
        enabled: target != null && target.targetMinutes > 0,
        minutes: target?.targetMinutes ?? 60,
      );
    });
    return FocusAreaFormData(
      name: area.name,
      description: area.description,
      priority: area.priority,
      targetEndDate: area.targetEndDate,
      targets: targets,
    );
  }

  final String name;
  final String? description;
  final int priority;
  final DateTime? targetEndDate;
  final List<WeekdayTargetFormData> targets;

  FocusAreaCreateInput toCreateInput(DateTime validFrom) =>
      FocusAreaCreateInput(
        name: name.trim(),
        description: description,
        priority: priority,
        targetEndDate: targetEndDate,
        targets: _inputs(validFrom),
      );

  FocusAreaUpdateInput toUpdateInput(
    FocusArea area,
    FocusAreaFormData initial,
    DateTime validFrom,
  ) {
    final changedTargets = <FocusAreaTargetInput>[];
    for (var index = 0; index < targets.length; index++) {
      if (targets[index] == initial.targets[index]) continue;
      changedTargets.add(
        FocusAreaTargetInput(
          weekday: index + 1,
          targetMinutes: targets[index].enabled ? targets[index].minutes : 0,
          validFrom: _nextAvailableDate(area.targets, index + 1, validFrom),
        ),
      );
    }
    return FocusAreaUpdateInput(
      name: name.trim() == initial.name.trim() ? null : name.trim(),
      description: description == initial.description
          ? const NullableUpdate.unchanged()
          : NullableUpdate.set(description),
      priority: priority == initial.priority ? null : priority,
      targetEndDate: sameDate(targetEndDate, initial.targetEndDate)
          ? const NullableUpdate.unchanged()
          : NullableUpdate.set(targetEndDate),
      targets: changedTargets.isEmpty ? null : changedTargets,
    );
  }

  List<FocusAreaTargetInput> _inputs(DateTime validFrom) => [
    for (var index = 0; index < targets.length; index++)
      if (targets[index].enabled)
        FocusAreaTargetInput(
          weekday: index + 1,
          targetMinutes: targets[index].minutes,
          validFrom: dateOnly(validFrom),
        ),
  ];

  @override
  bool operator ==(Object other) =>
      other is FocusAreaFormData &&
      name == other.name &&
      description == other.description &&
      priority == other.priority &&
      sameDate(targetEndDate, other.targetEndDate) &&
      listEquals(targets, other.targets);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    priority,
    targetEndDate?.year,
    targetEndDate?.month,
    targetEndDate?.day,
    Object.hashAll(targets),
  );
}

FocusAreaTarget? _currentTarget(
  List<FocusAreaTarget> targets,
  int weekday,
  DateTime date,
) {
  final day = dateOnly(date);
  final matches = targets.where((target) {
    final start = dateOnly(target.validFrom);
    final end = target.validUntil == null ? null : dateOnly(target.validUntil!);
    return target.weekday == weekday &&
        !day.isBefore(start) &&
        (end == null || !day.isAfter(end));
  }).toList()..sort((a, b) => a.validFrom.compareTo(b.validFrom));
  return matches.isEmpty ? null : matches.last;
}

DateTime _nextAvailableDate(
  List<FocusAreaTarget> targets,
  int weekday,
  DateTime requested,
) {
  var candidate = dateOnly(requested);
  final starts = targets
      .where((target) => target.weekday == weekday)
      .map((target) => dateOnly(target.validFrom))
      .toList();
  while (starts.any((date) => sameDate(date, candidate))) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool sameDate(DateTime? first, DateTime? second) {
  if (first == null || second == null) return first == second;
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
