import '../models/active_focus_timer.dart';

abstract interface class ActiveFocusTimerStore {
  Future<ActiveFocusTimer?> load();
  Future<void> save(ActiveFocusTimer timer);
  Future<void> clear();
}

/// Boundary for the alarm and platform notification implementation.
abstract interface class FocusTimerTransitionEffect {
  Future<void> onRestStarted();
}
