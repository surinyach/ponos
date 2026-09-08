import 'focus_area.dart';

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
    required this.completedFocusAreas,
    required this.targetedFocusAreas,
    required this.areas,
  });

  final DateTime date;
  final Duration expectedFocusTime;
  final Duration actualFocusedTime;
  final int completedFocusAreas;
  final int targetedFocusAreas;
  final List<FocusAreaTodayProgress> areas;
}
