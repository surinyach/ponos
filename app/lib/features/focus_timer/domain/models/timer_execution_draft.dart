class TimerExecutionDraft {
  const TimerExecutionDraft({
    this.focusAreaId,
    this.specialActivityId,
    required this.workDate,
    required this.startedAt,
    required this.startedAtUtcOffset,
    required this.endedAt,
    required this.endedAtUtcOffset,
    required this.focusedTime,
    required this.restTime,
  }) : assert((focusAreaId == null) != (specialActivityId == null));

  final int? focusAreaId;
  final int? specialActivityId;
  final DateTime workDate;
  final DateTime startedAt;
  final Duration startedAtUtcOffset;
  final DateTime endedAt;
  final Duration endedAtUtcOffset;
  final Duration focusedTime;
  final Duration restTime;
}
