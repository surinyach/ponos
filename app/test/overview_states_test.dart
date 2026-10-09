import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/work_goals_providers.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/home_page.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/work_goals/domain/models/work_goals.dart';

void main() {
  testWidgets('initial loading and fatal error keep the shell and retry', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);

    expect(find.byKey(const Key('overview-initial-loading')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    overview.requests.single.completeError(Exception('offline'));
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overview-initial-error')), findsOneWidget);
    expect(find.text('Check the connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(overview.requests, hasLength(2));

    overview.requests.last.complete(_overview());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview-streak')), findsOneWidget);
    expect(find.byKey(const Key('overview-initial-error')), findsNothing);
    container.dispose();
  });

  testWidgets('refresh preserves the dashboard and exposes subtle progress', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);
    overview.requests.single.complete(_overview());
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    container.invalidate(todayOverviewProvider);
    await tester.pump();

    expect(find.byKey(const Key('overview-streak')), findsOneWidget);
    expect(find.byKey(const Key('overview-refresh-indicator')), findsOneWidget);
    expect(find.byKey(const Key('overview-initial-loading')), findsNothing);

    overview.requests.last.complete(
      _overview(focused: const Duration(minutes: 45)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview-refresh-indicator')), findsNothing);
    container.dispose();
  });

  testWidgets('refresh failure keeps stale data and Retry recovers', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);
    overview.requests.single.complete(_overview());
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    container.invalidate(todayOverviewProvider);
    await tester.pump();
    overview.requests.last.completeError(Exception('refresh failed'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('overview-streak')), findsOneWidget);
    expect(find.byKey(const Key('overview-refresh-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-overview-refresh')));
    await tester.pump();
    expect(overview.requests, hasLength(3));
    overview.requests.last.complete(_overview());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview-refresh-error')), findsNothing);
    container.dispose();
  });

  testWidgets('Work Goals loading and failure do not hide Streak', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);
    overview.requests.single.complete(_overview());
    await tester.pump();

    expect(find.byKey(const Key('overview-streak')), findsOneWidget);
    expect(find.text('Goals unavailable'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));

    goals.requests.single.completeError(Exception('goals failed'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('overview-streak')), findsOneWidget);
    expect(find.text('Goals unavailable'), findsOneWidget);
    expect(find.byKey(const Key('retry-work-goals')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-work-goals')));
    await tester.pump();
    expect(goals.requests, hasLength(2));
    goals.requests.last.complete(_goals());
    await tester.pumpAndSettle();
    expect(find.text('Goals unavailable'), findsNothing);
    expect(find.text('1h 30m'), findsOneWidget);
    container.dispose();
  });

  testWidgets('card-level empty states preserve normal zero metrics', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);
    overview.requests.single.complete(
      _overview(
        focused: Duration.zero,
        emptyAreas: true,
        emptyHistory: true,
        zeroStatistics: true,
      ),
    );
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    expect(find.text('No focus areas configured'), findsOneWidget);
    expect(find.text('0 / 0 complete'), findsNothing);
    expect(find.text('No special activity recorded today'), findsOneWidget);
    expect(find.text('No streak history yet'), findsOneWidget);
    expect(find.text('0m'), findsWidgets);
    expect(find.text('Days'), findsOneWidget);
    container.dispose();
  });

  testWidgets('existing Focus Areas keep their normal zero-progress summary', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(tester, overview: overview, goals: goals);
    overview.requests.single.complete(_overview(focused: Duration.zero));
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    expect(find.text('0 / 1 complete'), findsOneWidget);
    expect(find.text('No focus areas configured'), findsNothing);
    expect(find.text('0m'), findsWidgets);
    container.dispose();
  });

  for (final viewport in const [
    (Size(390, 844), TargetPlatform.android),
    (Size(500, 700), TargetPlatform.windows),
    (Size(768, 1024), TargetPlatform.windows),
    (Size(1440, 900), TargetPlatform.windows),
  ]) {
    testWidgets('async states fit at ${viewport.$1}', (tester) async {
      final overview = _Sequence<TodayOverview>();
      final goals = _Sequence<WorkGoals>();
      final container = await _pumpApp(
        tester,
        overview: overview,
        goals: goals,
        size: viewport.$1,
        platform: viewport.$2,
      );
      overview.requests.single.complete(_overview());
      goals.requests.single.completeError(Exception('goals failed'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Goals unavailable'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('retry-work-goals'))).height,
        greaterThanOrEqualTo(48),
      );
      container.dispose();
    });
  }

  testWidgets('initial error remains reachable at 200% text scaling', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(
      tester,
      overview: overview,
      goals: goals,
      textScaler: const TextScaler.linear(2),
    );
    overview.requests.single.completeError(Exception('offline'));
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('overview-initial-error')), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Try again')).height,
      greaterThanOrEqualTo(48),
    );
    container.dispose();
  });

  testWidgets('Work Goals failure remains reachable at 200% text scaling', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(
      tester,
      overview: overview,
      goals: goals,
      textScaler: const TextScaler.linear(2),
    );
    overview.requests.single.complete(_overview());
    goals.requests.single.completeError(Exception('goals failed'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Goals unavailable'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('retry-work-goals'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      find.byKey(const Key('overview-accessibility-scroll')),
      findsOneWidget,
    );
    container.dispose();
  });

  testWidgets('refresh failure notice remains accessible at 200% scaling', (
    tester,
  ) async {
    final overview = _Sequence<TodayOverview>();
    final goals = _Sequence<WorkGoals>();
    final container = await _pumpApp(
      tester,
      overview: overview,
      goals: goals,
      textScaler: const TextScaler.linear(2),
    );
    overview.requests.single.complete(_overview());
    goals.requests.single.complete(_goals());
    await tester.pumpAndSettle();

    container.invalidate(todayOverviewProvider);
    await tester.pump();
    overview.requests.last.completeError(Exception('refresh failed'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('overview-refresh-error')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('retry-overview-refresh'))).height,
      greaterThanOrEqualTo(48),
    );
    container.dispose();
  });
}

class _Sequence<T> {
  final List<Completer<T>> requests = [];

  Future<T> next() {
    final request = Completer<T>();
    requests.add(request);
    return request.future;
  }
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required _Sequence<TodayOverview> overview,
  required _Sequence<WorkGoals> goals,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      todayOverviewProvider.overrideWith((ref) => overview.next()),
      workGoalsProvider.overrideWith((ref) => goals.next()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const HomePage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

WorkGoals _goals() => WorkGoals(
  date: DateTime(2026, 9, 7),
  dailyGoals: [
    for (var weekday = 1; weekday <= 7; weekday++)
      DailyWorkGoal(weekday: weekday, targetMinutes: 90),
  ],
  weeklyGoalMinutes: 600,
  weeklyGoalEffectiveFrom: DateTime(2026, 9, 7),
);

TodayOverview _overview({
  Duration focused = const Duration(minutes: 30),
  bool emptyAreas = false,
  bool emptyHistory = false,
  bool zeroStatistics = false,
}) {
  final date = DateTime(2026, 9, 7);
  final area = FocusArea(
    id: 1,
    name: 'Work placement',
    priority: 1,
    createdAt: date,
    updatedAt: date,
    targets: [
      FocusAreaTarget(
        id: 1,
        focusAreaId: 1,
        weekday: DateTime.monday,
        targetMinutes: 60,
        validFrom: date,
      ),
    ],
  );
  return TodayOverview(
    date: date,
    expectedFocusTime: const Duration(hours: 1),
    actualFocusedTime: focused,
    actualRestTime: Duration.zero,
    actualTrackedTime: focused,
    completedFocusAreas: 0,
    targetedFocusAreas: emptyAreas ? 0 : 1,
    areas: emptyAreas
        ? const []
        : [
            FocusAreaTodayProgress(
              focusArea: area,
              focusedTime: focused,
              targetTime: const Duration(hours: 1),
              completed: false,
            ),
          ],
    streak: StreakSummary(
      currentDailyStreak: 2,
      currentWeeklyStreak: 1,
      recentDays: emptyHistory
          ? const []
          : [
              DailyCompletion(
                date: date,
                state: DailyCompletionState.inProgress,
              ),
            ],
    ),
    week: WeeklyWorkTotals(
      weekStart: date,
      weekEnd: date.add(const Duration(days: 6)),
      focusedTime: focused,
      restTime: Duration.zero,
      trackedTime: focused,
    ),
    overall: zeroStatistics
        ? const OverallWorkTotals(
            daysWorked: 0,
            focusedTime: Duration.zero,
            restTime: Duration.zero,
            trackedTime: Duration.zero,
          )
        : const OverallWorkTotals(
            daysWorked: 42,
            focusedTime: Duration(hours: 126),
            restTime: Duration(hours: 18),
            trackedTime: Duration(hours: 144),
          ),
  );
}
