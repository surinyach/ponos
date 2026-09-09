import '../models/active_focus_timer.dart';

abstract interface class ActiveFocusTimerStore {
  Future<ActiveFocusTimer?> load();
  Future<void> save(ActiveFocusTimer timer);
  Future<void> clear();
}

enum FocusTimerAlert { focusComplete, restComplete }

/// Boundary for timestamp-based alarm and notification scheduling.
abstract interface class FocusTimerNotificationScheduler {
  Future<void> requestPermissions();
  Future<void> schedule(FocusTimerAlert alert, DateTime scheduledAt);
  Future<void> cancel(FocusTimerAlert alert);
  Future<void> cancelAll();
}
