import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_timer_providers.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/models/timer_execution_draft.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_state.dart';

void main() {
  late FakeClock clock;
  late MemoryTimerStore store;
  late RecordingExecutionRecorder recorder;
  late RecordingTransitionEffect effect;
  late ProviderContainer container;
  late FocusTimerController controller;

  Future<void> initialize() async {
    container.read(focusTimerProvider);
    await Future<void>.delayed(Duration.zero);
    controller = container.read(focusTimerProvider.notifier);
  }

  FocusTimerState current() => container.read(focusTimerProvider);

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 8, 21));
    store = MemoryTimerStore();
    recorder = RecordingExecutionRecorder();
    effect = RecordingTransitionEffect();
    container = ProviderContainer(
      overrides: [
        focusTimerClockProvider.overrideWithValue(clock.call),
        activeFocusTimerStoreProvider.overrideWithValue(store),
        timerExecutionRecorderProvider.overrideWithValue(recorder),
        focusTimerTransitionEffectProvider.overrideWithValue(effect),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('starts and calculates focus elapsed time from timestamps', () async {
    await initialize();

    expect(
      await controller.start(
        focusAreaId: 4,
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
      ),
      isTrue,
    );
    clock.advance(const Duration(minutes: 7));
    await controller.synchronize();

    expect(current().status, FocusTimerStatus.running);
    expect(current().activeTimer!.phase, FocusTimerPhase.focus);
    expect(current().elapsedFocusTime, const Duration(minutes: 7));
    expect(current().phaseRemaining, const Duration(minutes: 18));
    expect(store.value, isNotNull);
  });

  test('automatically transitions to rest and emits its effect once', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 10),
      restDuration: const Duration(minutes: 5),
    );

    clock.advance(const Duration(minutes: 12));
    await controller.synchronize();
    await controller.synchronize();

    expect(current().activeTimer!.phase, FocusTimerPhase.rest);
    expect(current().elapsedFocusTime, const Duration(minutes: 10));
    expect(current().elapsedRestTime, const Duration(minutes: 2));
    expect(effect.calls, 1);
    expect(store.value!.focusTransitionNotified, isTrue);
  });

  test('pauses and resumes without counting paused time', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 20),
      restDuration: const Duration(minutes: 5),
    );
    clock.advance(const Duration(minutes: 3));

    expect(await controller.pause(), isTrue);
    expect(current().status, FocusTimerStatus.paused);
    clock.advance(const Duration(minutes: 30));
    await controller.synchronize();
    expect(current().elapsedFocusTime, const Duration(minutes: 3));

    expect(await controller.resume(), isTrue);
    clock.advance(const Duration(minutes: 2));
    await controller.synchronize();
    expect(current().elapsedFocusTime, const Duration(minutes: 5));
  });

  test('pause and resume also work during rest', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 1),
      restDuration: const Duration(minutes: 10),
    );
    clock.advance(const Duration(minutes: 3));
    await controller.synchronize();

    expect(await controller.pause(), isTrue);
    expect(current().elapsedRestTime, const Duration(minutes: 2));
    clock.advance(const Duration(hours: 1));
    expect(await controller.resume(), isTrue);
    clock.advance(const Duration(minutes: 1));
    await controller.synchronize();
    expect(current().elapsedRestTime, const Duration(minutes: 3));
  });

  test('natural completion persists and exposes completion state', () async {
    await initialize();
    await controller.start(
      focusAreaId: 8,
      focusDuration: const Duration(minutes: 2),
      restDuration: const Duration(minutes: 1),
    );
    final workDate = store.value!.workDate;
    clock.advance(const Duration(minutes: 3));

    await controller.synchronize();

    expect(current().status, FocusTimerStatus.completed);
    expect(store.value, isNull);
    expect(recorder.executions, hasLength(1));
    final execution = recorder.executions.single;
    expect(execution.focusAreaId, 8);
    expect(execution.focusedTime, const Duration(minutes: 2));
    expect(execution.restTime, const Duration(minutes: 1));
    expect(execution.workDate, workDate);
    expect(execution.endedAt, DateTime.utc(2026, 9, 8, 21, 3));

    controller.prepareNextExecution();
    expect(current().status, FocusTimerStatus.inactive);
  });

  test('partial reset requires pause and persists elapsed values', () async {
    await initialize();
    await controller.start(
      focusAreaId: 2,
      focusDuration: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 5),
    );
    expect(await controller.resetAndSavePartial(), isFalse);
    clock.advance(const Duration(minutes: 6));
    await controller.pause();

    expect(await controller.resetAndSavePartial(), isTrue);
    expect(recorder.executions.single.focusedTime, const Duration(minutes: 6));
    expect(recorder.executions.single.restTime, Duration.zero);
    expect(current().status, FocusTimerStatus.inactive);
  });

  test('discarded reset clears state without creating a record', () async {
    await initialize();
    await controller.start(
      focusAreaId: 2,
      focusDuration: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 5),
    );
    await controller.pause();

    expect(await controller.resetAndDiscard(), isTrue);
    expect(recorder.executions, isEmpty);
    expect(store.value, isNull);
    expect(current().status, FocusTimerStatus.inactive);
  });

  test('restores persisted running state and catches up from time', () async {
    store.value = ActiveFocusTimer(
      focusAreaId: 3,
      workDate: DateTime(2026, 9, 8),
      startedAt: clock().toUtc(),
      startedAtUtcOffset: const Duration(hours: 2),
      focusDuration: const Duration(minutes: 20),
      restDuration: const Duration(minutes: 5),
      phase: FocusTimerPhase.focus,
      activity: FocusTimerActivity.running,
      accumulatedFocusTime: Duration.zero,
      accumulatedRestTime: Duration.zero,
      runningSince: clock().toUtc(),
      focusTransitionNotified: false,
    );
    clock.advance(const Duration(minutes: 9));

    await initialize();

    expect(current().status, FocusTimerStatus.running);
    expect(current().elapsedFocusTime, const Duration(minutes: 9));
  });

  test('persistence failure exposes error and retains active state', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 1),
      restDuration: const Duration(minutes: 1),
    );
    recorder.error = StateError('offline');
    clock.advance(const Duration(minutes: 2));

    await controller.synchronize();

    expect(current().status, FocusTimerStatus.error);
    expect(current().activeTimer, isNotNull);
    expect(store.value, isNotNull);
  });
}

class FakeClock {
  FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
  void advance(Duration duration) => now = now.add(duration);
}

class MemoryTimerStore implements ActiveFocusTimerStore {
  ActiveFocusTimer? value;

  @override
  Future<ActiveFocusTimer?> load() async => value;
  @override
  Future<void> save(ActiveFocusTimer timer) async => value = timer;
  @override
  Future<void> clear() async => value = null;
}

class RecordingExecutionRecorder implements TimerExecutionRecorder {
  final executions = <TimerExecutionDraft>[];
  Object? error;

  @override
  Future<void> save(TimerExecutionDraft execution) async {
    if (error case final error?) throw error;
    executions.add(execution);
  }
}

class RecordingTransitionEffect implements FocusTimerTransitionEffect {
  int calls = 0;

  @override
  Future<void> onRestStarted() async => calls++;
}
