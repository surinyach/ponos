import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/focus_timer/data/shared_preferences_focus_timer_store.dart';
import '../../features/focus_timer/domain/models/timer_execution_draft.dart';
import '../../features/focus_timer/domain/repositories/focus_timer_gateways.dart';

final focusTimerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final activeFocusTimerStoreProvider = Provider<ActiveFocusTimerStore>(
  (ref) => SharedPreferencesFocusTimerStore(SharedPreferencesAsync()),
);

final timerExecutionRecorderProvider = Provider<TimerExecutionRecorder>(
  (ref) => const _UnavailableTimerExecutionRecorder(),
);

final focusTimerTransitionEffectProvider = Provider<FocusTimerTransitionEffect>(
  (ref) => const _NoopFocusTimerTransitionEffect(),
);

class _UnavailableTimerExecutionRecorder implements TimerExecutionRecorder {
  const _UnavailableTimerExecutionRecorder();

  @override
  Future<void> save(TimerExecutionDraft execution) => Future.error(
    UnsupportedError('Timer execution API integration is not configured yet.'),
  );
}

class _NoopFocusTimerTransitionEffect implements FocusTimerTransitionEffect {
  const _NoopFocusTimerTransitionEffect();

  @override
  Future<void> onRestStarted() async {}
}
