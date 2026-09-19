import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/work_entry_providers.dart';
import '../../domain/models/special_activity.dart';
import '../../domain/repositories/special_activity_repository.dart';
import 'special_activities_state.dart';

final specialActivitiesProvider =
    NotifierProvider<SpecialActivitiesController, SpecialActivitiesState>(
      SpecialActivitiesController.new,
    );

class SpecialActivitiesController extends Notifier<SpecialActivitiesState> {
  late SpecialActivityRepository _repository;
  Future<void> _tail = Future<void>.value();
  bool _hasLoaded = false;

  @override
  SpecialActivitiesState build() {
    _repository = ref.watch(specialActivityRepositoryProvider);
    _tail = Future<void>.microtask(() async {
      if (ref.mounted) await _load();
    });
    return SpecialActivitiesState(status: SpecialActivitiesStatus.loading);
  }

  Future<bool> refresh() => _enqueue(_load);
  Future<bool> create(SpecialActivityCreateInput input) async =>
      await createAndReturn(input) != null;

  /// Returns the newly created activity.
  Future<SpecialActivity?> createAndReturn(
    SpecialActivityCreateInput input,
  ) async {
    SpecialActivity? created;
    final success = await _save(() async {
      created = await _repository.create(input);
      return created!;
    });
    return success ? created : null;
  }

  Future<bool> update(int id, SpecialActivityUpdateInput input) =>
      _save(() => _repository.update(id, input));
  Future<bool> archive(int id) => _save(() => _repository.archive(id));
  Future<bool> restore(int id) => _save(() => _repository.restore(id));

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = _tail.then((_) async {
      if (!ref.mounted) return false;
      return operation();
    });
    _tail = result.then<void>((_) {});
    return result;
  }

  Future<bool> _load() async {
    state = SpecialActivitiesState(
      status: SpecialActivitiesStatus.loading,
      active: state.active,
      archived: state.archived,
    );
    try {
      final active = await _repository.getActive();
      final archived = await _repository.getArchived();
      if (!ref.mounted) return false;
      _hasLoaded = true;
      _loaded(active, archived);
      return true;
    } catch (error) {
      if (ref.mounted) _failed(error);
      return false;
    }
  }

  Future<bool> _save(Future<SpecialActivity> Function() operation) =>
      _enqueue(() async {
        if (!_hasLoaded && !await _load()) return false;
        state = SpecialActivitiesState(
          status: SpecialActivitiesStatus.saving,
          active: state.active,
          archived: state.archived,
        );
        try {
          final changed = await operation();
          if (!ref.mounted) return false;
          final active = {for (final item in state.active) item.id: item};
          final archived = {for (final item in state.archived) item.id: item};
          active.remove(changed.id);
          archived.remove(changed.id);
          (changed.isArchived ? archived : active)[changed.id] = changed;
          _loaded(active.values, archived.values);
          return true;
        } catch (error) {
          if (ref.mounted) _failed(error);
          return false;
        }
      });

  void _loaded(
    Iterable<SpecialActivity> active,
    Iterable<SpecialActivity> archived,
  ) {
    final activeList = active.toList()..sort(_byId);
    final archivedList = archived.toList()..sort(_byId);
    state = SpecialActivitiesState(
      status: activeList.isEmpty && archivedList.isEmpty
          ? SpecialActivitiesStatus.empty
          : SpecialActivitiesStatus.loaded,
      active: activeList,
      archived: archivedList,
    );
  }

  int _byId(SpecialActivity a, SpecialActivity b) => a.id.compareTo(b.id);

  void _failed(Object error) {
    state = SpecialActivitiesState(
      status: SpecialActivitiesStatus.error,
      active: state.active,
      archived: state.archived,
      error: error,
    );
  }
}
