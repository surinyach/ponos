import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/focus_areas_page.dart';

void main() {
  testWidgets(
    'archive requires confirmation and restore returns area to active',
    (tester) async {
      final repository = FakeRepository(() async => [area(1, 'First', 1, 60)]);
      await pumpPage(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Archive First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.archivedIds, isEmpty);
      await tester.tap(find.byTooltip('Archive First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('No archived Focus Areas'), findsOneWidget);
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
    },
  );
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

    expect(find.text('Today · 3h across 2 areas'), findsOneWidget);
    expect(find.text('1h target today'), findsOneWidget);
    expect(find.text('2h target today'), findsOneWidget);
    expect(find.text('No target today'), findsOneWidget);
    final first = tester.getTopLeft(find.text('First')).dy;
    final second = tester.getTopLeft(find.text('Second')).dy;
    expect(first, lessThan(second));

    await tester.tap(find.text('New area'));
    await tester.tap(find.text('First'));
    expect(creates, 1);
    expect(selected?.id, 1);
  });

  testWidgets('uses a two-column grid on wide screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      FakeRepository(() async => [area(1, 'First', 1, 60)]),
    );
    await tester.pump();

    expect(find.byKey(const Key('focus-areas-grid')), findsOneWidget);
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
    expect(find.byKey(const Key('focus-areas-grid')), findsNothing);
  });

  testWidgets('shows drag handles for reordering on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [area(1, 'First', 1, 60), area(2, 'Second', 2, 60)],
    );
    await pumpPage(tester, repository);
    await tester.pump();

    await tester.tap(find.byKey(const Key('focus-areas-reorder-toggle')));
    await tester.pump();

    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    expect(find.byKey(const Key('move-down-1')), findsNothing);

    await tester.timedDrag(
      find.byType(ReorderableDragStartListener).first,
      const Offset(0, 220),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(repository.priorities!.map((item) => item.id), [2, 1]);
  });

  testWidgets('move buttons persist the new order on wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository(
      () async => [
        area(1, 'First', 1, 60),
        area(2, 'Second', 2, 60),
        area(3, 'Third', 3, 60),
      ],
    );
    await pumpPage(tester, repository);
    await tester.pump();

    await tester.tap(find.byKey(const Key('focus-areas-reorder-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-down-1')));
    await tester.pumpAndSettle();

    expect(repository.priorities!.map((item) => item.id), [2, 1, 3]);
    expect(repository.priorities!.map((item) => item.priority), [1, 2, 3]);
  });
}

Future<void> pumpPage(
  WidgetTester tester,
  FocusAreaRepository repository, {
  VoidCallback? onCreate,
  ValueChanged<FocusArea>? onSelected,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [focusAreaRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FocusAreasPage(
          today: DateTime(2026, 9, 7),
          onCreate: onCreate,
          onAreaSelected: onSelected,
        ),
      ),
    ),
  ),
);

FocusArea area(int id, String name, int priority, int? targetMinutes) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: id,
    name: name,
    priority: priority,
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

  @override
  Future<List<FocusArea>> getActive() => load();
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
