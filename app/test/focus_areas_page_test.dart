import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/theme/app_breakpoints.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/focus_areas_page.dart';
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
      await tester.tap(find.byTooltip('Permanently delete First'));
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
    await tester.tap(find.byTooltip('Permanently delete First'));
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
    await tester.tap(
      find.byTooltip('Cannot delete while this area has an active timer'),
    );
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
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(() async => [area(1, 'First', 1, 60)]),
      layout: AppLayoutSize.expanded,
    );
    await tester.pump();

    expect(find.byKey(const Key('focus-areas-table')), findsOneWidget);
    expect(find.byKey(const Key('focus-areas-list')), findsNothing);
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
  });
}

Future<void> _openArchiveDialog(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('focus-area-menu-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Archive'));
  await tester.pumpAndSettle();
}

Future<void> pumpPage(
  WidgetTester tester,
  FocusAreaRepository repository, {
  VoidCallback? onCreate,
  ValueChanged<FocusArea>? onSelected,
  int? activeTimerFocusAreaId,
  bool archived = false,
  AppLayoutSize? layout,
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
      home: Scaffold(
        body: FocusAreasPage(
          archived: archived,
          layout: layout,
          today: DateTime(2026, 9, 7),
          onCreate: onCreate,
          onAreaSelected: onSelected,
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
  DateTime? targetEndDate,
}) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: id,
    name: name,
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
      priority: original.priority,
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
  Future<List<FocusArea>> getArchived() async => [
    for (final id in archivedIds.toList()) await archive(id),
  ];
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
