import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/work_entry_providers.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/work_entries/domain/models/manual_work_entry.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/manual_work_entry_repository.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/special_activity_repository.dart';
import 'package:ponos_app/features/work_entries/presentation/state/manual_work_entries_controller.dart';
import 'package:ponos_app/features/work_entries/presentation/state/manual_work_entries_state.dart';
import 'package:ponos_app/features/work_entries/presentation/state/special_activities_controller.dart';
import 'package:ponos_app/features/work_entries/presentation/state/special_activities_state.dart';

void main() {
  group('SpecialActivitiesController', () {
    late FakeSpecialRepository repository;
    late ProviderContainer container;
    late SpecialActivitiesController controller;
    late List<SpecialActivitiesStatus> transitions;

    SpecialActivitiesState current() =>
        container.read(specialActivitiesProvider);
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      repository = FakeSpecialRepository();
      container = ProviderContainer(
        overrides: [
          specialActivityRepositoryProvider.overrideWithValue(repository),
        ],
      );
      transitions = [];
      container.listen(specialActivitiesProvider, (_, next) {
        transitions.add(next.status);
      }, fireImmediately: true);
      controller = container.read(specialActivitiesProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('loads activities, then refreshes to empty', () async {
      expect(current().status, SpecialActivitiesStatus.loading);
      await settle();
      expect(current().status, SpecialActivitiesStatus.loaded);
      expect(current().active.single.id, 1);
      repository.active = () async => [];
      expect(await controller.refresh(), isTrue);
      expect(current().status, SpecialActivitiesStatus.empty);
      expect(() => current().active.clear(), throwsUnsupportedError);
    });

    test('initial error can recover through refresh', () async {
      // A second container allows the initial request to be configured first.
      container.dispose();
      repository.active = () async => throw const NetworkException('offline');
      container = ProviderContainer(
        overrides: [
          specialActivityRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(specialActivitiesProvider, (_, _) {});
      controller = container.read(specialActivitiesProvider.notifier);
      await settle();
      expect(current().status, SpecialActivitiesStatus.error);
      repository.active = () async => [special(1)];
      expect(await controller.refresh(), isTrue);
      expect(current().status, SpecialActivitiesStatus.loaded);
      expect(current().error, isNull);
    });

    for (final action in ['create', 'update']) {
      test('$action saves to the list', () async {
        await settle();
        final pending = Completer<SpecialActivity>();
        repository.mutate = () => pending.future;
        final result = switch (action) {
          'create' => controller.create(
            SpecialActivityCreateInput(name: 'New'),
          ),
          'update' => controller.update(
            1,
            const SpecialActivityUpdateInput(name: 'Updated'),
          ),
          _ => throw StateError('Unexpected action'),
        };
        await settle();
        expect(current().status, SpecialActivitiesStatus.saving);
        expect(repository.lastAction, action);
        pending.complete(
          special(
            action == 'create' ? 3 : 1,
            name: action == 'update' ? 'Updated' : 'Activity',
          ),
        );
        expect(await result, isTrue);
        expect(current().status, SpecialActivitiesStatus.loaded);
        expect(current().error, isNull);
        expect(transitions, contains(SpecialActivitiesStatus.saving));
        if (action == 'update') {
          expect(current().active.single.name, 'Updated');
        } else {
          expect(current().active.map((a) => a.id), [1, 3]);
        }
      });

      test('$action failure retains lists and exposes error', () async {
        await settle();
        const error = ConflictException('failed');
        repository.mutate = () async => throw error;
        final result = switch (action) {
          'create' => controller.create(
            SpecialActivityCreateInput(name: 'New'),
          ),
          'update' => controller.update(
            1,
            const SpecialActivityUpdateInput(name: 'Updated'),
          ),
          _ => throw StateError('Unexpected action'),
        };
        expect(await result, isFalse);
        expect(current().status, SpecialActivitiesStatus.error);
        expect(current().error, same(error));
        expect(current().active.single.id, 1);
      });
    }

    test('deletion removes an activity and conflict retains it', () async {
      await settle();
      expect(await controller.delete(1), isTrue);
      expect(current().status, SpecialActivitiesStatus.empty);
      repository.active = () async => [special(1)];
      await controller.refresh();
      repository.failDelete = true;
      expect(await controller.delete(1), isFalse);
      expect(current().active.single.id, 1);
      expect(current().error, isA<ConflictException>());
    });

    test('failed refresh retains the list', () async {
      await settle();
      repository.active = () async => throw const ServerException('down');
      expect(await controller.refresh(), isFalse);
      expect(current().active.single.id, 1);
    });
  });

  group('ManualWorkEntriesController', () {
    late FakeManualRepository repository;
    late ProviderContainer container;
    late ManualWorkEntriesController controller;
    late List<ManualWorkEntriesStatus> transitions;

    ManualWorkEntriesState current() =>
        container.read(manualWorkEntriesProvider);
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      repository = FakeManualRepository();
      container = ProviderContainer(
        overrides: [
          manualWorkEntryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      transitions = [];
      container.listen(manualWorkEntriesProvider, (_, next) {
        transitions.add(next.status);
      }, fireImmediately: true);
      controller = container.read(manualWorkEntriesProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('loads, sorts, and refreshes to empty', () async {
      expect(current().status, ManualWorkEntriesStatus.loading);
      await settle();
      expect(current().entries.map((e) => e.id), [1, 2]);
      repository.load = () async => [];
      expect(await controller.refresh(), isTrue);
      expect(current().status, ManualWorkEntriesStatus.empty);
      expect(() => current().entries.clear(), throwsUnsupportedError);
    });

    test('initial error recovers on refresh', () async {
      container.dispose();
      repository.load = () async => throw const NetworkException('offline');
      container = ProviderContainer(
        overrides: [
          manualWorkEntryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(manualWorkEntriesProvider, (_, _) {});
      controller = container.read(manualWorkEntriesProvider.notifier);
      await settle();
      expect(current().status, ManualWorkEntriesStatus.error);
      repository.load = () async => [entry(1)];
      expect(await controller.refresh(), isTrue);
      expect(current().status, ManualWorkEntriesStatus.loaded);
    });

    for (final action in ['create', 'update', 'delete']) {
      test('$action saves and applies result', () async {
        await settle();
        final pending = Completer<void>();
        repository.mutate = () async {
          await pending.future;
          return entry(action == 'create' ? 3 : 1);
        };
        final result = switch (action) {
          'create' => controller.create(
            ManualWorkEntryCreateInput(
              focusAreaId: 1,
              workDate: DateTime(2026, 9, 19),
              focusedTime: const Duration(minutes: 1),
              restTime: Duration.zero,
            ),
          ),
          'update' => controller.update(
            1,
            const ManualWorkEntryUpdateInput(restTime: Duration(minutes: 2)),
          ),
          _ => controller.delete(1),
        };
        await settle();
        expect(current().status, ManualWorkEntriesStatus.saving);
        expect(repository.lastAction, action);
        pending.complete();
        expect(await result, isTrue);
        expect(current().status, ManualWorkEntriesStatus.loaded);
        expect(
          current().entries.map((e) => e.id),
          action == 'create'
              ? [1, 2, 3]
              : action == 'delete'
              ? [2]
              : [1, 2],
        );
        expect(transitions, contains(ManualWorkEntriesStatus.saving));
      });

      test('$action failure preserves entries', () async {
        await settle();
        const error = ValidationException('invalid');
        repository.mutate = () async => throw error;
        final result = switch (action) {
          'create' => controller.create(
            ManualWorkEntryCreateInput(
              focusAreaId: 1,
              workDate: DateTime(2026, 9, 19),
              focusedTime: const Duration(minutes: 1),
              restTime: Duration.zero,
            ),
          ),
          'update' => controller.update(
            1,
            const ManualWorkEntryUpdateInput(restTime: Duration(minutes: 2)),
          ),
          _ => controller.delete(1),
        };
        expect(await result, isFalse);
        expect(current().status, ManualWorkEntriesStatus.error);
        expect(current().error, same(error));
        expect(current().entries.map((e) => e.id), [1, 2]);
      });
    }

    test('refresh and save are serialized', () async {
      await settle();
      final pending = Completer<List<ManualWorkEntry>>();
      repository.load = () => pending.future;
      final refresh = controller.refresh();
      final save = controller.update(
        1,
        const ManualWorkEntryUpdateInput(restTime: Duration(minutes: 2)),
      );
      await settle();
      expect(repository.lastAction, isNull);
      pending.complete([entry(1)]);
      expect(await refresh, isTrue);
      expect(await save, isTrue);
    });
  });
}

SpecialActivity special(int id, {String name = 'Activity'}) =>
    SpecialActivity(id: id, name: name);

ManualWorkEntry entry(int id) => ManualWorkEntry(
  id: id,
  focusAreaId: 1,
  workDate: DateTime(2026, 9, 19),
  focusedTime: const Duration(minutes: 1),
  restTime: Duration.zero,
);

class FakeSpecialRepository implements SpecialActivityRepository {
  Future<List<SpecialActivity>> Function() active = () async => [special(1)];
  bool failDelete = false;
  Future<SpecialActivity> Function() mutate = () async => special(3);
  String? lastAction;

  @override
  Future<List<SpecialActivity>> getActive() => active();
  @override
  Future<SpecialActivity> getById(int id) => throw UnimplementedError();
  @override
  Future<SpecialActivity> create(SpecialActivityCreateInput input) {
    lastAction = 'create';
    return mutate();
  }

  @override
  Future<SpecialActivity> update(int id, SpecialActivityUpdateInput input) {
    lastAction = 'update';
    return mutate();
  }

  @override
  Future<void> delete(int id) async {
    lastAction = 'delete';
    if (failDelete) throw const ConflictException('Activity has recorded work');
  }
}

class FakeManualRepository implements ManualWorkEntryRepository {
  Future<List<ManualWorkEntry>> Function() load = () async => [
    entry(2),
    entry(1),
  ];
  Future<ManualWorkEntry> Function() mutate = () async => entry(3);
  String? lastAction;

  @override
  Future<List<ManualWorkEntry>> getAll() => load();
  @override
  Future<ManualWorkEntry> create(ManualWorkEntryCreateInput input) {
    lastAction = 'create';
    return mutate();
  }

  @override
  Future<ManualWorkEntry> update(int id, ManualWorkEntryUpdateInput input) {
    lastAction = 'update';
    return mutate();
  }

  @override
  Future<void> delete(int id) async {
    lastAction = 'delete';
    await mutate();
  }
}
