class DailyWorkGoal {
  const DailyWorkGoal({required this.weekday, required this.targetMinutes});

  final int weekday;
  final int targetMinutes;
}

class WorkGoals {
  const WorkGoals({
    required this.date,
    required this.dailyGoals,
    required this.weeklyGoalMinutes,
    required this.weeklyGoalEffectiveFrom,
  });

  final DateTime date;
  final List<DailyWorkGoal> dailyGoals;
  final int weeklyGoalMinutes;
  final DateTime? weeklyGoalEffectiveFrom;
}
