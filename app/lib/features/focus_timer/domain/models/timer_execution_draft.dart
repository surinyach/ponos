class TimerExecutionDraft {
  const TimerExecutionDraft({
    required this.focusAreaId,
    required this.workDate,
    required this.startedAt,
    required this.endedAt,
    required this.focusedTime,
    required this.restTime,
  });

  final int focusAreaId;
  final DateTime workDate;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration focusedTime;
  final Duration restTime;
}
