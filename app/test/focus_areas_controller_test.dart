import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_controller.dart';
import 'package:ponos_app/features/focus_areas/presentation/state/focus_areas_state.dart';

void main() {
  late FakeRepository repository;
  late ProviderContainer container;
  late FocusAreasController controller;
  late List<FocusAreasStatus> transitions;

  late bool started;
  void start() {
    if (started) return;
    started = true;
    container.listen(focusAreasProvider, (_, next) {
      transitions.add(next.status);
    }, fireImmediately: true);
    controller = container.read(focusAreasProvider.notifier);
  }

  Future<void> settle() {
    start();
    return Future<void>.delayed(Duration.zero);
  }

  FocusAreasState current() {
    start();
    return container.read(focusAreasProvider);
  }

  setUp(() {
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: [focusAreaRepositoryProvider.overrideWithValue(repository)],
    );
    transitions = [];
    started = false;
  });
  tearDown(() => container.dispose());

  test('initial loading resolves to a sorted loaded list', () async {
    final pending = Completer<List<FocusArea>>();
    repository.load = () => pending.future;
    expect(current().status, FocusAreasStatus.loading);
    await settle();
    pending.complete([area(2, priority: 2), area(1)]);
    await settle();
    expect(current().status, FocusAreasStatus.loaded);
    expect(current().areas.map((a) => a.id), [1, 2]);
    expect(() => current().areas.clear(), throwsUnsupportedError);
  });

  test('an empty response produces empty state', () async {
    repository.load = () async => [];
    await settle();
    expect(current().status, FocusAreasStatus.empty);
  });

  test('initial error is retained and refresh retries loading', () async {
    const error = NetworkException('offline');
    repository.load = () async => throw error;
    await settle();
    expect(current().status, FocusAreasStatus.error);
    expect(current().error, same(error));
    repository.load = () async => [area(1)];
    expect(await controller.refresh(), isTrue);
    expect(current().status, FocusAreasStatus.loaded);
    expect(current().error, isNull);
  });

  test(
    'refresh retains data while pending and replaces it on success',
    () async {
      await settle();
      final pending = Completer<List<FocusArea>>();
      repository.load = () => pending.future;
      final result = controller.refresh();
      await settle();
      expect(current().status, FocusAreasStatus.refreshing);
      expect(current().areas.single.id, 1);
      pending.complete([]);
      expect(await result, isTrue);
      expect(current().status, FocusAreasStatus.empty);
    },
  );

  test('refresh failure keeps existing data and can recover', () async {
    await settle();
    const error = ServerException('unavailable');
    repository.load = () async => throw error;
    expect(await controller.refresh(), isFalse);
    expect(current().status, FocusAreasStatus.error);
    expect(current().areas.single.id, 1);
    expect(current().error, same(error));
    repository.load = () async => [area(2)];
    expect(await controller.refresh(), isTrue);
    expect(current().areas.single.id, 2);
  });

  for (final action in ['create', 'update', 'archive', 'restore', 'reorder']) {
    Future<bool> invoke() => switch (action) {
      'create' => controller.create(
        FocusAreaCreateInput(
          name: 'New',
          priority: 1,
          targets: [
            FocusAreaTargetInput(
              weekday: 1,
              targetMinutes: 60,
              validFrom: DateTime(2026, 9, 7),
            ),
          ],
        ),
      ),
      'update' => controller.update(
        1,
        const FocusAreaUpdateInput(name: 'Updated'),
      ),
      'archive' => controller.archive(1),
      'restore' => controller.restore(2),
      _ => controller.reorder(const [
        FocusAreaPriorityInput(id: 1, priority: 2),
        FocusAreaPriorityInput(id: 2, priority: 2),
      ]),
    };

    test(
      '$action transitions through saving and applies server result',
      () async {
        await settle();
        final pending = Completer<List<FocusArea>>();
        repository.change = () => pending.future;
        final result = invoke();
        await settle();
        expect(current().status, FocusAreasStatus.saving);
        expect(current().areas.single.id, 1);
        expect(repository.lastAction, action);
        final changed = switch (action) {
          'archive' => [area(1, archived: true)],
          'update' => [area(1, name: 'Updated')],
          'reorder' => [area(2, priority: 2), area(1, priority: 2)],
          _ => [area(2)],
        };
        pending.complete(changed);
        expect(await result, isTrue);
        expect(
          current().status,
          action == 'archive'
              ? FocusAreasStatus.empty
              : FocusAreasStatus.loaded,
        );
        if (action == 'update') expect(current().areas.single.name, 'Updated');
        if (action == 'create' || action == 'restore' || action == 'reorder') {
          expect(current().areas.map((a) => a.id), [1, 2]);
        }
        if (action == 'reorder') {
          expect(repository.priorities!.map((a) => a.priority), [2, 2]);
        }
        expect(transitions, contains(FocusAreasStatus.saving));
        expect(current().error, isNull);
      },
    );

    test(
      '$action failure preserves data and exposes the repository error',
      () async {
        await settle();
        const error = ConflictException('conflict');
        repository.change = () async => throw error;
        expect(await invoke(), isFalse);
        expect(current().status, FocusAreasStatus.error);
        expect(current().error, same(error));
        expect(current().areas.single.id, 1);
        repository.change = () async => [area(1)];
        expect(await invoke(), isTrue);
        expect(current().error, isNull);
      },
    );
  }

  test(
    'refresh and mutation execute in order without losing the edit',
    () async {
      await settle();
      final pending = Completer<List<FocusArea>>();
      repository.load = () => pending.future;
      final refresh = controller.refresh();
      repository.change = () async => [area(1, name: 'Updated')];
      final save = controller.update(
        1,
        const FocusAreaUpdateInput(name: 'Updated'),
      );
      await settle();
      expect(repository.lastAction, isNull);
      pending.complete([area(1)]);
      expect(await refresh, isTrue);
      expect(await save, isTrue);
      expect(current().areas.single.name, 'Updated');
    },
  );

  test(
    'reorder is optimistic and restores the exact list on failure',
    () async {
      repository.load = () async => [
        area(1, priority: 1),
        area(2, priority: 2),
        area(3, priority: 3),
      ];
      await settle();
      final pending = Completer<List<FocusArea>>();
      repository.change = () => pending.future;

      final result = controller.reorder(const [
        FocusAreaPriorityInput(id: 3, priority: 1),
        FocusAreaPriorityInput(id: 1, priority: 2),
        FocusAreaPriorityInput(id: 2, priority: 3),
      ]);
      await settle();

      expect(current().status, FocusAreasStatus.saving);
      expect(current().areas.map((area) => area.id), [3, 1, 2]);
      expect(current().areas.map((area) => area.priority), [1, 2, 3]);

      pending.completeError(const ConflictException('priority conflict'));
      expect(await result, isFalse);
      expect(current().status, FocusAreasStatus.error);
      expect(current().areas.map((area) => area.id), [1, 2, 3]);
      expect(current().areas.map((area) => area.priority), [1, 2, 3]);
    },
  );

  test(
    'reorder forwards duplicate priorities without rejecting them',
    () async {
      repository.load = () async => [area(1), area(2), area(3)];
      await settle();
      repository.change = () async => [
        area(2, priority: 1),
        area(3, priority: 1),
        area(1, priority: 2),
      ];

      expect(
        await controller.reorder(const [
          FocusAreaPriorityInput(id: 2, priority: 1),
          FocusAreaPriorityInput(id: 3, priority: 1),
          FocusAreaPriorityInput(id: 1, priority: 2),
        ]),
        isTrue,
      );
      expect(repository.priorities!.map((item) => item.priority), [1, 1, 2]);
    },
  );

  test('disposal ignores a pending response', () async {
    await settle();
    final pending = Completer<List<FocusArea>>();
    repository.change = () => pending.future;
    final result = controller.archive(1);
    await settle();
    container.dispose();
    pending.complete([area(1, archived: true)]);
    expect(await result, isFalse);
    // Replace the container so tearDown only disposes a live instance.
    container = ProviderContainer();
  });
}

FocusArea area(
  int id, {
  int priority = 1,
  String name = 'Area',
  bool archived = false,
}) {
  final date = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: id,
    name: name,
    priority: priority,
    createdAt: date,
    updatedAt: date,
    archivedAt: archived ? date : null,
    targets: const [],
  );
}

class FakeRepository implements FocusAreaRepository {
  Future<List<FocusArea>> Function() load = () async => [area(1)];
  Future<List<FocusArea>> Function() change = () async => [area(2)];
  String? lastAction;
  List<FocusAreaPriorityInput>? priorities;

  @override
  Future<List<FocusArea>> getActive() => load();
  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) =>
      throw UnimplementedError();
  Future<FocusArea> mutate(String action) async {
    lastAction = action;
    return (await change()).single;
  }

  @override
  Future<FocusArea> create(FocusAreaCreateInput input) => mutate('create');
  @override
  Future<FocusArea> update(int id, FocusAreaUpdateInput input) =>
      mutate('update');
  @override
  Future<FocusArea> archive(int id) => mutate('archive');
  @override
  Future<FocusArea> restore(int id) => mutate('restore');
  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> values,
  ) {
    lastAction = 'reorder';
    priorities = values;
    return change();
  }

  @override
  Future<List<FocusArea>> getArchived() => throw UnimplementedError();
  @override
  Future<FocusArea> getById(int id) => throw UnimplementedError();
}
