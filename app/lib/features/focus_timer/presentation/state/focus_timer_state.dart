import '../../domain/models/active_focus_timer.dart';

enum FocusTimerStatus {
  restoring,
  inactive,
  running,
  paused,
  persisting,
  error,
}

class FocusTimerState {
  const FocusTimerState({
    required this.status,
    this.activeTimer,
    this.elapsedFocusTime = Duration.zero,
    this.elapsedRestTime = Duration.zero,
    this.error,
  });

  const FocusTimerState.restoring() : this(status: FocusTimerStatus.restoring);
  const FocusTimerState.inactive() : this(status: FocusTimerStatus.inactive);

  final FocusTimerStatus status;
  final ActiveFocusTimer? activeTimer;
  final Duration elapsedFocusTime;
  final Duration elapsedRestTime;
  final Object? error;

  Duration get phaseElapsed => switch (activeTimer?.phase) {
    FocusTimerPhase.focus => elapsedFocusTime,
    FocusTimerPhase.rest => elapsedRestTime,
    null => Duration.zero,
  };

  Duration get phaseDuration => switch (activeTimer?.phase) {
    FocusTimerPhase.focus => activeTimer!.focusDuration,
    FocusTimerPhase.rest => activeTimer!.restDuration,
    null => Duration.zero,
  };

  Duration get phaseRemaining {
    final remaining = phaseDuration - phaseElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
