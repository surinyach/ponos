import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/app.dart';
import 'package:ponos_app/app/providers/focus_timer_providers.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/home/presentation/widgets/today_summary.dart';
import 'package:ponos_app/features/home/presentation/widgets/focus_areas.dart';
import 'package:ponos_app/features/home/presentation/widgets/work_statistics.dart';
import 'package:ponos_app/features/home/presentation/widgets/streak_consistency.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';

void main() {
  testWidgets('shows wide navigation in a wide viewport', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Ponos'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('manages both types under Work Areas', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work Areas').last);
    await tester.pump();
    expect(find.text('Focus Areas'), findsOneWidget);
    expect(find.text('Special Activities'), findsOneWidget);
    expect(find.byKey(const Key('work-area-type')), findsOneWidget);
    await tester.tap(find.text('Special Activities'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-special-activity')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    expect(find.text('New Special Activity'), findsOneWidget);
  });

  testWidgets('opens the Focus Timer from the navigation bar', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();

    expect(find.text('Focus timer'), findsOneWidget);
  });

  test('light and dark themes use the Ponos palette', () {
    expect(AppTheme.light.colorScheme.primary, AppColors.olive);
    expect(AppTheme.light.colorScheme.secondary, AppColors.bronze);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    expect(AppTheme.dark.useMaterial3, isTrue);
  });

  testWidgets('shows today summary mock values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: TodaySummary(
            workedDuration: Duration(hours: 6, minutes: 30),
            expectedDuration: Duration(hours: 11),
            completedFocusAreas: 1,
            totalFocusAreas: 3,
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('6h 30m'), findsOneWidget);
    expect(find.text('11h'), findsOneWidget);
    expect(find.text('Focused today'), findsOneWidget);
    expect(find.text('Expected today'), findsOneWidget);
    expect(find.text('1 / 3 focus areas completed'), findsOneWidget);
  });

  testWidgets('today metrics align across focused and rest rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: TodaySummary(
            workedDuration: Duration(hours: 6),
            expectedDuration: Duration(hours: 8),
            restDuration: Duration(minutes: 15),
            trackedDuration: Duration(hours: 6, minutes: 15),
            completedFocusAreas: 1,
            totalFocusAreas: 2,
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byIcon(Icons.schedule)).dx,
      tester.getTopLeft(find.byIcon(Icons.self_improvement_outlined)).dx,
    );
    expect(
      tester.getTopLeft(find.text('Focused today')).dx,
      tester.getTopLeft(find.text('Rest today')).dx,
    );
  });

  testWidgets('shows focus areas ordered by priority with daily progress', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 1);
    final targetDate = DateTime(2026, 9, 7);
    FocusArea area(int id, String name, int priority, int targetMinutes) {
      return FocusArea(
        id: id,
        name: name,
        priority: priority,
        createdAt: timestamp,
        updatedAt: timestamp,
        targets: [
          FocusAreaTarget(
            id: id,
            focusAreaId: id,
            weekday: DateTime.monday,
            targetMinutes: targetMinutes,
            validFrom: targetDate,
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FocusAreas(
            targetDate: targetDate,
            workedTodayByAreaId: const {
              1: Duration(hours: 1),
              2: Duration(hours: 1),
            },
            areas: [
              area(2, 'Second priority', 2, 120),
              area(1, 'First priority', 1, 60),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Focus Areas & Special Activities'), findsOneWidget);
    expect(find.text('1h today · 1h/day target'), findsOneWidget);
    expect(find.text('1h today · 2h/day target'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    expect(
      labels.indexOf('First priority'),
      lessThan(labels.indexOf('Second priority')),
    );
  });

  testWidgets('shows Special Activity focus and rest beside Focus Areas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FocusAreas(
            areas: const [],
            workedTodayByAreaId: const {},
            specialActivities: const [
              SpecialActivityTodayProgress(
                specialActivity: SpecialActivity(id: 4, name: 'Release day'),
                focusedTime: Duration(minutes: 25),
                restTime: Duration(minutes: 5),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Focus Areas & Special Activities'), findsOneWidget);
    expect(find.text('Release day'), findsOneWidget);
    expect(
      find.text('Special Activity · Focus 25m · Rest 5m today'),
      findsOneWidget,
    );
  });

  testWidgets('uses full elapsed precision for Work Area progress', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 7);
    final area = FocusArea(
      id: 9,
      name: 'Short task',
      priority: 1,
      createdAt: day,
      updatedAt: day,
      targets: [
        FocusAreaTarget(
          id: 9,
          focusAreaId: 9,
          weekday: DateTime.monday,
          targetMinutes: 2,
          validFrom: day,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FocusAreas(
            targetDate: day,
            areas: [area],
            workedTodayByAreaId: const {9: Duration(seconds: 90)},
          ),
        ),
      ),
    );

    expect(find.text('75%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.75,
    );
  });

  testWidgets('shows current streak and weekly consistency', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: StreakConsistency(
            dailyStreak: 6,
            weeklyStreak: 3,
            week: [
              ConsistencyDay(label: 'M', isCompleted: true),
              ConsistencyDay(label: 'T', isCompleted: true),
              ConsistencyDay(label: 'W', isCompleted: false, isToday: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Streak consistency'), findsOneWidget);
    expect(find.text('6 days'), findsOneWidget);
    expect(find.text('Daily streak'), findsOneWidget);
    expect(find.text('3 weeks'), findsOneWidget);
    expect(find.text('Weekly streak'), findsOneWidget);
    expect(find.text('2 of 3 days completed this week'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('shows lifetime work statistics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: WorkStatistics(
            totalDaysWorked: 128,
            totalFocusedTime: Duration(hours: 342, minutes: 30),
            totalRestTime: Duration(hours: 86, minutes: 15),
            totalTrackedTime: Duration(hours: 428, minutes: 45),
          ),
        ),
      ),
    );

    expect(find.text('Work statistics'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('342h 30m'), findsOneWidget);
    expect(find.text('86h 15m'), findsOneWidget);
    expect(find.text('428h 45m'), findsOneWidget);
    expect(find.text('Days worked'), findsOneWidget);
    expect(find.text('Focused time'), findsOneWidget);
    expect(find.text('Rest time'), findsOneWidget);
    expect(find.text('Tracked time'), findsOneWidget);
  });

  testWidgets('desktop overview columns share the same height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    final summaryRect = tester.getRect(find.byType(TodaySummary));
    final statisticsRect = tester.getRect(find.byType(WorkStatistics));
    final areasRect = tester.getRect(find.byType(FocusAreas));

    expect(summaryRect.top, areasRect.top);
    expect(statisticsRect.bottom, areasRect.bottom);
  });

  testWidgets('overview shows aggregated daily, weekly, and lifetime data', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Rest today'), findsOneWidget);
    expect(find.text('Tracked today'), findsOneWidget);
    expect(find.text('This week · 30m focused · 5m rest'), findsOneWidget);
    expect(find.text('Days worked'), findsOneWidget);
    expect(find.text('128'), findsNothing);
  });

  testWidgets('overview shows empty and error states', (tester) async {
    await tester.pumpWidget(_testApp(overview: _overview(areas: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No active focus areas'), findsOneWidget);
    expect(find.byType(WorkStatistics), findsOneWidget);
    expect(find.byType(TodaySummary), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayOverviewProvider.overrideWith(
            (ref) => Future<TodayOverview>.error(Exception('offline')),
          ),
        ],
        child: const PonosApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load today’s overview'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

Widget _testApp({TodayOverview? overview}) => ProviderScope(
  overrides: [
    activeFocusTimerStoreProvider.overrideWithValue(_EmptyTimerStore()),
    todayOverviewProvider.overrideWith(
      (ref) async => overview ?? _overview(areas: [_progress()]),
    ),
  ],
  child: const PonosApp(),
);

class _EmptyTimerStore implements ActiveFocusTimerStore {
  @override
  Future<ActiveFocusTimer?> load() async => null;

  @override
  Future<void> save(ActiveFocusTimer timer) async {}

  @override
  Future<void> clear() async {}
}

TodayOverview _overview({required List<FocusAreaTodayProgress> areas}) =>
    TodayOverview(
      date: DateTime(2026, 9, 7),
      expectedFocusTime: const Duration(hours: 1),
      actualFocusedTime: const Duration(minutes: 30),
      actualRestTime: const Duration(minutes: 5),
      actualTrackedTime: const Duration(minutes: 35),
      completedFocusAreas: 0,
      targetedFocusAreas: areas.isEmpty ? 0 : 1,
      areas: areas,
      week: WeeklyWorkTotals(
        weekStart: DateTime(2026, 9, 7),
        weekEnd: DateTime(2026, 9, 13),
        focusedTime: const Duration(minutes: 30),
        restTime: const Duration(minutes: 5),
        trackedTime: const Duration(minutes: 35),
      ),
      overall: const OverallWorkTotals(
        daysWorked: 1,
        focusedTime: Duration(minutes: 30),
        restTime: Duration(minutes: 5),
        trackedTime: Duration(minutes: 35),
      ),
    );

FocusAreaTodayProgress _progress() {
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
  return FocusAreaTodayProgress(
    focusArea: area,
    focusedTime: const Duration(minutes: 30),
    targetTime: const Duration(hours: 1),
    completed: false,
  );
}
