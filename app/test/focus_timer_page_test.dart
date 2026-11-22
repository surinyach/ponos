import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/navigation/ponos_destination.dart';
import 'package:ponos_app/app/providers/focus_timer_providers.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_controller.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_state.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/models/timer_execution_draft.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/timer_execution_repository.dart';
import 'package:ponos_app/features/focus_timer/presentation/focus_timer_page.dart';
import 'package:ponos_app/features/focus_timer/presentation/timer_laurel.dart';
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

  testWidgets('restoring shows progress and restores a paused execution', (
    tester,
  ) async {
    store.pendingLoad = Completer<ActiveFocusTimer?>();
    await pumpPage(tester, size: const Size(390, 844));
    expect(find.text('Restoring timer'), findsOneWidget);
    expect(find.byKey(const Key('timer-start')), findsNothing);
    store.pendingLoad!.complete(
      ActiveFocusTimer(
        focusAreaId: 1,
        workDate: DateTime(2026, 9, 8),
        startedAt: DateTime.utc(2026, 9, 8, 8),
        startedAtUtcOffset: Duration.zero,
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
        phase: FocusTimerPhase.rest,
        activity: FocusTimerActivity.paused,
        accumulatedFocusTime: const Duration(minutes: 25),
        accumulatedRestTime: const Duration(minutes: 2),
        focusTransitionNotified: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('REST'), findsOneWidget);
    expect(find.text('Rest · Paused'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(find.byKey(const Key('timer-resume')), findsOneWidget);
    expect(find.text('Timer restored.'), findsOneWidget);
  });

  testWidgets('restoration failure exposes retry and recovers', (tester) async {
    store.pendingLoad = Completer<ActiveFocusTimer?>();
    await pumpPage(tester);
    expect(find.text('Restoring timer'), findsOneWidget);
    store.pendingLoad!.completeError(StateError('unavailable'));
    await tester.pump();
    expect(find.text('Unable to restore the timer'), findsOneWidget);
    store.pendingLoad = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('configures, starts, pauses, and discards an execution', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(500, 800));

    expect(find.byKey(const Key('timer-focus-area')), findsOneWidget);
    expect(find.text('Work placement'), findsOneWidget);

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
    expect(find.byKey(const Key('timer-focus-area')), findsOneWidget);
    expect(recorder.executions, isEmpty);
  });

  testWidgets('mobile inline configuration validates before starting', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '0');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('Focus must be at least 1 minute.'), findsOneWidget);
    expect(find.byKey(const Key('active-timer')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('timer-focus-minutes')));
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '15');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('15:00'), findsOneWidget);
    expect(find.textContaining('Focus · 15 min'), findsOneWidget);
    await container.read(focusTimerProvider.notifier).pause();
  });

  testWidgets('duration errors identify the invalid fields independently', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    final focus = find.byKey(const Key('timer-focus-minutes'));
    final rest = find.byKey(const Key('timer-rest-minutes'));
    String? errorFor(Finder field) => tester
        .widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        )
        .decoration
        ?.errorText;
    await tester.enterText(focus, '0');
    await tester.enterText(rest, 'not a number');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(errorFor(focus), 'Focus must be at least 1 minute.');
    expect(errorFor(rest), 'Rest must be 0 minutes or more.');
    await tester.ensureVisible(focus);
    await tester.enterText(focus, '10');
    await tester.pump();
    expect(errorFor(focus), isNull);
    expect(errorFor(rest), isNotNull);
    await tester.enterText(rest, '5');
    await tester.pump();
    expect(errorFor(rest), isNull);
  });

  testWidgets('zero rest displays No rest and remains editable', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    final rest = find.byKey(const Key('timer-rest-minutes'));
    await tester.enterText(rest, '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('No rest'), findsOneWidget);
    await tester.tap(rest);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.enterText(rest, '5');
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('focus-only configuration and completion at $size', (
      tester,
    ) async {
      await pumpPage(tester, size: size);
      await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
      await tester.enterText(find.byKey(const Key('timer-rest-minutes')), '0');
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(find.textContaining('No rest'), findsWidgets);
      expect(find.text('REST'), findsNothing);
      clock.advance(const Duration(minutes: 1));
      await container.read(focusTimerProvider.notifier).synchronize();
      await tester.pump();
      expect(find.text('REST'), findsNothing);
      expect(
        recorder.executions.single.focusedTime,
        const Duration(minutes: 1),
      );
      expect(recorder.executions.single.restTime, Duration.zero);
      expect(find.text('No rest'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.text('Partial execution saved.'), findsOneWidget);
  });

  testWidgets('reset cancel leaves the paused timer intact', (tester) async {
    await pumpPage(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.byKey(const Key('timer-reset')), findsNothing);
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save partial records'), findsOneWidget);
    expect(find.textContaining('Discard resets'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timer-resume')), findsOneWidget);
    expect(container.read(focusTimerProvider).activeTimer?.isPaused, isTrue);
    expect(recorder.executions, isEmpty);
  });

  testWidgets('partial save displays progress and retains timer on failure', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    recorder.pending = Completer<void>();
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save partial'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Saving execution…'), findsOneWidget);
    expect(find.text('Focus · Saving'), findsOneWidget);
    expect(find.byKey(const Key('timer-resume')), findsNothing);
    recorder.pending!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('timer-resume')), findsOneWidget);
    expect(find.text('Focus · Error'), findsOneWidget);
    expect(find.text('Your timer is still available.'), findsOneWidget);
    expect(container.read(focusTimerProvider).activeTimer?.isPaused, isTrue);
    expect(recorder.executions, isEmpty);
    recorder.pending = null;
    await tester.ensureVisible(find.byKey(const Key('timer-reset')));
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save partial'));
    await tester.pumpAndSettle();
    expect(recorder.executions, hasLength(1));
    expect(find.text('Partial execution saved.'), findsOneWidget);
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
    expect(find.text('Focus complete'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.byKey(const Key('active-timer')), findsNothing);
    expect(find.byKey(const Key('timer-remaining')), findsNothing);
    expect(find.text('Session setup'), findsOneWidget);
    expect(recorder.executions, hasLength(1));
    await tester.pump();
    expect(find.text('Focus cycle completed and saved.'), findsOneWidget);
  });

  testWidgets('laurel follows each phase and remains still while paused', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    TimerLaurelPainter painter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('timer-laurel')))
                .painter!
            as TimerLaurelPainter;
    expect(painter().progress, 0);
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('Focus phase'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.byKey(const Key('timer-phase-transition')),
          )
          .duration,
      const Duration(milliseconds: 180),
    );
    clock.advance(const Duration(minutes: 10));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(painter().progress, closeTo(.4, .001));
    expect(painter().isRest, isFalse);
    expect(find.text('15:00'), findsOneWidget);
    await container.read(focusTimerProvider.notifier).pause();
    clock.advance(const Duration(minutes: 3));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(painter().progress, closeTo(.4, .001));
    expect(find.text('Focus · Paused'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    await container.read(focusTimerProvider.notifier).resume();
    clock.advance(const Duration(minutes: 15, seconds: 5));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(painter().isRest, isTrue);
    expect(painter().progress, closeTo(0, .001));
    expect(find.text('Rest phase'), findsOneWidget);
    expect(find.text('Focus complete'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    await container.read(focusTimerProvider.notifier).pause();
  });

  testWidgets('laurel supports reduced motion and enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const Scaffold(body: FocusTimerPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('timer-laurel')), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('timer-focus-area')));
    await tester.tap(find.byKey(const Key('timer-focus-area')));
    await tester.pumpAndSettle();
    expect(find.text('FOCUS AREAS'), findsOneWidget);
    expect(find.text('SPECIAL ACTIVITIES'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('timer-option-special-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('timer-focus-minutes')));
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '20');
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('FOCUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.byKey(const Key('timer-phase-transition')),
          )
          .duration,
      Duration.zero,
    );
    await container.read(focusTimerProvider.notifier).pause();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('timer-reset')));
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Save partial'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('desktop laurel remains usable with 200 percent text', (
    tester,
  ) async {
    const size = Size(1440, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: PonosViewportScope(size: size, child: FocusTimerPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('timer-laurel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(find.text('FOCUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await container.read(focusTimerProvider.notifier).pause();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('timer-reset')));
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Save partial'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('small mobile viewport allows enlarged content to scroll', (
    tester,
  ) async {
    const size = Size(320, 568);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(2),
            ),
            child: PonosAdaptiveShell(
              selectedDestination: PonosDestination.focus,
              onDestinationSelected: (_) {},
              destinationBuilder: (_) => const FocusTimerPage(),
              appBar: AppBar(toolbarHeight: 64, title: const Text('Ponos')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await container.read(focusTimerProvider.notifier).pause();
  });

  testWidgets('rest reset dialog remains usable at 200 percent text', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: Scaffold(body: FocusTimerPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('timer-focus-minutes')));
    await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
    await tester.ensureVisible(find.byKey(const Key('timer-start')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    clock.advance(const Duration(minutes: 1, seconds: 5));
    await container.read(focusTimerProvider.notifier).synchronize();
    await tester.pump();
    expect(find.text('REST'), findsOneWidget);
    expect(find.byKey(const Key('timer-reset')), findsNothing);
    await container.read(focusTimerProvider.notifier).pause();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('timer-reset')));
    await tester.tap(find.byKey(const Key('timer-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Save partial'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timer-resume')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('timer controls support keyboard focus and activation', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1440, 900));
    final start = find.byKey(const Key('timer-start'));
    await tester.ensureVisible(start);
    final focusNode = Focus.of(tester.element(find.text('Start focus')));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final button = tester.widget<FilledButton>(
      find.descendant(of: start, matching: find.byType(FilledButton)),
    );
    expect(
      button.style!.side!.resolve({WidgetState.focused})!.color,
      AppColors.accent,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byKey(const Key('timer-pause')), findsOneWidget);
    await container.read(focusTimerProvider.notifier).pause();
  });

  test('timer text and primary controls meet light-theme contrast', () {
    double contrast(Color a, Color b) {
      final light = a.computeLuminance();
      final dark = b.computeLuminance();
      return light > dark
          ? (light + .05) / (dark + .05)
          : (dark + .05) / (light + .05);
    }

    expect(
      contrast(AppColors.primaryDark, AppColors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.primary, AppColors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.textSecondary, AppColors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(AppTheme.light.brightness, Brightness.light);
  });

  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(320, 568),
    const Size(844, 390),
    const Size(800, 360),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'timer remains accessible at $size and ${scale * 100}% text',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.light.copyWith(
                  platform: TargetPlatform.android,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  // The expanded shell's branding overflows at enlarged text;
                  // isolate the timer while preserving its available width.
                  child: size.width == 1440 && scale > 1
                      ? const Scaffold(
                          body: Padding(
                            padding: EdgeInsets.only(left: 200),
                            child: FocusTimerPage(),
                          ),
                        )
                      : PonosAdaptiveShell(
                          selectedDestination: PonosDestination.focus,
                          onDestinationSelected: (_) {},
                          destinationBuilder: (_) => const FocusTimerPage(),
                          appBar: AppBar(
                            toolbarHeight: 64,
                            title: const Text('Ponos'),
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          for (final key in [
            'timer-focus-area',
            'timer-focus-minutes',
            'timer-rest-minutes',
            'timer-start',
          ]) {
            await tester.ensureVisible(find.byKey(Key(key)));
            await tester.pump();
            final target = tester.getSize(find.byKey(Key(key)));
            expect(
              target.width,
              greaterThanOrEqualTo(48),
              reason: '$key at $size / $scale',
            );
            expect(
              target.height,
              greaterThanOrEqualTo(48),
              reason: '$key at $size / $scale',
            );
          }
          await tester.ensureVisible(
            find.byKey(const Key('timer-focus-minutes')),
          );
          await tester.enterText(
            find.byKey(const Key('timer-focus-minutes')),
            '1',
          );
          await tester.ensureVisible(
            find.byKey(const Key('timer-rest-minutes')),
          );
          await tester.enterText(
            find.byKey(const Key('timer-rest-minutes')),
            '1',
          );
          await tester.ensureVisible(find.byKey(const Key('timer-start')));
          await tester.tap(find.byKey(const Key('timer-start')));
          await tester.pump();
          expect(find.text('FOCUS'), findsOneWidget);
          final countdown = tester.widget<Semantics>(
            find.byKey(const Key('timer-countdown-semantics')),
          );
          expect(countdown.properties.liveRegion, isFalse);
          expect(countdown.properties.label, contains('FOCUS time remaining'));
          expect(
            find.ancestor(
              of: find.byKey(const Key('timer-laurel')),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
          await container.read(focusTimerProvider.notifier).pause();
          await tester.pump();
          await tester.ensureVisible(find.byKey(const Key('timer-reset')));
          expect(
            tester.getSize(find.byKey(const Key('timer-reset'))).height,
            greaterThanOrEqualTo(48),
          );
          expect(find.text('Paused'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await container.read(focusTimerProvider.notifier).resume();
          clock.advance(const Duration(minutes: 1, seconds: 5));
          await container.read(focusTimerProvider.notifier).synchronize();
          await tester.pump();
          expect(find.text('REST'), findsOneWidget);
          expect(tester.takeException(), isNull);
          clock.advance(const Duration(minutes: 1));
          await container.read(focusTimerProvider.notifier).synchronize();
          await tester.pump();
          expect(find.text('READY'), findsOneWidget);
          expect(recorder.executions, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
      if (size.width >= 600) {
        expect(find.text('Session details'), findsOneWidget);
      }
      expect(find.text('FOCUS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(focusTimerProvider.notifier).pause();
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(320, 568),
  ]) {
    testWidgets('mobile shell keeps timer controls reachable at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: PonosAdaptiveShell(
              selectedDestination: PonosDestination.focus,
              onDestinationSelected: (_) {},
              destinationBuilder: (_) => const FocusTimerPage(),
              appBar: AppBar(toolbarHeight: 64, title: const Text('Ponos')),
            ),
          ),
        ),
      );
      await tester.pump();
      final heading = tester.getRect(find.text('Focus timer'));
      final appBar = tester.getRect(find.byType(AppBar));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(heading.top, greaterThanOrEqualTo(appBar.bottom));
      expect(tester.takeException(), isNull);
      if (size.height >= 800) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('mobile-timer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        final dial = tester.getSize(find.byKey(const Key('timer-laurel')));
        final timerCard = tester.getRect(
          find.byKey(const Key('ready-timer-card')),
        );
        final setupCard = tester.getRect(
          find.byKey(const Key('timer-configuration-card')),
        );
        expect(dial.width, greaterThan(200));
        expect(dial.width, dial.height);
        expect(timerCard.height, greaterThan(setupCard.height));
        expect(nav.top - setupCard.bottom, inInclusiveRange(0, 24));
        expect(
          tester.getRect(find.byKey(const Key('timer-start'))).bottom,
          lessThanOrEqualTo(nav.top),
        );
      }
      await tester.ensureVisible(find.byKey(const Key('timer-focus-minutes')));
      await tester.enterText(find.byKey(const Key('timer-focus-minutes')), '1');
      await tester.enterText(find.byKey(const Key('timer-rest-minutes')), '1');
      expect(find.text('1'), findsNWidgets(2));
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.byKey(const Key('timer-focus-area')), findsNothing);
      expect(find.byKey(const Key('timer-config-summary')), findsOneWidget);
      if (size.height >= 800) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('mobile-timer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        final activeCard = tester.getRect(
          find.byKey(const Key('active-timer')),
        );
        expect(nav.top - activeCard.bottom, inInclusiveRange(0, 24));
        expect(
          tester.getRect(find.byKey(const Key('timer-pause'))).bottom,
          lessThanOrEqualTo(nav.top),
        );
      }
      await container.read(focusTimerProvider.notifier).pause();
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.byKey(const Key('timer-config-summary')), findsOneWidget);
      expect(find.byKey(const Key('timer-focus-area')), findsNothing);
      if (size.height >= 800) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('mobile-timer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        expect(
          tester.getRect(find.byKey(const Key('timer-reset'))).bottom,
          lessThanOrEqualTo(nav.top),
        );
      }
      await container.read(focusTimerProvider.notifier).resume();
      clock.advance(const Duration(minutes: 1, seconds: 5));
      await container.read(focusTimerProvider.notifier).synchronize();
      await tester.pump();
      expect(find.text('REST'), findsOneWidget);
      expect(find.byKey(const Key('timer-config-summary')), findsOneWidget);
      expect(find.byKey(const Key('timer-focus-area')), findsNothing);
      if (size.height >= 800) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('mobile-timer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
      }
      clock.advance(const Duration(minutes: 1));
      await container.read(focusTimerProvider.notifier).synchronize();
      await tester.pump();
      expect(find.byKey(const Key('timer-focus-area')), findsOneWidget);
      expect(recorder.executions, hasLength(1));
      expect(tester.takeException(), isNull);
      if (size.height >= 800) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('mobile-timer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
      }
    });
  }

  testWidgets('selects an active Special Activity and persists its execution', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(500, 800));
    await tester.ensureVisible(find.byKey(const Key('timer-focus-area')));
    await tester.tap(find.byKey(const Key('timer-focus-area')));
    await tester.pumpAndSettle();
    expect(find.text('FOCUS AREAS'), findsOneWidget);
    expect(find.text('SPECIAL ACTIVITIES'), findsOneWidget);
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

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('identical activity names remain distinguishable at $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester, size: size);
      final selector = find.byKey(const Key('timer-focus-area'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('FOCUS AREAS'), findsOneWidget);
      expect(find.text('SPECIAL ACTIVITIES'), findsOneWidget);
      expect(find.byKey(const Key('timer-option-focus-2')), findsOneWidget);
      expect(find.byKey(const Key('timer-option-special-4')), findsOneWidget);
      final divider = tester.getRect(
        find.byKey(const Key('timer-activity-group-divider')),
      );
      final heading = tester.getRect(find.text('SPECIAL ACTIVITIES'));
      final preceding = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('timer-option-focus-2')),
          matching: find.text('Release day'),
        ),
      );
      expect(divider.left, heading.left);
      expect(divider.left, lessThan(preceding.left));
      expect(divider.top, greaterThan(preceding.bottom));
      expect(heading.top, greaterThan(divider.bottom));
      expect(
        (divider.top - preceding.bottom) - (heading.top - divider.bottom),
        inInclusiveRange(-4, 4),
      );
      await tester.tap(find.byKey(const Key('timer-option-focus-2')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: selector,
          matching: find.byIcon(Icons.track_changes_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Focus Area: Release day')),
        findsOneWidget,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timer-option-special-4')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: selector,
          matching: find.byIcon(Icons.local_activity_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Special Activity: Release day')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(
        container.read(focusTimerProvider).activeTimer?.specialActivityId,
        4,
      );
      expect(
        container.read(focusTimerProvider).activeTimer?.focusAreaId,
        isNull,
      );
      await container.read(focusTimerProvider.notifier).pause();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

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
      FocusArea(
        id: 2,
        name: 'Release day',
        priority: 2,
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
  Completer<ActiveFocusTimer?>? pendingLoad;
  @override
  Future<ActiveFocusTimer?> load() async =>
      pendingLoad == null ? value : await pendingLoad!.future;
  @override
  Future<void> save(ActiveFocusTimer timer) async => value = timer;
  @override
  Future<void> clear() async => value = null;
}

class RecordingExecutionRecorder implements TimerExecutionRepository {
  final executions = <TimerExecutionDraft>[];
  Completer<void>? pending;
  @override
  Future<void> save(TimerExecutionDraft execution) async {
    await pending?.future;
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
