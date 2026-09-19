import '../../domain/models/work_totals.dart';
import 'focus_area_dto.dart';
import 'focus_area_target_dto.dart';

class WeeklyWorkTotalsDto {
  const WeeklyWorkTotalsDto({
    required this.weekStart,
    required this.weekEnd,
    required this.focusedSeconds,
    required this.restSeconds,
    required this.trackedSeconds,
  });

  factory WeeklyWorkTotalsDto.fromJson(Map<String, Object?> json) =>
      WeeklyWorkTotalsDto(
        weekStart: requiredDate(json, 'week_start'),
        weekEnd: requiredDate(json, 'week_end'),
        focusedSeconds: required<int>(json, 'focused_seconds'),
        restSeconds: required<int>(json, 'rest_seconds'),
        trackedSeconds: required<int>(json, 'tracked_seconds'),
      );

  final DateTime weekStart;
  final DateTime weekEnd;
  final int focusedSeconds;
  final int restSeconds;
  final int trackedSeconds;

  WeeklyWorkTotals toDomain() => WeeklyWorkTotals(
    weekStart: weekStart,
    weekEnd: weekEnd,
    focusedTime: Duration(seconds: focusedSeconds),
    restTime: Duration(seconds: restSeconds),
    trackedTime: Duration(seconds: trackedSeconds),
  );
}

class OverallWorkTotalsDto {
  const OverallWorkTotalsDto({
    required this.daysWorked,
    required this.focusedSeconds,
    required this.restSeconds,
    required this.trackedSeconds,
  });

  factory OverallWorkTotalsDto.fromJson(Map<String, Object?> json) =>
      OverallWorkTotalsDto(
        daysWorked: required<int>(json, 'days_worked'),
        focusedSeconds: required<int>(json, 'focused_seconds'),
        restSeconds: required<int>(json, 'rest_seconds'),
        trackedSeconds: required<int>(json, 'tracked_seconds'),
      );

  final int daysWorked;
  final int focusedSeconds;
  final int restSeconds;
  final int trackedSeconds;

  OverallWorkTotals toDomain() => OverallWorkTotals(
    daysWorked: daysWorked,
    focusedTime: Duration(seconds: focusedSeconds),
    restTime: Duration(seconds: restSeconds),
    trackedTime: Duration(seconds: trackedSeconds),
  );
}
