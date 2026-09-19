import 'focus_area.dart';
import 'work_totals.dart';

class FocusAreaTodayProgress {
  const FocusAreaTodayProgress({
    required this.focusArea,
    required this.focusedTime,
    required this.completed,
    this.targetTime,
  });

  final FocusArea focusArea;
  final Duration? targetTime;
  final Duration focusedTime;
  final bool completed;
}

class TodayOverview {
  const TodayOverview({
    required this.date,
    required this.expectedFocusTime,
    required this.actualFocusedTime,
    required this.actualRestTime,
    required this.actualTrackedTime,
    required this.completedFocusAreas,
    required this.targetedFocusAreas,
    required this.areas,
    required this.week,
    required this.overall,
  });

  final DateTime date;
  final Duration expectedFocusTime;
  final Duration actualFocusedTime;
  final Duration actualRestTime;
  final Duration actualTrackedTime;
  final int completedFocusAreas;
  final int targetedFocusAreas;
  final List<FocusAreaTodayProgress> areas;
  final WeeklyWorkTotals week;
  final OverallWorkTotals overall;
}
