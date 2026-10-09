import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/providers/work_goals_providers.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/models/work_totals.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';
import 'package:ponos_app/features/home/presentation/home_page.dart';
import 'package:ponos_app/features/home/presentation/overview_page.dart';
import 'package:ponos_app/features/home/presentation/overview_responsive_layout.dart';
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

  for (final testCase in const [
    (
      name: '320x568',
      size: Size(320, 568),
      viewPadding: EdgeInsets.zero,
      availableHeight: 408.0,
      scrolls: true,
    ),
    (
      name: '360x640',
      size: Size(360, 640),
      viewPadding: EdgeInsets.zero,
      availableHeight: 480.0,
      scrolls: true,
    ),
    (
      name: '360x700',
      size: Size(360, 700),
      viewPadding: EdgeInsets.zero,
      availableHeight: 540.0,
      scrolls: true,
    ),
    (
      name: '390x844',
      size: Size(390, 844),
      viewPadding: EdgeInsets.zero,
      availableHeight: 684.0,
      scrolls: false,
    ),
    (
      name: '411.43x914.29 with Android insets',
      size: Size(411.428571, 914.285714),
      viewPadding: EdgeInsets.only(top: 50.285714, bottom: 24),
      availableHeight: 680.0,
      scrolls: false,
    ),
    (
      name: '412x915',
      size: Size(412, 915),
      viewPadding: EdgeInsets.zero,
      availableHeight: 755.0,
      scrolls: false,
    ),
    (
      name: '430x932',
      size: Size(430, 932),
      viewPadding: EdgeInsets.zero,
      availableHeight: 772.0,
      scrolls: false,
    ),
  ]) {
    testWidgets('compact dashboard adapts at ${testCase.name}', (tester) async {
      await _pumpOverview(
        tester,
        testCase.size,
        viewPadding: testCase.viewPadding,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Compact Overview must not throw layout overflow errors.',
      );
      expect(
        tester.getSize(find.byType(OverviewResponsiveLayout)).height,
        closeTo(testCase.availableHeight.clamp(0, 684), 0.02),
      );
      expect(
        find.byKey(const Key('overview-compact-scroll')),
        testCase.scrolls ? findsOneWidget : findsNothing,
      );
      if (testCase.scrolls) {
        final scrollable = find.descendant(
          of: find.byKey(const Key('overview-compact-scroll')),
          matching: find.byType(Scrollable),
        );
        expect(scrollable, findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
      }
      for (final key in const [
        'overview-today',
        'overview-actions',
        'overview-work-areas',
        'overview-streak',
        'overview-statistics',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      expect(
        tester.getSize(find.byKey(const Key('overview-streak'))).height,
        164,
      );
      expect(
        tester.getSize(find.byKey(const Key('overview-today'))).height,
        196,
      );
      expect(
        tester.getSize(find.byKey(const Key('overview-work-areas'))).height,
        120,
      );
      expect(
        tester.getSize(find.byKey(const Key('overview-statistics'))).height,
        168,
      );

      final workGoals = tester.getSize(
        find.byKey(const Key('compact-edit-goals-action')),
      );
      expect(workGoals.width, greaterThanOrEqualTo(48));
      expect(workGoals.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Start Focus')).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Log Work')).height,
        greaterThanOrEqualTo(48),
      );
    });
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
      greaterThanOrEqualTo(0),
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

  testWidgets('Overview actions and streak states expose clear semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpOverview(tester, const Size(390, 844));

      for (final label in const ['Start Focus', 'Log Work', 'Edit goals']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-work-areas')),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-streak')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.hint == 'Show streak details',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(': completed')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(': in progress')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('compact-today-pillar')),
          matching: find.bySemanticsLabel(RegExp('.+')),
        ),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
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

  for (final viewport in const [Size(600, 800), Size(640, 960)]) {
    testWidgets('narrow desktop uses compact desktop at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      await _pumpOverview(tester, viewport, platform: TargetPlatform.windows);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('overview-compact-desktop')), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  }

  for (final viewport in const [
    Size(768, 1024),
    Size(820, 1180),
    Size(839, 1024),
    Size(768, 700),
  ]) {
    testWidgets(
      'medium Overview is stable at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await _pumpOverview(tester, viewport, platform: TargetPlatform.windows);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('overview-medium')), findsOneWidget);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byKey(const Key('overview-medium-scroll')), findsNothing);
        expect(
          tester.getSize(find.byKey(const Key('overview-streak'))).height,
          154,
        );
        expect(
          tester.getSize(find.byKey(const Key('overview-today'))).height,
          260,
        );
        expect(
          tester.getSize(find.byKey(const Key('overview-work-areas'))).height,
          260,
        );
        expect(
          tester.getSize(find.byKey(const Key('overview-statistics'))).height,
          148,
        );
        expect(
          tester.getRect(find.byKey(const Key('overview-statistics'))).right,
          lessThanOrEqualTo(viewport.width - 24),
        );
        expect(
          tester.getSize(find.byKey(const Key('overview-actions'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('compact-edit-goals-action')))
              .shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('navigation-overview-selected')))
              .shortestSide,
          greaterThanOrEqualTo(48),
        );
      },
    );
  }

  testWidgets('medium Overview scrolls only when 200% text cannot fit', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(768, 1024),
      platform: TargetPlatform.windows,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    final fallback = find.byKey(
      const Key('overview-medium-accessibility-scroll'),
    );
    expect(fallback, findsOneWidget);
    final scrollable = find.descendant(
      of: fallback,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, 0);
    final scrollViewport = tester.getRect(scrollable);
    final statistics = tester.getRect(
      find.byKey(const Key('overview-statistics')),
    );
    expect(
      statistics.bottom,
      lessThanOrEqualTo(scrollViewport.bottom + position.maxScrollExtent),
    );
    expect(find.byTooltip('Edit goals'), findsOneWidget);
    final today = find.byKey(const Key('overview-today'));
    expect(
      find.descendant(of: today, matching: find.text('Start Focus')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: today, matching: find.text('Log Work')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('overview-actions'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('compact-edit-goals-action')))
          .shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('navigation-overview-selected')))
          .shortestSide,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('compact desktop matches the canonical 500x700 geometry', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(500, 700),
      platform: TargetPlatform.windows,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('overview-streak'))),
      const Rect.fromLTWH(88, 18, 396, 150),
    );
    expect(
      tester.getRect(find.byKey(const Key('overview-today'))),
      const Rect.fromLTWH(88, 180, 396, 190),
    );
    expect(
      tester.getRect(find.byKey(const Key('overview-work-areas'))),
      const Rect.fromLTWH(88, 382, 396, 110),
    );
    expect(
      tester.getRect(find.byKey(const Key('overview-statistics'))),
      const Rect.fromLTWH(88, 504, 396, 124),
    );
    final pillar = tester.getRect(
      find.byKey(const Key('compact-today-pillar')),
    );
    expect(pillar.left, closeTo(366, 0.01));
    expect(pillar.top, closeTo(206, 0.01));
    expect(pillar.width, closeTo(86, 0.01));
    expect(pillar.height, closeTo(112, 0.01));
    expect(
      tester.getSize(find.byKey(const Key('overview-actions'))),
      const Size(364, 48),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Start Focus')),
      const Size(178, 48),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Log Work')),
      const Size(178, 48),
    );
  });

  for (final viewport in const [
    Size(500, 700),
    Size(600, 700),
    Size(768, 700),
    Size(900, 700),
    Size(1024, 700),
  ]) {
    testWidgets(
      'desktop Overview is overflow-free at ${viewport.width.toInt()}x${viewport.height.toInt()}',
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
        for (final key in const [
          'overview-streak',
          'overview-today',
          'overview-work-areas',
          'overview-statistics',
        ]) {
          final bounds = tester.getRect(find.byKey(Key(key)));
          expect(bounds.left, greaterThanOrEqualTo(72));
          expect(bounds.right, lessThanOrEqualTo(viewport.width));
          expect(bounds.bottom, lessThanOrEqualTo(viewport.height));
        }
      },
    );
  }

  for (final width in const [500.0, 599.0, 600.0]) {
    testWidgets('desktop keeps lateral navigation at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpOverview(
        tester,
        Size(width, 700),
        platform: TargetPlatform.windows,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  }

  testWidgets('compact desktop scrolls when 500x600 cannot fit', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(500, 600),
      platform: TargetPlatform.windows,
    );

    expect(tester.takeException(), isNull);
    final fallback = find.byKey(const Key('overview-compact-desktop-scroll'));
    expect(fallback, findsOneWidget);
    final scrollable = find.descendant(
      of: fallback,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(
      tester.getSize(find.byKey(const Key('overview-streak'))).height,
      150,
    );
    expect(tester.getSize(find.byKey(const Key('overview-today'))).height, 190);
    expect(
      tester.getSize(find.byKey(const Key('overview-work-areas'))).height,
      110,
    );
    expect(
      tester.getSize(find.byKey(const Key('overview-statistics'))).height,
      124,
    );
  });

  testWidgets('compact desktop supports 200% text with scrolling', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(500, 700),
      platform: TargetPlatform.windows,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    final fallback = find.byKey(
      const Key('overview-compact-desktop-accessibility-scroll'),
    );
    expect(fallback, findsOneWidget);
    final scrollable = find.descendant(
      of: fallback,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    for (final finder in [
      find.widgetWithText(FilledButton, 'Start Focus'),
      find.widgetWithText(TextButton, 'Log Work'),
      find.byKey(const Key('compact-edit-goals-action')),
      find.byKey(const Key('navigation-overview-selected')),
    ]) {
      expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
    }
    expect(find.byKey(const Key('overview-statistics')), findsOneWidget);
  });

  testWidgets('599 remains Compact on mobile', (tester) async {
    await _pumpOverview(tester, const Size(599, 844));
    expect(find.byKey(const Key('overview-compact')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('600 enters Medium on mobile', (tester) async {
    await _pumpOverview(tester, const Size(600, 800));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('overview-medium')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('expanded desktop remains usable at 200% text scaling', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      const Size(1440, 900),
      platform: TargetPlatform.windows,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    final accessibilityScroll = find.byKey(
      const Key('overview-compact-desktop-accessibility-scroll'),
    );
    expect(accessibilityScroll, findsOneWidget);
    final scrollable = find.descendant(
      of: accessibilityScroll,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThanOrEqualTo(0),
    );
    for (final finder in [
      find.widgetWithText(FilledButton, 'Start Focus'),
      find.widgetWithText(TextButton, 'Log Work'),
      find.byTooltip('Edit goals'),
    ]) {
      expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('overview-statistics')),
      300,
      scrollable: scrollable,
    );
    expect(find.byKey(const Key('overview-statistics')), findsOneWidget);
  });

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
        final overviewScrollables = find.descendant(
          of: find.byType(OverviewPage),
          matching: find.byType(Scrollable),
        );
        expect(
          overviewScrollables,
          viewport == const Size(500, 600) ? findsOneWidget : findsNothing,
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
  EdgeInsets viewPadding = EdgeInsets.zero,
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
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
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
