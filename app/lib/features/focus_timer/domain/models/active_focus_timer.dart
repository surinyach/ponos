enum FocusTimerPhase { focus, rest }

enum FocusTimerActivity { running, paused }

/// Persistable domain snapshot for one execution that has not ended yet.
///
/// [runningSince] is an absolute instant used with the accumulated durations
/// after resume/background recovery. It is null exactly while paused.
class ActiveFocusTimer {
  ActiveFocusTimer({
    required this.focusAreaId,
    required this.workDate,
    required this.startedAt,
    required this.focusDuration,
    required this.restDuration,
    required this.phase,
    required this.activity,
    required this.accumulatedFocusTime,
    required this.accumulatedRestTime,
    required this.focusTransitionNotified,
    this.runningSince,
  }) : assert(focusAreaId > 0),
       assert(focusDuration.inMicroseconds > 0),
       assert(restDuration.inMicroseconds > 0),
       assert(!accumulatedFocusTime.isNegative),
       assert(!accumulatedRestTime.isNegative),
       assert(
         workDate.hour == 0 &&
             workDate.minute == 0 &&
             workDate.second == 0 &&
             workDate.millisecond == 0 &&
             workDate.microsecond == 0,
       ),
       assert(
         activity == FocusTimerActivity.running
             ? runningSince != null
             : runningSince == null,
       );

  final int focusAreaId;

  /// Local calendar date captured once when the execution starts.
  final DateTime workDate;

  /// Absolute instant at which the execution originally started.
  final DateTime startedAt;

  final Duration focusDuration;
  final Duration restDuration;
  final FocusTimerPhase phase;
  final FocusTimerActivity activity;

  /// Completed elapsed segments, excluding the currently running segment.
  final Duration accumulatedFocusTime;
  final Duration accumulatedRestTime;

  /// Start instant of the current running segment, or null while paused.
  final DateTime? runningSince;

  /// Prevents replaying the focus-to-rest alarm after state recovery.
  final bool focusTransitionNotified;

  bool get isPaused => activity == FocusTimerActivity.paused;

  ActiveFocusTimer copyWith({
    FocusTimerPhase? phase,
    FocusTimerActivity? activity,
    Duration? accumulatedFocusTime,
    Duration? accumulatedRestTime,
    DateTime? runningSince,
    bool clearRunningSince = false,
    bool? focusTransitionNotified,
  }) => ActiveFocusTimer(
    focusAreaId: focusAreaId,
    workDate: workDate,
    startedAt: startedAt,
    focusDuration: focusDuration,
    restDuration: restDuration,
    phase: phase ?? this.phase,
    activity: activity ?? this.activity,
    accumulatedFocusTime: accumulatedFocusTime ?? this.accumulatedFocusTime,
    accumulatedRestTime: accumulatedRestTime ?? this.accumulatedRestTime,
    runningSince: clearRunningSince ? null : runningSince ?? this.runningSince,
    focusTransitionNotified:
        focusTransitionNotified ?? this.focusTransitionNotified,
  );
}
