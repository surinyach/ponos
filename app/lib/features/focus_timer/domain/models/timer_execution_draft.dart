class TimerExecutionDraft {
  const TimerExecutionDraft({
    required this.focusAreaId,
    required this.workDate,
    required this.startedAt,
    required this.startedAtUtcOffset,
    required this.endedAt,
    required this.endedAtUtcOffset,
    required this.focusedTime,
    required this.restTime,
  });

  final int focusAreaId;
  final DateTime workDate;
  final DateTime startedAt;
  final Duration startedAtUtcOffset;
  final DateTime endedAt;
  final Duration endedAtUtcOffset;
  final Duration focusedTime;
  final Duration restTime;
}
