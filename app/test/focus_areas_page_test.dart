import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/theme/app_breakpoints.dart';
import 'package:ponos_app/app/theme/app_priority_colors.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/focus_areas_page.dart';
import 'package:ponos_app/features/focus_areas/presentation/work_areas_page.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_state.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';

void main() {
  testWidgets(
    'archive requires confirmation and restore returns area to active',
    (tester) async {
      final repository = FakeRepository(() async => [area(1, 'First', 1, 60)]);
      await pumpPage(tester, repository);
      await tester.pumpAndSettle();
      await _openArchiveDialog(tester, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.archivedIds, isEmpty);
      await _openArchiveDialog(tester, 1);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      await pumpPage(tester, repository, archived: true);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await _openArchivedActionMenu(tester, 1);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('No archived Focus Areas'), findsOneWidget);
    },
  );
  testWidgets(
    'permanently deletes archived area without work after one confirmation',
    (tester) async {
      final repository = FakeRepository(() async => [area(1, 'First', 1, 60)])
        ..archivedIds.add(1);
      await pumpPage(tester, repository, archived: true);
      await tester.pumpAndSettle();
      await _openArchivedActionMenu(tester, 1);
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, 1);
      expect(repository.deletionConfirmation, isFalse);
      expect(find.text('No archived Focus Areas'), findsOneWidget);
    },
  );

  testWidgets('requires a second warning before deleting historical work', (
    tester,
  ) async {
    final repository = FakeRepository(() async => [area(1, 'First', 1, 60)])
      ..archivedIds.add(1)
      ..historicalWork = true;
    await pumpPage(tester, repository, archived: true);
    await tester.pumpAndSettle();
    await _openArchivedActionMenu(tester, 1);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Delete historical work too?'), findsOneWidget);
    expect(repository.deletedId, isNull);
    await tester.tap(find.text('Delete all permanently'));
    await tester.pumpAndSettle();
    expect(repository.deletedId, 1);
    expect(repository.deletionConfirmation, isTrue);
  });

  testWidgets('blocks deletion while the Focus Area timer is paused', (
    tester,
  ) async {
    final repository = FakeRepository(() async => [area(1, 'First', 1, 60)])
      ..archivedIds.add(1);
    await pumpPage(
      tester,
      repository,
      activeTimerFocusAreaId: 1,
      archived: true,
    );
    await tester.pumpAndSettle();
    await _openArchivedActionMenu(tester, 1);
    await tester.tap(find.text('Delete unavailable'));
    await tester.pump();

    expect(
      find.text(
        'This Focus Area cannot be deleted while its timer is active or paused.',
      ),
      findsOneWidget,
    );
    expect(repository.deletedId, isNull);
  });
  testWidgets('shows loading while the repository request is pending', (
    tester,
  ) async {
    final pending = Completer<List<FocusArea>>();
    await pumpPage(tester, FakeRepository(() => pending.future));

    expect(find.byKey(const Key('focus-areas-loading')), findsOneWidget);
  });

  testWidgets('keeps archived loading and error states inside its page', (
    tester,
  ) async {
    final pending = Completer<List<FocusArea>>();
    final loadingRepository = FakeRepository(() async => [])
      ..archivedLoad = () => pending.future;
    await pumpPage(tester, loadingRepository, archived: true);
    await tester.pump();

    expect(find.text('Archived Focus Areas'), findsOneWidget);
    expect(
      find.byKey(const Key('archived-focus-areas-loading')),
      findsOneWidget,
    );

    final errorRepository = FakeRepository(() async => [])
      ..archivedLoad = () async => throw const NetworkException('Offline');
    await pumpPage(tester, errorRepository, archived: true);
    await tester.pumpAndSettle();

    expect(find.text('Archived Focus Areas'), findsOneWidget);
    expect(find.text('Unable to load archived Focus Areas'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('shows the empty state and create action', (tester) async {
    var creates = 0;
    await pumpPage(
      tester,
      FakeRepository(() async => []),
      onCreate: () => creates++,
    );
    await tester.pump();

    expect(find.text('No Focus Areas yet'), findsOneWidget);
    await tester.tap(find.text('Create Focus Area'));
    expect(creates, 1);
  });

  testWidgets('shows an initial error and retries', (tester) async {
    var attempts = 0;
    final repository = FakeRepository(() async {
      attempts++;
      if (attempts == 1) throw const NetworkException('Server unavailable');
      return [area(1, 'Recovered', 1, 60)];
    });
    await pumpPage(tester, repository);
    await tester.pump();

    expect(find.text('Unable to load Focus Areas'), findsOneWidget);
    expect(find.text('Server unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recovered'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('orders rows, summarizes targets, and exposes callbacks', (
    tester,
  ) async {
    var creates = 0;
    FocusArea? selected;
    await pumpPage(
      tester,
      FakeRepository(
        () async => [
          area(2, 'Second', 2, 120),
          area(1, 'First', 1, 60),
          area(3, 'Unscheduled', 3, null),
        ],
      ),
      onCreate: () => creates++,
      onSelected: (area) => selected = area,
    );
    await tester.pump();

    expect(find.text('3h 00m'), findsOneWidget);
    expect(find.text('1h 00m today'), findsOneWidget);
    expect(find.text('2h 00m today'), findsOneWidget);
    expect(find.text('No target today'), findsOneWidget);
    final first = tester.getTopLeft(find.text('First')).dy;
    final second = tester.getTopLeft(find.text('Second')).dy;
    expect(first, lessThan(second));

    await tester.tap(find.text('New Focus Area'));
    await tester.tap(find.text('First'));
    expect(creates, 1);
    expect(selected?.id, 1);
  });

  testWidgets('uses the approved table on expanded screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(
        () async => [
          area(1, 'First', 1, 60),
          area(2, 'Second', 2, 60),
          area(10, 'Tenth', 10, 60),
          area(100, 'Hundredth', 100, 60),
        ],
      ),
      layout: AppLayoutSize.expanded,
    );
    await tester.pump();

    expect(find.byKey(const Key('focus-areas-table')), findsOneWidget);
    expect(find.byKey(const Key('focus-areas-list')), findsNothing);
    final nameLefts = <double>[];
    for (final entry in const [
      (priority: 1, name: 'First'),
      (priority: 2, name: 'Second'),
      (priority: 10, name: 'Tenth'),
      (priority: 100, name: 'Hundredth'),
    ]) {
      final badge = tester.getRect(
        find.byKey(Key('priority-badge-${entry.priority}')),
      );
      final name = tester.getRect(find.text(entry.name));
      expect(
        name.left - badge.right,
        greaterThanOrEqualTo(12),
        reason: 'P${entry.priority}: badge=$badge name=$name',
      );
      nameLefts.add(name.left);
    }
    expect(nameLefts.toSet(), hasLength(1));
    expect(
      tester.getSize(find.byKey(const Key('priority-badge-1'))),
      const Size(32, 32),
    );
    expect(
      tester.getSize(find.byKey(const Key('priority-badge-100'))).width,
      greaterThan(32),
    );
  });

  testWidgets('uses a single list on mobile screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(() async => [area(1, 'First', 1, 60)]),
    );
    await tester.pump();

    expect(find.byKey(const Key('focus-areas-list')), findsOneWidget);
    expect(find.byKey(const Key('focus-areas-table')), findsNothing);
  });

  testWidgets('expanded priority badges stay compact at 200% text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(() async => [area(100, 'Hundredth', 100, 60)]),
      layout: AppLayoutSize.expanded,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    final badge = tester.getRect(
      find.byKey(const Key('priority-badge-100')),
    );
    final name = tester.getRect(find.text('Hundredth'));
    expect(name.left - badge.right, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses priority-colored cards for archived compact layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [
        area(
          6,
          'Long-term area',
          6,
          60,
          description: 'An archived description',
          targetEndDate: DateTime(2026, 8, 31),
        ),
      ],
    )..archivedIds.add(6);

    await pumpPage(
      tester,
      repository,
      archived: true,
      layout: AppLayoutSize.compact,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archived-focus-areas-list')), findsOneWidget);
    expect(find.text('P6'), findsOneWidget);
    expect(find.text('An archived description'), findsOneWidget);
    expect(find.text('Finished: 31 Aug 2026'), findsOneWidget);
    final badge = tester.widget<Container>(
      find.byKey(const Key('priority-badge-6')),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, AppPriorityColors.p5AndHigher.background);
    expect(
      decoration.border,
      Border.all(color: AppPriorityColors.p5AndHigher.border),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting an archived card opens its details callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final archivedArea = area(6, 'Archived details', 2, 60);
    final repository = FakeRepository(() async => [archivedArea])
      ..archivedIds.add(6);
    FocusArea? selected;

    await pumpPage(
      tester,
      repository,
      archived: true,
      layout: AppLayoutSize.compact,
      onArchivedSelected: (area) => selected = area,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived details'));

    expect(selected?.id, 6);
  });

  testWidgets('uses the archived table on expanded layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [area(1, 'Archived area', 1, 60)],
    )..archivedIds.add(1);

    await pumpPage(
      tester,
      repository,
      archived: true,
      layout: AppLayoutSize.expanded,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archived-focus-areas-table')), findsOneWidget);
    expect(find.text('Finish Date'), findsOneWidget);
    expect(find.text('Archived At'), findsOneWidget);
    expect(find.text('Total Time'), findsNothing);
    expect(find.byTooltip('Restore Archived area'), findsOneWidget);
    expect(find.byTooltip('Permanently delete Archived area'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('priority-badge-1'))),
      const Size(32, 32),
    );
  });

  testWidgets('active and archived tables share the same foreground outline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [area(1, 'Focus Area', 1, 60)],
    )..archivedIds.add(1);

    await pumpPage(
      tester,
      repository,
      layout: AppLayoutSize.expanded,
    );
    await tester.pumpAndSettle();
    final active = tester.widget<Container>(
      find.byKey(const Key('focus-areas-table')),
    );
    final activeOutline = active.foregroundDecoration! as BoxDecoration;

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage(
      tester,
      repository,
      archived: true,
      layout: AppLayoutSize.expanded,
    );
    await tester.pumpAndSettle();
    final archived = tester.widget<Container>(
      find.byKey(const Key('archived-focus-areas-table')),
    );
    final archivedOutline = archived.foregroundDecoration! as BoxDecoration;

    expect(archivedOutline.border, activeOutline.border);
    expect(archivedOutline.borderRadius, activeOutline.borderRadius);
    expect(archived.child, isA<ClipRRect>());
  });

  testWidgets('archived mobile cards use 16px page and internal insets', (
    tester,
  ) async {
    final repository = FakeRepository(
      () async => [
        area(
          100,
          'A long archived Focus Area name that wraps naturally',
          100,
          60,
          description:
              'A long optional description that is allowed to wrap naturally.',
        ),
      ],
    )..archivedIds.add(100);

    await pumpWorkAreas(tester, repository, const Size(390, 844));
    await tester.tap(find.byKey(const Key('view-archived-focus-areas')));
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find.byKey(const Key('archived-focus-area-card-100')),
    );
    final badge = tester.getRect(find.byKey(const Key('priority-badge-100')));
    expect(card.left, 16);
    expect(card.right, 390 - 16);
    expect(badge.left - card.left, 16);
    expect(badge.height, 32);
    expect(badge.width, greaterThan(32));
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(320, 568),
    Size(500, 700),
    Size(768, 1024),
  ]) {
    testWidgets(
      'archived cards remain overflow free at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        final repository = FakeRepository(
          () async => [
            area(
              100,
              'A long archived Focus Area name that wraps naturally',
              100,
              60,
              description:
                  'A long optional description that is allowed to wrap naturally.',
            ),
          ],
        )..archivedIds.add(100);

        await pumpWorkAreas(tester, repository, viewport);
        await tester.tap(find.byKey(const Key('view-archived-focus-areas')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('archived-focus-area-card-100')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('archived cards remain usable at 200% text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [
        area(
          1,
          'Archived area with a long name',
          1,
          60,
          description: 'A longer description that remains reachable',
        ),
      ],
    )..archivedIds.add(1);

    await pumpPage(
      tester,
      repository,
      archived: true,
      layout: AppLayoutSize.compact,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    final actions = tester.getRect(
      find.byKey(const Key('archived-focus-area-menu-1')),
    );
    expect(actions.height, greaterThanOrEqualTo(48));
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not expose priority-mutating reorder controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(
        () async => [area(1, 'First', 1, 60), area(2, 'Second', 2, 60)],
      ),
    );
    await tester.pump();

    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.byKey(const Key('focus-areas-reorder-toggle')), findsNothing);
    expect(find.byKey(const Key('move-down-1')), findsNothing);
  });

  testWidgets('shows warning and danger expiration states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(
        () async => [
          area(
            1,
            'Recently expired',
            1,
            60,
            targetEndDate: DateTime(2026, 9, 1),
          ),
          area(2, 'Long expired', 2, 60, targetEndDate: DateTime(2026, 8, 20)),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Expired 6 days ago'), findsOneWidget);
    expect(find.text('Expired 18 days ago'), findsOneWidget);
    expect(find.text('No target today'), findsNWidgets(2));

    final recentlyExpiredBadge = tester.widget<Container>(
      find.byKey(const Key('priority-badge-1')),
    );
    final badgeDecoration = recentlyExpiredBadge.decoration! as BoxDecoration;
    expect(badgeDecoration.color, AppPriorityColors.p1.background);
  });

  for (final viewport in const [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
    Size(500, 600),
    Size(500, 700),
    Size(600, 800),
    Size(768, 700),
    Size(768, 1024),
    Size(839, 1024),
    Size(1024, 700),
    Size(1440, 900),
  ]) {
    testWidgets(
      'active Work Areas remain usable at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await pumpWorkAreas(
          tester,
          FakeRepository(
            () async => [
              area(1, 'First priority area', 1, 60),
              area(2, 'Second priority area', 2, 90),
            ],
          ),
          viewport,
        );

        await tester.ensureVisible(find.text('First priority area'));
        expect(find.byKey(const Key('new-focus-area')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('maps every priority from P5 onward to the same sage tier', () {
    expect(AppPriorityColors.forPriority(1), same(AppPriorityColors.p1));
    expect(AppPriorityColors.forPriority(2), same(AppPriorityColors.p2));
    expect(AppPriorityColors.forPriority(3), same(AppPriorityColors.p3));
    expect(AppPriorityColors.forPriority(4), same(AppPriorityColors.p4));
    expect(
      AppPriorityColors.forPriority(5),
      same(AppPriorityColors.p5AndHigher),
    );
    expect(
      AppPriorityColors.forPriority(37),
      same(AppPriorityColors.p5AndHigher),
    );
    expect(AppPriorityColors.p1.background, const Color(0xFFFFB4B8));
    expect(AppPriorityColors.p5AndHigher.foreground, const Color(0xFF3E5642));
  });
}

Future<void> _openArchiveDialog(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('focus-area-menu-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Archive'));
  await tester.pumpAndSettle();
}

Future<void> _openArchivedActionMenu(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('archived-focus-area-menu-$id')));
  await tester.pumpAndSettle();
}

Future<void> pumpWorkAreas(
  WidgetTester tester,
  FocusAreaRepository repository,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        focusAreaRepositoryProvider.overrideWithValue(repository),
        focusTimerProvider.overrideWith(() => TestFocusTimerController(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: PonosViewportScope(
          size: size,
          child: WorkAreasPage(
            onCreateFocusArea: () {},
            onCreateSpecialActivity: () {},
            onFocusAreaSelected: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpPage(
  WidgetTester tester,
  FocusAreaRepository repository, {
  VoidCallback? onCreate,
  ValueChanged<FocusArea>? onSelected,
  ValueChanged<FocusArea>? onArchivedSelected,
  int? activeTimerFocusAreaId,
  bool archived = false,
  AppLayoutSize? layout,
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      focusAreaRepositoryProvider.overrideWithValue(repository),
      focusTimerProvider.overrideWith(
        () => TestFocusTimerController(activeTimerFocusAreaId),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: FocusAreasPage(
          archived: archived,
          layout: layout,
          today: DateTime(2026, 9, 7),
          onCreate: onCreate,
          onAreaSelected: onSelected,
          onArchivedAreaSelected: onArchivedSelected,
        ),
      ),
    ),
  ),
);

class TestFocusTimerController extends FocusTimerController {
  TestFocusTimerController(this.focusAreaId);
  final int? focusAreaId;

  @override
  FocusTimerState build() {
    if (focusAreaId == null) return const FocusTimerState.inactive();
    return FocusTimerState(
      status: FocusTimerStatus.paused,
      activeTimer: ActiveFocusTimer(
        focusAreaId: focusAreaId,
        workDate: DateTime(2026, 9, 21),
        startedAt: DateTime.utc(2026, 9, 21, 8),
        startedAtUtcOffset: const Duration(hours: 2),
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
        phase: FocusTimerPhase.focus,
        activity: FocusTimerActivity.paused,
        accumulatedFocusTime: const Duration(minutes: 2),
        accumulatedRestTime: Duration.zero,
        focusTransitionNotified: false,
      ),
    );
  }
}

FocusArea area(
  int id,
  String name,
  int priority,
  int? targetMinutes, {
  String? description,
  DateTime? targetEndDate,
}) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: id,
    name: name,
    description: description,
    priority: priority,
    targetEndDate: targetEndDate,
    createdAt: timestamp,
    updatedAt: timestamp,
    targets: targetMinutes == null
        ? const []
        : [
            FocusAreaTarget(
              id: id,
              focusAreaId: id,
              weekday: DateTime.monday,
              targetMinutes: targetMinutes,
              validFrom: DateTime(2026, 9, 7),
            ),
          ],
  );
}

class FakeRepository implements FocusAreaRepository {
  FakeRepository(this.load);
  final Future<List<FocusArea>> Function() load;
  List<FocusAreaPriorityInput>? priorities;
  final archivedIds = <int>{};
  bool historicalWork = false;
  int? deletedId;
  bool? deletionConfirmation;
  Future<List<FocusArea>> Function()? archivedLoad;

  @override
  Future<bool> hasHistoricalWork(int id) async => historicalWork;

  @override
  Future<void> permanentlyDelete(
    int id, {
    required bool confirmHistoricalWork,
  }) async {
    deletedId = id;
    deletionConfirmation = confirmHistoricalWork;
    archivedIds.remove(id);
  }

  @override
  Future<List<FocusArea>> getActive() => load();
  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) =>
      throw UnimplementedError();
  @override
  Future<FocusArea> archive(int id) async {
    archivedIds.add(id);
    final original = (await load()).firstWhere((area) => area.id == id);
    return FocusArea(
      id: original.id,
      name: original.name,
      description: original.description,
      priority: original.priority,
      targetEndDate: original.targetEndDate,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      targets: original.targets,
      archivedAt: DateTime.now(),
    );
  }

  @override
  Future<FocusArea> create(FocusAreaCreateInput input) =>
      throw UnimplementedError();
  @override
  Future<List<FocusArea>> getArchived() async {
    final customLoad = archivedLoad;
    if (customLoad != null) return customLoad();
    return [for (final id in archivedIds.toList()) await archive(id)];
  }

  @override
  Future<FocusArea> getById(int id) => throw UnimplementedError();
  @override
  Future<FocusArea> restore(int id) async {
    archivedIds.remove(id);
    return (await load()).firstWhere((area) => area.id == id);
  }

  @override
  Future<FocusArea> update(int id, FocusAreaUpdateInput input) =>
      throw UnimplementedError();
  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> values,
  ) async {
    priorities = values;
    final byId = {for (final item in await load()) item.id: item};
    return [
      for (final value in values)
        _withPriority(byId[value.id]!, value.priority),
    ];
  }
}

FocusArea _withPriority(FocusArea area, int priority) => FocusArea(
  id: area.id,
  name: area.name,
  description: area.description,
  priority: priority,
  targetEndDate: area.targetEndDate,
  archivedAt: area.archivedAt,
  createdAt: area.createdAt,
  updatedAt: area.updatedAt,
  targets: area.targets,
);
