import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/providers/work_goals_providers.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/home/presentation/home_page.dart';
import 'package:ponos_app/features/home/presentation/overview_page.dart';
import 'package:ponos_app/features/work_goals/domain/models/work_goals.dart';
import 'package:ponos_app/features/work_goals/presentation/work_goals_page.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(
        rootBundle.load('assets/fonts/inter/Inter-VariableFont_opsz,wght.ttf'),
      );
    await inter.load();
    final dartExecutable = File(Platform.resolvedExecutable);
    var flutterCache = dartExecutable.parent;
    while (flutterCache.path.split(Platform.pathSeparator).last != 'cache') {
      flutterCache = flutterCache.parent;
    }
    final materialIconsFile = File(
      '${flutterCache.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}material_fonts${Platform.pathSeparator}'
      'materialicons-regular.otf',
    );
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(
        materialIconsFile.readAsBytes().then(
          (bytes) => ByteData.sublistView(bytes),
        ),
      );
    await materialIcons.load();
  });

  for (final testCase in const [
    (width: 390.0, layoutKey: 'overview-compact'),
    (width: 768.0, layoutKey: 'overview-medium'),
    (width: 1440.0, layoutKey: 'overview-expanded'),
  ]) {
    testWidgets('uses ${testCase.layoutKey} at ${testCase.width}px', (
      tester,
    ) async {
      await _pumpOverview(tester, Size(testCase.width, 1000));
      expect(find.byKey(Key(testCase.layoutKey)), findsOneWidget);
      if (testCase.width < 840) {
        expect(find.textContaining('day streak'), findsOneWidget);
        expect(find.textContaining('week streak'), findsOneWidget);
        expect(find.byTooltip('Edit goals'), findsOneWidget);
      } else {
        expect(find.textContaining('2 days'), findsOneWidget);
        expect(find.textContaining('1 week'), findsOneWidget);
        expect(find.text('Goals'), findsOneWidget);
      }
    });
  }

  testWidgets('compact sections follow the approved priority order', (
    tester,
  ) async {
    await _pumpOverview(tester, const Size(390, 1200));

    final tops = [
      'overview-streak',
      'overview-today',
      'overview-work-areas',
      'overview-statistics',
    ].map((key) => tester.getTopLeft(find.byKey(Key(key))).dy).toList();
    expect(tops, orderedEquals([...tops]..sort()));
  });

  for (final viewport in const [
    Size(360, 700),
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets(
      'compact dashboard fits ${viewport.width.toInt()}x${viewport.height.toInt()} without scrolling',
      (tester) async {
        await _pumpOverview(tester, viewport);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Compact Overview must not throw layout overflow errors.',
        );
        final compact = find.byKey(const Key('overview-compact'));
        expect(
          find.descendant(of: compact, matching: find.byType(Scrollable)),
          findsNothing,
        );
        for (final key in const [
          'overview-today',
          'overview-actions',
          'overview-work-areas',
          'overview-streak',
          'overview-statistics',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }
        final navigationTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
        final statisticsBottom = tester
            .getBottomLeft(find.byKey(const Key('overview-statistics')))
            .dy;
        expect(statisticsBottom, lessThanOrEqualTo(navigationTop));
        expect(
          navigationTop - statisticsBottom,
          lessThanOrEqualTo(AppSpacing.lg + 0.01),
        );

        final pillar = tester.getRect(
          find.byKey(const Key('compact-today-pillar')),
        );
        final actions = tester.getRect(
          find.byKey(const Key('overview-actions')),
        );
        expect(pillar.bottom, lessThanOrEqualTo(actions.top));

        final workGoals = tester.getSize(
          find.byKey(const Key('compact-edit-goals-action')),
        );
        expect(workGoals.width, greaterThanOrEqualTo(48));
        expect(workGoals.height, greaterThanOrEqualTo(48));
      },
    );
  }

  testWidgets('compact Overview scrolls only when 200% text cannot fit', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    final accessibilityScroll = find.byKey(
      const Key('overview-accessibility-scroll'),
    );
    expect(accessibilityScroll, findsOneWidget);
    final scrollable = find.descendant(
      of: accessibilityScroll,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );

    for (final key in const [
      'overview-streak',
      'overview-today',
      'overview-work-areas',
      'overview-statistics',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Start Focus')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Log Work')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('compact-edit-goals-action'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('overview-statistics')),
      300,
      scrollable: scrollable,
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('overview-statistics'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
    );
  });

  testWidgets('compact detail summaries open and close modal sheets', (
    tester,
  ) async {
    await _pumpOverview(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('overview-work-areas')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-areas-detail-sheet')), findsOneWidget);
    expect(find.text('No special activity recorded today'), findsWidgets);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-areas-detail-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('compact-streak-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('streak-detail-sheet')), findsOneWidget);
    for (final state in const [
      'completed',
      'failed',
      'neutral',
      'in progress',
    ]) {
      expect(find.bySemanticsLabel(RegExp(': $state')), findsWidgets);
    }
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('streak-detail-sheet')), findsNothing);
  });

  testWidgets(
    'desktop Work Goals appear only inside Streak and retain navigation',
    (tester) async {
      await _pumpOverview(tester, const Size(1440, 900));

      expect(find.text('Ready to focus?'), findsNothing);
      final today = find.byKey(const Key('overview-today'));
      expect(
        find.descendant(of: today, matching: find.text('Start Focus')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: today, matching: find.text('Log Work')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('overview-work-goals')), findsNothing);
      final streak = find.byKey(const Key('overview-streak'));
      expect(
        find.descendant(of: streak, matching: find.text('1h 30m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: streak, matching: find.text('10h')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: streak, matching: find.text('Edit goals')),
        findsOneWidget,
      );
      expect(find.text('Edit goals'), findsOneWidget);

      await tester.tap(
        find.descendant(of: streak, matching: find.text('Edit goals')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkGoalsPage), findsOneWidget);
    },
  );

  testWidgets('expanded streak keeps all seven recent days grouped', (
    tester,
  ) async {
    await _pumpOverview(tester, const Size(1440, 900));
    final group = find.byKey(const Key('desktop-recent-days-group'));
    expect(group, findsOneWidget);
    expect(tester.getSize(group).width, lessThan(500));
    for (final state in const [
      'completed',
      'failed',
      'neutral',
      'in progress',
    ]) {
      expect(find.bySemanticsLabel(RegExp(': $state')), findsWidgets);
    }
  });

  testWidgets(
    'medium layout keeps streak first and balances remaining sections',
    (tester) async {
      await _pumpOverview(tester, const Size(768, 1024));
      final areas = tester.getRect(
        find.byKey(const Key('overview-work-areas')),
      );
      final streak = tester.getRect(find.byKey(const Key('overview-streak')));
      final today = tester.getRect(find.byKey(const Key('overview-today')));
      final statistics = tester.getRect(
        find.byKey(const Key('overview-statistics')),
      );
      expect(streak.bottom, lessThanOrEqualTo(today.top));
      expect(today.left, lessThan(areas.left));
      expect(statistics.top, greaterThan(areas.top));
    },
  );

  for (final viewport in const [Size(1440, 900), Size(1920, 1080)]) {
    testWidgets(
      'expanded hierarchy keeps streak first at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await _pumpOverview(tester, viewport);
        final streak = tester.getRect(find.byKey(const Key('overview-streak')));
        final today = tester.getRect(find.byKey(const Key('overview-today')));
        final areas = tester.getRect(
          find.byKey(const Key('overview-work-areas')),
        );
        final statistics = tester.getRect(
          find.byKey(const Key('overview-statistics')),
        );
        expect(streak.top, lessThan(today.top));
        expect(streak.top, lessThan(areas.top));
        expect(streak.top, lessThan(statistics.top));
      },
    );
  }

  for (final viewport in const [
    Size(500, 600),
    Size(500, 700),
    Size(600, 650),
    Size(700, 700),
    Size(1024, 768),
    Size(500, 900),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'desktop Overview keeps a lateral navigation at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await _pumpOverview(tester, viewport, platform: TargetPlatform.windows);

        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(OverviewPage),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        expect(
          tester.getRect(find.byKey(const Key('overview-streak'))).right,
          lessThanOrEqualTo(viewport.width),
        );
        if (viewport.width >= 1440 && viewport.height >= 900) {
          expect(find.byKey(const Key('overview-expanded')), findsOneWidget);
          expect(
            find.byKey(const Key('overview-compact-desktop')),
            findsNothing,
          );
          expect(
            tester.getSize(find.byKey(const Key('overview-streak'))).height,
            lessThan(240),
          );
          expect(
            tester.getSize(find.byKey(const Key('overview-today'))).height,
            lessThan(500),
          );
        }
      },
    );
  }

  for (final viewport in const [
    (width: 390.0, height: 844.0, platform: TargetPlatform.android),
    (width: 500.0, height: 700.0, platform: TargetPlatform.windows),
    (width: 768.0, height: 1024.0, platform: TargetPlatform.windows),
    (width: 1440.0, height: 900.0, platform: TargetPlatform.windows),
  ]) {
    testWidgets(
      'Overview screenshot at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await _pumpOverview(
          tester,
          Size(viewport.width, viewport.height),
          platform: viewport.platform,
        );
        await expectLater(
          find.byType(PonosAdaptiveShell),
          matchesGoldenFile(
            'goldens/ponos_overview_${viewport.width.toInt()}x${viewport.height.toInt()}.png',
          ),
        );
      },
    );
  }
}

Future<void> _pumpOverview(
  WidgetTester tester,
  Size size, {
  TargetPlatform platform = TargetPlatform.android,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayOverviewProvider.overrideWith((ref) async => _overview()),
        workGoalsProvider.overrideWith((ref) async => _workGoals()),
      ],
      child: MaterialApp(
        title: 'Ponos',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light.copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const HomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WorkGoals _workGoals() => WorkGoals(
  date: DateTime(2026, 9, 7),
  dailyGoals: [
    for (var weekday = 1; weekday <= 7; weekday++)
      DailyWorkGoal(
        weekday: weekday,
        targetMinutes: weekday == DateTime.monday ? 90 : 60,
      ),
  ],
  weeklyGoalMinutes: 600,
  weeklyGoalEffectiveFrom: DateTime(2026, 9, 7),
);

TodayOverview _overview() {
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
    actualFocusedTime: const Duration(minutes: 30),
    actualRestTime: const Duration(minutes: 5),
    actualTrackedTime: const Duration(minutes: 35),
    completedFocusAreas: 0,
    targetedFocusAreas: 1,
    areas: [
      FocusAreaTodayProgress(
        focusArea: area,
        focusedTime: const Duration(minutes: 30),
        targetTime: const Duration(hours: 1),
        completed: false,
      ),
    ],
    streak: StreakSummary(
      currentDailyStreak: 2,
      currentWeeklyStreak: 1,
      recentDays: [
        for (var offset = 6; offset >= 0; offset--)
          DailyCompletion(
            date: date.subtract(Duration(days: offset)),
            state: switch (offset) {
              0 => DailyCompletionState.inProgress,
              1 || 2 || 3 => DailyCompletionState.completed,
              4 => DailyCompletionState.failed,
              _ => DailyCompletionState.neutral,
            },
          ),
      ],
    ),
    week: WeeklyWorkTotals(
      weekStart: date,
      weekEnd: date.add(const Duration(days: 6)),
      focusedTime: const Duration(hours: 4),
      restTime: const Duration(minutes: 45),
      trackedTime: const Duration(hours: 4, minutes: 45),
    ),
    overall: const OverallWorkTotals(
      daysWorked: 42,
      focusedTime: Duration(hours: 126),
      restTime: Duration(hours: 18),
      trackedTime: Duration(hours: 144),
    ),
  );
}
