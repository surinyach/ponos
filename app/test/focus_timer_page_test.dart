import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        focusTimerClockProvider.overrideWithValue(clock.call),
        activeFocusTimerStoreProvider.overrideWithValue(store),
        timerExecutionRepositoryProvider.overrideWithValue(recorder),
        focusTimerTransitionEffectProvider.overrideWithValue(NoopEffect()),
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
        child: const MaterialApp(home: Scaffold(body: FocusTimerPage())),
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
    expect(find.text('New execution'), findsOneWidget);
    expect(recorder.executions, isEmpty);
  });

  testWidgets('saves a partial execution from the reset dialog', (
    tester,
  ) async {
    await pumpPage(tester);
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
    expect(find.text('New execution'), findsOneWidget);
  });

  testWidgets('shows rest and natural completion states', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
    await tester.enterText(find.byKey(const Key('timer-rest-minutes')), '1');
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();

    clock.advance(const Duration(minutes: 1));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.text('Rest phase'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.byKey(const Key('active-timer')), findsNothing);
    expect(find.byKey(const Key('timer-remaining')), findsNothing);
    expect(find.text('Execution complete'), findsOneWidget);
    expect(recorder.executions, hasLength(1));
  });

  testWidgets('uses the wide setup layout on web-sized screens', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1200, 800));
    expect(find.byKey(const Key('focus-timer-wide')), findsOneWidget);
    expect(find.byKey(const Key('focus-timer-compact')), findsNothing);
  });
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

class NoopEffect implements FocusTimerTransitionEffect {
  @override
  Future<void> onRestStarted() async {}
}
