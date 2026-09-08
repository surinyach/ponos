import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/focus_timer_providers.dart';
import '../../domain/models/active_focus_timer.dart';
import '../../domain/models/timer_execution_draft.dart';
import '../../domain/repositories/focus_timer_gateways.dart';
import 'focus_timer_state.dart';

final focusTimerProvider =
    NotifierProvider<FocusTimerController, FocusTimerState>(
      FocusTimerController.new,
    );

class FocusTimerController extends Notifier<FocusTimerState> {
  late ActiveFocusTimerStore _store;
  late TimerExecutionRecorder _recorder;
  late FocusTimerTransitionEffect _transitionEffect;
  late DateTime Function() _clock;
  Timer? _ticker;
  bool _busy = false;

  @override
  FocusTimerState build() {
    _store = ref.watch(activeFocusTimerStoreProvider);
    _recorder = ref.watch(timerExecutionRecorderProvider);
    _transitionEffect = ref.watch(focusTimerTransitionEffectProvider);
    _clock = ref.watch(focusTimerClockProvider);
    ref.onDispose(() => _ticker?.cancel());
    Future<void>.microtask(_restore);
    return const FocusTimerState.restoring();
  }

  Future<bool> start({
    required int focusAreaId,
    required Duration focusDuration,
    required Duration restDuration,
  }) async {
    if (state.status != FocusTimerStatus.inactive ||
        focusAreaId <= 0 ||
        focusDuration <= Duration.zero ||
        restDuration <= Duration.zero) {
      return false;
    }
    final localNow = _clock().toLocal();
    final now = localNow.toUtc();
    final timer = ActiveFocusTimer(
      focusAreaId: focusAreaId,
      workDate: DateTime(localNow.year, localNow.month, localNow.day),
      startedAt: now,
      focusDuration: focusDuration,
      restDuration: restDuration,
      phase: FocusTimerPhase.focus,
      activity: FocusTimerActivity.running,
      accumulatedFocusTime: Duration.zero,
      accumulatedRestTime: Duration.zero,
      runningSince: now,
      focusTransitionNotified: false,
    );
    return _replace(timer);
  }

  Future<bool> pause() async {
    final timer = state.activeTimer;
    if (timer == null || timer.activity != FocusTimerActivity.running) {
      return false;
    }
    await synchronize();
    final current = state.activeTimer;
    if (current == null || current.activity != FocusTimerActivity.running) {
      return false;
    }
    final now = _clock().toUtc();
    final elapsed = _runningElapsed(current, now);
    final paused = current.copyWith(
      activity: FocusTimerActivity.paused,
      accumulatedFocusTime: current.phase == FocusTimerPhase.focus
          ? elapsed
          : current.accumulatedFocusTime,
      accumulatedRestTime: current.phase == FocusTimerPhase.rest
          ? elapsed
          : current.accumulatedRestTime,
      clearRunningSince: true,
    );
    return _replace(paused);
  }

  Future<bool> resume() async {
    final timer = state.activeTimer;
    if (timer == null || !timer.isPaused) return false;
    return _replace(
      timer.copyWith(
        activity: FocusTimerActivity.running,
        runningSince: _clock().toUtc(),
      ),
    );
  }

  Future<bool> resetAndSavePartial() async {
    final timer = state.activeTimer;
    if (timer == null || !timer.isPaused) return false;
    state = _snapshot(timer, status: FocusTimerStatus.persisting);
    try {
      await _recorder.save(_draft(timer, _clock().toUtc()));
      await _store.clear();
      _setInactive();
      return true;
    } catch (error) {
      _setError(timer, error);
      return false;
    }
  }

  Future<bool> resetAndDiscard() async {
    final timer = state.activeTimer;
    if (timer == null || !timer.isPaused) return false;
    try {
      await _store.clear();
      _setInactive();
      return true;
    } catch (error) {
      _setError(timer, error);
      return false;
    }
  }

  /// Reconciles state against an absolute timestamp. Periodic ticks only
  /// refresh exposure; correctness does not depend on their frequency.
  Future<void> synchronize() async {
    if (_busy) return;
    final timer = state.activeTimer;
    if (timer == null || timer.isPaused) return;
    _busy = true;
    try {
      await _advance(timer, _clock().toUtc());
    } finally {
      _busy = false;
    }
  }

  Future<void> _restore() async {
    try {
      final timer = await _store.load();
      if (!ref.mounted) return;
      if (timer == null) {
        _setInactive();
      } else {
        _publish(timer);
        if (!timer.isPaused) await synchronize();
      }
    } catch (error) {
      if (ref.mounted) {
        state = FocusTimerState(status: FocusTimerStatus.error, error: error);
      }
    }
  }

  Future<void> _advance(ActiveFocusTimer timer, DateTime now) async {
    if (timer.phase == FocusTimerPhase.focus) {
      final elapsed = _runningElapsed(timer, now);
      if (elapsed < timer.focusDuration) {
        _publish(timer, focusElapsed: elapsed);
        return;
      }

      final transitionAt = timer.runningSince!.add(
        timer.focusDuration - timer.accumulatedFocusTime,
      );
      final restTimer = timer.copyWith(
        phase: FocusTimerPhase.rest,
        accumulatedFocusTime: timer.focusDuration,
        runningSince: transitionAt,
        focusTransitionNotified: timer.focusTransitionNotified,
      );
      try {
        await _store.save(restTimer);
        _publish(restTimer);
        final notifiedTimer = await _ensureRestEffect(restTimer);
        await _advanceRest(notifiedTimer, now);
      } catch (error) {
        _setError(restTimer, error);
      }
      return;
    }
    try {
      await _advanceRest(await _ensureRestEffect(timer), now);
    } catch (error) {
      _setError(timer, error);
    }
  }

  Future<ActiveFocusTimer> _ensureRestEffect(ActiveFocusTimer timer) async {
    if (timer.focusTransitionNotified) return timer;
    await _transitionEffect.onRestStarted();
    final notified = timer.copyWith(focusTransitionNotified: true);
    await _store.save(notified);
    _publish(notified);
    return notified;
  }

  Future<void> _advanceRest(ActiveFocusTimer timer, DateTime now) async {
    final elapsed = _runningElapsed(timer, now);
    if (elapsed < timer.restDuration) {
      _publish(timer, restElapsed: elapsed);
      return;
    }
    final endedAt = timer.runningSince!.add(
      timer.restDuration - timer.accumulatedRestTime,
    );
    final completed = timer.copyWith(accumulatedRestTime: timer.restDuration);
    state = _snapshot(completed, status: FocusTimerStatus.persisting);
    try {
      await _recorder.save(_draft(completed, endedAt));
      await _store.clear();
      _setInactive();
    } catch (error) {
      _ticker?.cancel();
      _setError(completed, error);
    }
  }

  Future<bool> _replace(ActiveFocusTimer timer) async {
    try {
      await _store.save(timer);
      if (!ref.mounted) return false;
      _publish(timer);
      return true;
    } catch (error) {
      if (ref.mounted) _setError(state.activeTimer, error);
      return false;
    }
  }

  Duration _runningElapsed(ActiveFocusTimer timer, DateTime now) {
    final accumulated = timer.phase == FocusTimerPhase.focus
        ? timer.accumulatedFocusTime
        : timer.accumulatedRestTime;
    final delta = now.difference(timer.runningSince!);
    return accumulated + (delta.isNegative ? Duration.zero : delta);
  }

  TimerExecutionDraft _draft(ActiveFocusTimer timer, DateTime endedAt) =>
      TimerExecutionDraft(
        focusAreaId: timer.focusAreaId,
        workDate: timer.workDate,
        startedAt: timer.startedAt,
        endedAt: endedAt,
        focusedTime: timer.accumulatedFocusTime,
        restTime: timer.accumulatedRestTime,
      );

  void _publish(
    ActiveFocusTimer timer, {
    Duration? focusElapsed,
    Duration? restElapsed,
  }) {
    if (!ref.mounted) return;
    state = FocusTimerState(
      status: timer.isPaused
          ? FocusTimerStatus.paused
          : FocusTimerStatus.running,
      activeTimer: timer,
      elapsedFocusTime: focusElapsed ?? timer.accumulatedFocusTime,
      elapsedRestTime: restElapsed ?? timer.accumulatedRestTime,
    );
    _configureTicker(timer);
  }

  FocusTimerState _snapshot(
    ActiveFocusTimer timer, {
    required FocusTimerStatus status,
    Object? error,
  }) => FocusTimerState(
    status: status,
    activeTimer: timer,
    elapsedFocusTime: timer.accumulatedFocusTime,
    elapsedRestTime: timer.accumulatedRestTime,
    error: error,
  );

  void _setError(ActiveFocusTimer? timer, Object error) {
    _ticker?.cancel();
    _ticker = null;
    state = timer == null
        ? FocusTimerState(status: FocusTimerStatus.error, error: error)
        : _snapshot(timer, status: FocusTimerStatus.error, error: error);
  }

  void _setInactive() {
    _ticker?.cancel();
    _ticker = null;
    state = const FocusTimerState.inactive();
  }

  void _configureTicker(ActiveFocusTimer timer) {
    _ticker?.cancel();
    _ticker = null;
    if (!timer.isPaused) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(synchronize()),
      );
    }
  }
}
