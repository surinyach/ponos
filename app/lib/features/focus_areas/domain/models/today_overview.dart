import 'focus_area.dart';
import 'work_totals.dart';
import '../../../work_entries/domain/models/special_activity.dart';

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

class SpecialActivityTodayProgress {
  const SpecialActivityTodayProgress({
    required this.specialActivity,
    required this.focusedTime,
    required this.restTime,
  });

  final SpecialActivity specialActivity;
  final Duration focusedTime;
  final Duration restTime;
}

enum DailyCompletionState { completed, failed, neutral, inProgress }

class DailyCompletion {
  const DailyCompletion({required this.date, required this.state});

  final DateTime date;
  final DailyCompletionState state;
  bool get completed => state == DailyCompletionState.completed;
}

class StreakSummary {
  const StreakSummary({
    required this.currentDailyStreak,
    required this.currentWeeklyStreak,
    required this.recentDays,
  });

  final int currentDailyStreak;
  final int currentWeeklyStreak;
  final List<DailyCompletion> recentDays;
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
    this.specialActivities = const [],
    required this.streak,
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
  final List<SpecialActivityTodayProgress> specialActivities;
  final StreakSummary streak;
  final WeeklyWorkTotals week;
  final OverallWorkTotals overall;
}
