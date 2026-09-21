import '../../domain/models/today_overview.dart';
import 'focus_area_dto.dart';
import 'focus_area_target_dto.dart';
import 'work_totals_dto.dart';
import '../../../work_entries/data/dtos/special_activity_dto.dart';

class TodayOverviewDto {
  const TodayOverviewDto({
    required this.date,
    required this.expectedFocusSeconds,
    required this.actualFocusedSeconds,
    required this.actualRestSeconds,
    required this.actualTrackedSeconds,
    required this.completedFocusAreas,
    required this.targetedFocusAreas,
    required this.areas,
    required this.specialActivities,
    required this.week,
    required this.overall,
  });

  factory TodayOverviewDto.fromJson(Map<String, Object?> json) {
    final rawAreas = json['areas'];
    if (rawAreas is! List<Object?>) {
      throw const FormatException('areas must be a list');
    }
    return TodayOverviewDto(
      date: requiredDate(json, 'date'),
      expectedFocusSeconds: required<int>(json, 'expected_focus_seconds'),
      actualFocusedSeconds: required<int>(json, 'actual_focused_seconds'),
      actualRestSeconds: required<int>(json, 'actual_rest_seconds'),
      actualTrackedSeconds: required<int>(json, 'actual_tracked_seconds'),
      completedFocusAreas: required<int>(json, 'completed_focus_areas'),
      targetedFocusAreas: required<int>(json, 'targeted_focus_areas'),
      areas: rawAreas
          .map((value) => FocusAreaTodayProgressDto.fromJson(asObject(value)))
          .toList(growable: false),
      specialActivities:
          (json['special_activities'] as List<Object?>? ?? const [])
              .map(
                (value) =>
                    SpecialActivityTodayProgressDto.fromJson(asObject(value)),
              )
              .toList(growable: false),
      week: WeeklyWorkTotalsDto.fromJson(asObject(json['week'])),
      overall: OverallWorkTotalsDto.fromJson(asObject(json['overall'])),
    );
  }

  final DateTime date;
  final int expectedFocusSeconds;
  final int actualFocusedSeconds;
  final int actualRestSeconds;
  final int actualTrackedSeconds;
  final int completedFocusAreas;
  final int targetedFocusAreas;
  final List<FocusAreaTodayProgressDto> areas;
  final List<SpecialActivityTodayProgressDto> specialActivities;
  final WeeklyWorkTotalsDto week;
  final OverallWorkTotalsDto overall;

  TodayOverview toDomain() => TodayOverview(
    date: date,
    expectedFocusTime: Duration(seconds: expectedFocusSeconds),
    actualFocusedTime: Duration(seconds: actualFocusedSeconds),
    actualRestTime: Duration(seconds: actualRestSeconds),
    actualTrackedTime: Duration(seconds: actualTrackedSeconds),
    completedFocusAreas: completedFocusAreas,
    targetedFocusAreas: targetedFocusAreas,
    areas: areas.map((value) => value.toDomain()).toList(growable: false),
    specialActivities: specialActivities
        .map((value) => value.toDomain())
        .toList(growable: false),
    week: week.toDomain(),
    overall: overall.toDomain(),
  );
}

class SpecialActivityTodayProgressDto {
  const SpecialActivityTodayProgressDto({
    required this.activity,
    required this.focusedSeconds,
    required this.restSeconds,
  });

  factory SpecialActivityTodayProgressDto.fromJson(Map<String, Object?> json) =>
      SpecialActivityTodayProgressDto(
        activity: SpecialActivityDto.fromJson(
          asObject(json['special_activity']),
        ),
        focusedSeconds: required<int>(json, 'focused_seconds'),
        restSeconds: required<int>(json, 'rest_seconds'),
      );

  final SpecialActivityDto activity;
  final int focusedSeconds;
  final int restSeconds;

  SpecialActivityTodayProgress toDomain() => SpecialActivityTodayProgress(
    specialActivity: activity.toDomain(),
    focusedTime: Duration(seconds: focusedSeconds),
    restTime: Duration(seconds: restSeconds),
  );
}

class FocusAreaTodayProgressDto {
  const FocusAreaTodayProgressDto({
    required this.focusArea,
    required this.focusedSeconds,
    required this.completed,
    this.targetSeconds,
  });

  factory FocusAreaTodayProgressDto.fromJson(Map<String, Object?> json) =>
      FocusAreaTodayProgressDto(
        focusArea: FocusAreaDto.fromJson(asObject(json['focus_area'])),
        targetSeconds: nullable<int>(json, 'target_seconds'),
        focusedSeconds: required<int>(json, 'focused_seconds'),
        completed: required<bool>(json, 'completed'),
      );

  final FocusAreaDto focusArea;
  final int? targetSeconds;
  final int focusedSeconds;
  final bool completed;

  FocusAreaTodayProgress toDomain() => FocusAreaTodayProgress(
    focusArea: focusArea.toDomain(),
    targetTime: targetSeconds == null
        ? null
        : Duration(seconds: targetSeconds!),
    focusedTime: Duration(seconds: focusedSeconds),
    completed: completed,
  );
}
