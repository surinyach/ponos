import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/work_goals_providers.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/home_page.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/work_goals/domain/models/work_goals.dart';

void main() {
  testWidgets('refreshes Overview and Work Goals at local midnight', (
    tester,
  ) async {
    final clock = _MutableClock(DateTime(2026, 9, 7, 23, 59, 59));
    final requests = await _pumpLifecycleOverview(tester, clock);
    expect(requests.overviewDates, [DateTime(2026, 9, 7)]);
    expect(requests.goalDates, [DateTime(2026, 9, 7)]);

    clock.now = DateTime(2026, 9, 8);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(requests.overviewDates, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 8),
    ]);
    expect(requests.goalDates, [DateTime(2026, 9, 7), DateTime(2026, 9, 8)]);
  });

  testWidgets('resume after a date change refreshes immediately', (
    tester,
  ) async {
    final clock = _MutableClock(DateTime(2026, 9, 7, 18));
    final requests = await _pumpLifecycleOverview(tester, clock);
    clock.now = DateTime(2026, 9, 8, 9);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(requests.overviewDates, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 8),
    ]);
    expect(requests.goalDates, [DateTime(2026, 9, 7), DateTime(2026, 9, 8)]);
  });

  testWidgets('resume on the same local date avoids duplicate requests', (
    tester,
  ) async {
    final clock = _MutableClock(DateTime(2026, 9, 7, 9));
    final requests = await _pumpLifecycleOverview(tester, clock);
    clock.now = DateTime(2026, 9, 7, 18);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(requests.overviewDates, [DateTime(2026, 9, 7)]);
    expect(requests.goalDates, [DateTime(2026, 9, 7)]);
  });
}

class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  DateTime call() => now;
}

class _LifecycleRequests {
  final List<DateTime> overviewDates = [];
  final List<DateTime> goalDates = [];
}

Future<_LifecycleRequests> _pumpLifecycleOverview(
  WidgetTester tester,
  _MutableClock clock,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final requests = _LifecycleRequests();
  final container = ProviderContainer(
    overrides: [
      overviewClockProvider.overrideWithValue(clock.call),
      todayOverviewProvider.overrideWith((ref) async {
        final date = _dateOnly(ref.watch(currentDateTimeProvider));
        requests.overviewDates.add(date);
        return _overview(date);
      }),
      workGoalsProvider.overrideWith((ref) async {
        final date = _dateOnly(ref.watch(currentDateTimeProvider));
        requests.goalDates.add(date);
        return _goals(date);
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
        home: const HomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requests;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

TodayOverview _overview(DateTime date) => TodayOverview(
  date: date,
  expectedFocusTime: Duration.zero,
  actualFocusedTime: Duration.zero,
  actualRestTime: Duration.zero,
  actualTrackedTime: Duration.zero,
  completedFocusAreas: 0,
  targetedFocusAreas: 0,
  areas: const [],
  streak: const StreakSummary(
    currentDailyStreak: 0,
    currentWeeklyStreak: 0,
    recentDays: [],
  ),
  week: WeeklyWorkTotals(
    weekStart: date,
    weekEnd: date.add(const Duration(days: 6)),
    focusedTime: Duration.zero,
    restTime: Duration.zero,
    trackedTime: Duration.zero,
  ),
  overall: const OverallWorkTotals(
    daysWorked: 0,
    focusedTime: Duration.zero,
    restTime: Duration.zero,
    trackedTime: Duration.zero,
  ),
);

WorkGoals _goals(DateTime date) => WorkGoals(
  date: date,
  dailyGoals: [
    for (var weekday = 1; weekday <= 7; weekday++)
      DailyWorkGoal(weekday: weekday, targetMinutes: 0),
  ],
  weeklyGoalMinutes: 0,
  weeklyGoalEffectiveFrom: date,
);
