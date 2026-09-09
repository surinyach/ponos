import '../../domain/models/timer_execution_draft.dart';

class TimerExecutionCreateDto {
  const TimerExecutionCreateDto({
    required this.focusAreaId,
    required this.workDate,
    required this.startedAt,
    required this.startedAtUtcOffset,
    required this.endedAt,
    required this.endedAtUtcOffset,
    required this.focusedSeconds,
    required this.restSeconds,
  });

  factory TimerExecutionCreateDto.fromDomain(TimerExecutionDraft execution) =>
      TimerExecutionCreateDto(
        focusAreaId: execution.focusAreaId,
        workDate: execution.workDate,
        startedAt: execution.startedAt,
        startedAtUtcOffset: execution.startedAtUtcOffset,
        endedAt: execution.endedAt,
        endedAtUtcOffset: execution.endedAtUtcOffset,
        focusedSeconds: execution.focusedTime.inSeconds,
        restSeconds: execution.restTime.inSeconds,
      );

  final int focusAreaId;
  final DateTime workDate;
  final DateTime startedAt;
  final Duration startedAtUtcOffset;
  final DateTime endedAt;
  final Duration endedAtUtcOffset;
  final int focusedSeconds;
  final int restSeconds;

  Map<String, Object> toJson() => {
    'focus_area_id': focusAreaId,
    'work_date': _date(workDate),
    'started_at': _timestamp(startedAt, startedAtUtcOffset),
    'ended_at': _timestamp(endedAt, endedAtUtcOffset),
    'focused_seconds': focusedSeconds,
    'rest_seconds': restSeconds,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _timestamp(DateTime instant, Duration offset) {
    final localParts = instant.toUtc().add(offset);
    final timestamp = localParts.toIso8601String().replaceFirst(
      RegExp(r'Z$'),
      '',
    );
    final minutes = offset.inMinutes;
    final sign = minutes < 0 ? '-' : '+';
    final absolute = minutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final remainder = (absolute % 60).toString().padLeft(2, '0');
    return '$timestamp$sign$hours:$remainder';
  }
}
