import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';

void main() {
  test('captures the complete recoverable running state', () {
    final startedAt = DateTime.utc(2026, 9, 8, 21, 50);
    final resumedAt = DateTime.utc(2026, 9, 8, 22, 5);

    final state = ActiveFocusTimer(
      focusAreaId: 7,
      workDate: DateTime(2026, 9, 8),
      startedAt: startedAt,
      focusDuration: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 5),
      phase: FocusTimerPhase.rest,
      activity: FocusTimerActivity.running,
      accumulatedFocusTime: const Duration(minutes: 25),
      accumulatedRestTime: const Duration(minutes: 2),
      runningSince: resumedAt,
      focusTransitionNotified: true,
    );

    expect(state.focusAreaId, 7);
    expect(state.workDate, DateTime(2026, 9, 8));
    expect(state.startedAt, startedAt);
    expect(state.phase, FocusTimerPhase.rest);
    expect(state.runningSince, resumedAt);
    expect(state.focusTransitionNotified, isTrue);
    expect(state.isPaused, isFalse);
  });

  test('paused state retains accumulated phase time without a running instant', () {
    final state = ActiveFocusTimer(
      focusAreaId: 1,
      workDate: DateTime(2026, 9, 8),
      startedAt: DateTime.utc(2026, 9, 8, 8),
      focusDuration: const Duration(minutes: 50),
      restDuration: const Duration(minutes: 10),
      phase: FocusTimerPhase.focus,
      activity: FocusTimerActivity.paused,
      accumulatedFocusTime: const Duration(minutes: 12),
      accumulatedRestTime: Duration.zero,
      focusTransitionNotified: false,
    );

    expect(state.isPaused, isTrue);
    expect(state.runningSince, isNull);
    expect(state.accumulatedFocusTime, const Duration(minutes: 12));
  });

  test('rejects snapshots whose activity and running instant disagree', () {
    expect(
      () => ActiveFocusTimer(
        focusAreaId: 1,
        workDate: DateTime(2026, 9, 8),
        startedAt: DateTime.utc(2026, 9, 8, 8),
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
        phase: FocusTimerPhase.focus,
        activity: FocusTimerActivity.running,
        accumulatedFocusTime: Duration.zero,
        accumulatedRestTime: Duration.zero,
        focusTransitionNotified: false,
      ),
      throwsAssertionError,
    );
  });
}
