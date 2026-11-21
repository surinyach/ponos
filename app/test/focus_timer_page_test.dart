import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/providers/focus_timer_providers.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_controller.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_state.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/models/timer_execution_draft.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/timer_execution_repository.dart';
import 'package:ponos_app/features/focus_timer/presentation/focus_timer_page.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';
import 'package:ponos_app/features/work_entries/presentation/state/special_activities_controller.dart';
import 'package:ponos_app/features/work_entries/presentation/state/special_activities_state.dart';

void main() {
  late FakeClock clock;
  late MemoryTimerStore store;
  late RecordingExecutionRecorder recorder;
  late ProviderContainer container;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 9, 8, 8));
    store = MemoryTimerStore();
    recorder = RecordingExecutionRecorder();
    container = ProviderContainer(
      overrides: [
        focusAreasProvider.overrideWith(LoadedFocusAreasController.new),
        specialActivitiesProvider.overrideWith(
          LoadedSpecialActivitiesController.new,
        ),
        focusTimerClockProvider.overrideWithValue(clock.call),
        activeFocusTimerStoreProvider.overrideWithValue(store),
        timerExecutionRepositoryProvider.overrideWithValue(recorder),
        focusTimerNotificationSchedulerProvider.overrideWithValue(
          NoopNotificationScheduler(),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: size == null
                ? const FocusTimerPage()
                : PonosViewportScope(size: size, child: const FocusTimerPage()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('configures, starts, pauses, and discards an execution', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(500, 800));

    expect(find.byKey(const Key('focus-timer-compact')), findsOneWidget);
    expect(find.text('Work placement'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('Focus phase'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    expect(find.byKey(const Key('timer-reset')), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Save partial'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Session setup'), findsOneWidget);
    expect(recorder.executions, isEmpty);
  });

  testWidgets('saves a partial execution from the reset dialog', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    clock.advance(const Duration(minutes: 4));
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save partial'));
    await tester.pumpAndSettle();

    expect(recorder.executions.single.focusedTime, const Duration(minutes: 4));
    expect(find.text('Session setup'), findsOneWidget);
  });

  testWidgets('returns to setup after natural completion', (tester) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('timer-focus-minutes')));
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
    await tester.enterText(find.byKey(const Key('timer-rest-minutes')), '1');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();

    clock.advance(const Duration(minutes: 1, seconds: 5));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.text('Rest phase'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.byKey(const Key('active-timer')), findsNothing);
    expect(find.byKey(const Key('timer-remaining')), findsNothing);
    expect(find.text('Session setup'), findsOneWidget);
    expect(recorder.executions, hasLength(1));
  });

  testWidgets('uses the wide setup layout on web-sized screens', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1200, 800));
    expect(find.byKey(const Key('focus-timer-wide')), findsOneWidget);
    expect(find.byKey(const Key('focus-timer-compact')), findsNothing);
  });

  testWidgets('desktop content stays left aligned at its maximum width', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1600, 900));
    await tester.pump();
    final heading = tester.getRect(find.text('Focus timer'));
    final setup = tester.getRect(find.byKey(const Key('focus-timer-wide')));
    expect(heading.left, 40);
    expect(setup.left, heading.left);
    expect(setup.width, 1160);
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    final active = tester.getRect(find.byKey(const Key('active-timer')));
    expect(active.left, heading.left);
    expect(
      tester.getTopLeft(find.text('Session details')).dx,
      greaterThan(active.right),
    );
    expect(tester.takeException(), isNull);
    await container.read(focusTimerProvider.notifier).pause();
  });

  for (final size in [
    const Size(390, 844),
    const Size(500, 700),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('setup and active layout remain usable at $size', (
      tester,
    ) async {
      await pumpPage(tester, size: size);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('Session setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(find.text('Session details'), findsOneWidget);
      expect(find.text('FOCUS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(focusTimerProvider.notifier).pause();
    });
  }

  testWidgets('selects an active Special Activity and persists its execution', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(500, 800));
    await tester.ensureVisible(find.byKey(const Key('timer-focus-area')));
    await tester.tap(find.byKey(const Key('timer-focus-area')));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsNothing);
    await tester.tap(find.text('Release day').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(
      container.read(focusTimerProvider).activeTimer?.specialActivityId,
      4,
    );
    expect(container.read(focusTimerProvider).activeTimer?.focusAreaId, isNull);
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save partial'));
    await tester.pumpAndSettle();
    expect(recorder.executions.single.specialActivityId, 4);
    expect(recorder.executions.single.focusAreaId, isNull);
  });

  testWidgets('completes Special Activity focus and rest time naturally', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('timer-focus-area')));
    await tester.tap(find.byKey(const Key('timer-focus-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release day').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
    await tester.enterText(find.byKey(const Key('timer-rest-minutes')), '1');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    clock.advance(const Duration(minutes: 1, seconds: 5));
    await container.read(focusTimerProvider.notifier).synchronize();
    clock.advance(const Duration(minutes: 1));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();

    expect(recorder.executions.single.specialActivityId, 4);
    expect(recorder.executions.single.focusedTime, const Duration(minutes: 1));
    expect(recorder.executions.single.restTime, const Duration(minutes: 1));
    expect(find.text('Session setup'), findsOneWidget);
  });
}

class LoadedSpecialActivitiesController extends SpecialActivitiesController {
  @override
  SpecialActivitiesState build() => SpecialActivitiesState(
    status: SpecialActivitiesStatus.loaded,
    active: [const SpecialActivity(id: 4, name: 'Release day')],
  );
}

class LoadedFocusAreasController extends FocusAreasController {
  @override
  FocusAreasState build() => FocusAreasState(
    status: FocusAreasStatus.loaded,
    areas: [
      FocusArea(
        id: 1,
        name: 'Work placement',
        priority: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        targets: const [],
      ),
    ],
  );
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
  @override
  Future<void> save(TimerExecutionDraft execution) async {
    executions.add(execution);
  }
}

class NoopNotificationScheduler implements FocusTimerNotificationScheduler {
  @override
  Future<void> cancel(FocusTimerAlert alert) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> schedule(FocusTimerAlert alert, DateTime scheduledAt) async {}
}
