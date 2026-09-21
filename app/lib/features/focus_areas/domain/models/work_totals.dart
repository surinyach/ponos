class WorkTotals {
  const WorkTotals({
    required this.focusedTime,
    required this.restTime,
    required this.trackedTime,
  });

  final Duration focusedTime;
  final Duration restTime;
  final Duration trackedTime;
}

class WeeklyWorkTotals extends WorkTotals {
  const WeeklyWorkTotals({
    required this.weekStart,
    required this.weekEnd,
    required super.focusedTime,
    required super.restTime,
    required super.trackedTime,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
}

class OverallWorkTotals extends WorkTotals {
  const OverallWorkTotals({
    required this.daysWorked,
    required super.focusedTime,
    required super.restTime,
    required super.trackedTime,
  });

  final int daysWorked;
}
