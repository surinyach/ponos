import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_timer_providers.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/models/timer_execution_draft.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/timer_execution_repository.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_state.dart';

void main() {
  late FakeClock clock;
  late MemoryTimerStore store;
  late RecordingExecutionRecorder recorder;
  late RecordingNotificationScheduler notifications;
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
    notifications = RecordingNotificationScheduler();
    container = ProviderContainer(
      overrides: [
        focusTimerClockProvider.overrideWithValue(clock.call),
        activeFocusTimerStoreProvider.overrideWithValue(store),
        timerExecutionRepositoryProvider.overrideWithValue(recorder),
        focusTimerNotificationSchedulerProvider.overrideWithValue(
          notifications,
        ),
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
    expect(notifications.permissionRequests, 1);
    expect(notifications.cancelAllCalls, 1);
    expect(notifications.scheduled.single.alert, FocusTimerAlert.focusComplete);
    expect(notifications.scheduled.single.at, DateTime.utc(2026, 9, 8, 21, 25));
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
    expect(current().elapsedRestTime, const Duration(minutes: 1, seconds: 55));
    expect(
      notifications.scheduled.where(
        (entry) => entry.alert == FocusTimerAlert.restComplete,
      ),
      hasLength(1),
    );
    expect(store.value!.focusTransitionNotified, isTrue);
    expect(
      notifications.scheduled.last.at,
      DateTime.utc(2026, 9, 8, 21, 15, 5),
    );
  });

  test('waits five seconds before consuming rest time', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 1),
      restDuration: const Duration(minutes: 5),
    );

    clock.advance(const Duration(minutes: 1, seconds: 4));
    await controller.synchronize();
    expect(current().activeTimer!.phase, FocusTimerPhase.rest);
    expect(current().elapsedRestTime, Duration.zero);

    clock.advance(const Duration(seconds: 2));
    await controller.synchronize();
    expect(current().elapsedRestTime, const Duration(seconds: 1));
  });

  test('preserves the transition delay across pause and resume', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 1),
      restDuration: const Duration(minutes: 5),
    );
    clock.advance(const Duration(minutes: 1, seconds: 2));
    await controller.pause();

    expect(
      current().activeTimer!.restStartDelayRemaining,
      const Duration(seconds: 3),
    );
    clock.advance(const Duration(minutes: 10));
    await controller.resume();
    clock.advance(const Duration(seconds: 2));
    await controller.synchronize();
    expect(current().elapsedRestTime, Duration.zero);

    clock.advance(const Duration(seconds: 2));
    await controller.synchronize();
    expect(current().elapsedRestTime, const Duration(seconds: 1));
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
    expect(notifications.cancelled.last, FocusTimerAlert.focusComplete);
    clock.advance(const Duration(minutes: 30));
    await controller.synchronize();
    expect(current().elapsedFocusTime, const Duration(minutes: 3));

    expect(await controller.resume(), isTrue);
    expect(notifications.scheduled.last.alert, FocusTimerAlert.focusComplete);
    expect(notifications.scheduled.last.at, DateTime.utc(2026, 9, 8, 21, 50));
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
    clock.advance(const Duration(minutes: 3, seconds: 5));
    await controller.synchronize();

    expect(await controller.pause(), isTrue);
    expect(current().elapsedRestTime, const Duration(minutes: 2));
    clock.advance(const Duration(hours: 1));
    expect(await controller.resume(), isTrue);
    clock.advance(const Duration(minutes: 1));
    await controller.synchronize();
    expect(current().elapsedRestTime, const Duration(minutes: 3));
  });

  test('natural completion persists and resets to inactive', () async {
    await initialize();
    await controller.start(
      focusAreaId: 8,
      focusDuration: const Duration(minutes: 2),
      restDuration: const Duration(minutes: 1),
    );
    final workDate = store.value!.workDate;
    clock.advance(const Duration(minutes: 3, seconds: 5));

    await controller.synchronize();

    expect(current().status, FocusTimerStatus.inactive);
    expect(store.value, isNull);
    expect(recorder.executions, hasLength(1));
    final execution = recorder.executions.single;
    expect(execution.focusAreaId, 8);
    expect(execution.focusedTime, const Duration(minutes: 2));
    expect(execution.restTime, const Duration(minutes: 1));
    expect(execution.workDate, workDate);
    expect(execution.endedAt, DateTime.utc(2026, 9, 8, 21, 3, 5));
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
    expect(notifications.cancelAllCalls, 2);
  });

  test('failed partial save retains paused state and can be retried', () async {
    await initialize();
    await controller.start(
      focusAreaId: 2,
      focusDuration: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 5),
    );
    clock.advance(const Duration(minutes: 4));
    await controller.pause();
    recorder.error = StateError('offline');

    expect(await controller.resetAndSavePartial(), isFalse);
    expect(current().status, FocusTimerStatus.error);
    expect(current().activeTimer!.isPaused, isTrue);
    expect(current().elapsedFocusTime, const Duration(minutes: 4));
    expect(store.value, isNotNull);
    expect(recorder.executions, isEmpty);

    recorder.error = null;
    expect(await controller.resetAndSavePartial(), isTrue);
    expect(recorder.executions.single.focusedTime, const Duration(minutes: 4));
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
    expect(notifications.cancelAllCalls, 2);
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
    expect(notifications.permissionRequests, 0);
    expect(notifications.scheduled.single.at, DateTime.utc(2026, 9, 8, 21, 20));
  });

  test('persistence failure exposes error and retains active state', () async {
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 1),
      restDuration: const Duration(minutes: 1),
    );
    recorder.error = StateError('offline');
    clock.advance(const Duration(minutes: 2, seconds: 5));

    await controller.synchronize();

    expect(current().status, FocusTimerStatus.error);
    expect(current().activeTimer, isNotNull);
    expect(store.value, isNotNull);
  });

  test(
    'retries a failed natural completion without losing the cycle',
    () async {
      await initialize();
      await controller.start(
        focusAreaId: 1,
        focusDuration: const Duration(minutes: 1),
        restDuration: const Duration(minutes: 1),
      );
      recorder.error = StateError('offline');
      clock.advance(const Duration(minutes: 2, seconds: 5));
      await controller.synchronize();

      recorder.error = null;
      await controller.synchronize();

      expect(current().status, FocusTimerStatus.inactive);
      expect(recorder.executions, hasLength(1));
      expect(store.value, isNull);
    },
  );

  test(
    'restores and persists a cycle completed while the app was closed',
    () async {
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
      clock.advance(const Duration(minutes: 25, seconds: 5));

      await initialize();

      expect(current().status, FocusTimerStatus.inactive);
      expect(recorder.executions, hasLength(1));
      expect(
        recorder.executions.single.focusedTime,
        const Duration(minutes: 20),
      );
      expect(recorder.executions.single.restTime, const Duration(minutes: 5));
    },
  );

  test(
    'rest pause cancels and resume reschedules its completion alert',
    () async {
      await initialize();
      await controller.start(
        focusAreaId: 1,
        focusDuration: const Duration(minutes: 1),
        restDuration: const Duration(minutes: 5),
      );
      clock.advance(const Duration(minutes: 2, seconds: 5));
      await controller.synchronize();

      await controller.pause();
      expect(notifications.cancelled.last, FocusTimerAlert.restComplete);
      await controller.resume();
      expect(notifications.scheduled.last.alert, FocusTimerAlert.restComplete);
      expect(
        notifications.scheduled.last.at,
        DateTime.utc(2026, 9, 8, 21, 6, 5),
      );
    },
  );

  test('midnight crossing retains the local start work date', () async {
    clock.now = DateTime(2026, 9, 8, 23, 59);
    await initialize();
    await controller.start(
      focusAreaId: 1,
      focusDuration: const Duration(minutes: 3),
      restDuration: const Duration(minutes: 2),
    );
    clock.advance(const Duration(minutes: 5, seconds: 5));

    await controller.synchronize();

    expect(recorder.executions.single.workDate, DateTime(2026, 9, 8));
    expect(recorder.executions.single.endedAt.toLocal().day, 9);
  });

  test('supports consecutive executions with different Focus Areas', () async {
    await initialize();
    for (final focusAreaId in [1, 2]) {
      expect(
        await controller.start(
          focusAreaId: focusAreaId,
          focusDuration: const Duration(minutes: 1),
          restDuration: const Duration(minutes: 1),
        ),
        isTrue,
      );
      clock.advance(const Duration(minutes: 2, seconds: 5));
      await controller.synchronize();
    }

    expect(recorder.executions.map((execution) => execution.focusAreaId), [
      1,
      2,
    ]);
    expect(current().status, FocusTimerStatus.inactive);
  });

  test('notification failure does not corrupt timer state', () async {
    await initialize();
    notifications.error = StateError('notifications unavailable');

    expect(
      await controller.start(
        focusAreaId: 1,
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
      ),
      isTrue,
    );

    expect(current().status, FocusTimerStatus.running);
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

class RecordingExecutionRecorder implements TimerExecutionRepository {
  final executions = <TimerExecutionDraft>[];
  Object? error;

  @override
  Future<void> save(TimerExecutionDraft execution) async {
    if (error case final error?) throw error;
    executions.add(execution);
  }
}

class ScheduledAlert {
  const ScheduledAlert(this.alert, this.at);
  final FocusTimerAlert alert;
  final DateTime at;
}

class RecordingNotificationScheduler
    implements FocusTimerNotificationScheduler {
  final scheduled = <ScheduledAlert>[];
  final cancelled = <FocusTimerAlert>[];
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  Object? error;

  @override
  Future<void> requestPermissions() async {
    permissionRequests++;
    if (error case final error?) throw error;
  }

  @override
  Future<void> schedule(FocusTimerAlert alert, DateTime scheduledAt) async {
    if (error case final error?) throw error;
    scheduled.add(ScheduledAlert(alert, scheduledAt));
  }

  @override
  Future<void> cancel(FocusTimerAlert alert) async {
    if (error case final error?) throw error;
    cancelled.add(alert);
  }

  @override
  Future<void> cancelAll() async {
    if (error case final error?) throw error;
    cancelAllCalls++;
  }
}
