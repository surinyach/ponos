import '../models/active_focus_timer.dart';
import '../models/timer_execution_draft.dart';

abstract interface class ActiveFocusTimerStore {
  Future<ActiveFocusTimer?> load();
  Future<void> save(ActiveFocusTimer timer);
  Future<void> clear();
}

/// Boundary for the backend execution endpoint added in a later task.
abstract interface class TimerExecutionRecorder {
  Future<void> save(TimerExecutionDraft execution);
}

/// Boundary for the alarm and platform notification implementation.
abstract interface class FocusTimerTransitionEffect {
  Future<void> onRestStarted();
}
