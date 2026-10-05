import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ponos_app/app/providers/work_goals_providers.dart';
import 'package:ponos_app/core/config/api_config.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/work_goals/data/remote_work_goals_repository.dart';
import 'package:ponos_app/features/work_goals/data/work_goals_api_client.dart';
import 'package:ponos_app/features/work_goals/domain/models/work_goals.dart';
import 'package:ponos_app/features/work_goals/domain/repositories/work_goals_repository.dart';
import 'package:ponos_app/features/work_goals/presentation/work_goals_page.dart';

void main() {
  test('loads and saves weekday and weekly goals through the API', () async {
    final requests = <http.Request>[];
    final repository = RemoteWorkGoalsRepository(
      WorkGoalsApiClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_response()), 200);
        }),
        ApiConfig('https://home.example'),
      ),
    );

    final loaded = await repository.get(DateTime(2026, 9, 9));
    await repository.save(DateTime(2026, 9, 9), loaded);

    expect(requests.first.method, 'GET');
    expect(requests.last.method, 'PUT');
    expect(requests.last.url.queryParameters['date'], '2026-09-09');
    final body = jsonDecode(requests.last.body) as Map<String, Object?>;
    expect(body['weekly_goal_minutes'], 600);
    expect(body['daily_goals'], hasLength(7));
  });

  testWidgets('edits goals, saves, and refreshes Overview', (tester) async {
    final repository = _FakeWorkGoalsRepository(_goals());
    var overviewLoads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workGoalsRepositoryProvider.overrideWithValue(repository),
          currentDateTimeProvider.overrideWithValue(DateTime(2026, 9, 9)),
          todayOverviewProvider.overrideWith((ref) async {
            overviewLoads += 1;
            return _overview();
          }),
        ],
        child: const MaterialApp(home: _Harness()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monday minutes'),
      '90',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weekly minutes'),
      '720',
    );
    await tester.ensureVisible(find.text('Save goals'));
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(repository.saved!.dailyGoals.first.targetMinutes, 90);
    expect(repository.saved!.weeklyGoalMinutes, 720);
    expect(overviewLoads, 2);
  });
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(todayOverviewProvider);
    return const WorkGoalsPage();
  }
}

class _FakeWorkGoalsRepository implements WorkGoalsRepository {
  _FakeWorkGoalsRepository(this.value);

  final WorkGoals value;
  WorkGoals? saved;

  @override
  Future<WorkGoals> get(DateTime localDate) async => value;

  @override
  Future<WorkGoals> save(DateTime localDate, WorkGoals goals) async {
    saved = goals;
    return goals;
  }
}

WorkGoals _goals() => WorkGoals(
  date: DateTime(2026, 9, 9),
  dailyGoals: [
    for (var weekday = 1; weekday <= 7; weekday++)
      DailyWorkGoal(weekday: weekday, targetMinutes: 60),
  ],
  weeklyGoalMinutes: 600,
  weeklyGoalEffectiveFrom: DateTime(2026, 9, 14),
);

Map<String, Object?> _response() => {
  'date': '2026-09-09',
  'daily_goals': [
    for (var weekday = 1; weekday <= 7; weekday++)
      {'weekday': weekday, 'target_minutes': 60},
  ],
  'weekly_goal_minutes': 600,
  'weekly_goal_effective_from': '2026-09-14',
};

TodayOverview _overview() => TodayOverview(
  date: DateTime(2026, 9, 9),
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
    weekStart: DateTime(2026, 9, 7),
    weekEnd: DateTime(2026, 9, 13),
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
