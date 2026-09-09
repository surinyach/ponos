import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/focus_timer/data/remote_timer_execution_repository.dart';
import '../../features/focus_timer/data/shared_preferences_focus_timer_store.dart';
import '../../features/focus_timer/data/timer_execution_api_client.dart';
import '../../features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import '../../features/focus_timer/domain/repositories/timer_execution_repository.dart';
import 'focus_area_providers.dart';

final focusTimerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final activeFocusTimerStoreProvider = Provider<ActiveFocusTimerStore>(
  (ref) => SharedPreferencesFocusTimerStore(SharedPreferencesAsync()),
);

final timerExecutionRepositoryProvider = Provider<TimerExecutionRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RemoteTimerExecutionRepository(
    TimerExecutionApiClient(client, ref.watch(apiConfigProvider)),
  );
});

final focusTimerTransitionEffectProvider = Provider<FocusTimerTransitionEffect>(
  (ref) => const _NoopFocusTimerTransitionEffect(),
);

class _NoopFocusTimerTransitionEffect implements FocusTimerTransitionEffect {
  const _NoopFocusTimerTransitionEffect();

  @override
  Future<void> onRestStarted() async {}
}
