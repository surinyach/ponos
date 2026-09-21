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
  Future<bool> delete(int id) => _enqueue(() async {
    if (!_hasLoaded && !await _load()) return false;
    state = SpecialActivitiesState(
      status: SpecialActivitiesStatus.saving,
      active: state.active,
    );
    try {
      await _repository.delete(id);
      if (!ref.mounted) return false;
      _loaded(state.active.where((activity) => activity.id != id));
      return true;
    } catch (error) {
      if (ref.mounted) _failed(error);
      return false;
    }
  });

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
    );
    try {
      final active = await _repository.getActive();
      if (!ref.mounted) return false;
      _hasLoaded = true;
      _loaded(active);
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
        );
        try {
          final changed = await operation();
          if (!ref.mounted) return false;
          final active = {for (final item in state.active) item.id: item};
          active.remove(changed.id);
          active[changed.id] = changed;
          _loaded(active.values);
          return true;
        } catch (error) {
          if (ref.mounted) _failed(error);
          return false;
        }
      });

  void _loaded(Iterable<SpecialActivity> active) {
    final activeList = active.toList()..sort(_byId);
    state = SpecialActivitiesState(
      status: activeList.isEmpty
          ? SpecialActivitiesStatus.empty
          : SpecialActivitiesStatus.loaded,
      active: activeList,
    );
  }

  int _byId(SpecialActivity a, SpecialActivity b) => a.id.compareTo(b.id);

  void _failed(Object error) {
    state = SpecialActivitiesState(
      status: SpecialActivitiesStatus.error,
      active: state.active,
      error: error,
    );
  }
}
