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
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/home/presentation/widgets/today_summary.dart';
import 'package:ponos_app/features/home/presentation/widgets/focus_areas.dart';
import 'package:ponos_app/features/home/presentation/widgets/work_statistics.dart';
import 'package:ponos_app/features/home/presentation/widgets/streak_consistency.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/domain/repositories/focus_timer_gateways.dart';

void main() {
  testWidgets('shows wide navigation in a wide viewport', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Ponos'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
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

    expect(find.text('Focus areas'), findsOneWidget);
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

  testWidgets('overview shows empty and error states', (tester) async {
    await tester.pumpWidget(_testApp(overview: _overview(areas: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No active focus areas'), findsOneWidget);

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
      completedFocusAreas: 0,
      targetedFocusAreas: areas.isEmpty ? 0 : 1,
      areas: areas,
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
