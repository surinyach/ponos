import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/focus_area_providers.dart';
import '../../domain/models/focus_area.dart';
import '../../domain/models/focus_area_input.dart';
import '../../domain/repositories/focus_area_repository.dart';
import 'focus_areas_state.dart';

final focusAreasProvider =
    NotifierProvider<FocusAreasController, FocusAreasState>(
      FocusAreasController.new,
    );

final archivedFocusAreasProvider = FutureProvider<List<FocusArea>>((ref) async {
  final areas = await ref.watch(focusAreaRepositoryProvider).getArchived();
  return areas.where((area) => area.isArchived).toList()..sort((a, b) {
    final priority = a.priority.compareTo(b.priority);
    return priority == 0 ? a.id.compareTo(b.id) : priority;
  });
});

/// Active Focus Areas only. Actions return false on failure or disposal.
/// Work is serialized, and failed operations preserve the last good list.
class FocusAreasController extends Notifier<FocusAreasState> {
  late FocusAreaRepository _repository;
  Future<void> _tail = Future<void>.value();
  bool _hasLoaded = false;

  @override
  FocusAreasState build() {
    _repository = ref.watch(focusAreaRepositoryProvider);
    // Starting asynchronously leaves the initial loading state observable.
    _tail = Future<void>.microtask(() async {
      if (ref.mounted) await _load();
    });
    return FocusAreasState(status: FocusAreasStatus.loading);
  }

  Future<bool> refresh() => _enqueue(_load);

  Future<bool> create(FocusAreaCreateInput input) =>
      _save(() async => [await _repository.create(input)]);

  Future<bool> update(int id, FocusAreaUpdateInput input) =>
      _save(() async => [await _repository.update(id, input)]);

  Future<bool> archive(int id) => _save(() async {
    final area = await _repository.archive(id);
    if (ref.mounted) ref.invalidate(archivedFocusAreasProvider);
    return [area];
  });

  Future<bool> restore(int id) => _save(() async {
    final area = await _repository.restore(id);
    if (ref.mounted) ref.invalidate(archivedFocusAreasProvider);
    return [area];
  });

  /// Accepts explicit priorities, including duplicates; ties use IDs.
  Future<bool> reorder(List<FocusAreaPriorityInput> priorities) {
    final snapshot = List<FocusAreaPriorityInput>.unmodifiable(priorities);
    return _enqueue(() async {
      if (!_hasLoaded && !await _load()) return false;

      final previous = state.areas;
      state = FocusAreasState(
        status: FocusAreasStatus.saving,
        areas: _applyPriorities(previous, snapshot),
      );
      try {
        final changed = await _repository.updatePriorities(snapshot);
        if (!ref.mounted) return false;
        final byId = {for (final area in previous) area.id: area};
        for (final area in changed) {
          byId[area.id] = area;
        }
        _loaded(byId.values);
        return true;
      } catch (error) {
        if (ref.mounted) {
          state = FocusAreasState(
            status: FocusAreasStatus.error,
            areas: previous,
            error: error,
          );
        }
        return false;
      }
    });
  }

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = _tail.then((_) async {
      if (!ref.mounted) return false;
      return operation();
    });
    _tail = result.then<void>((_) {});
    return result;
  }

  Future<bool> _load() async {
    state = FocusAreasState(
      status: _hasLoaded
          ? FocusAreasStatus.refreshing
          : FocusAreasStatus.loading,
      areas: state.areas,
    );
    try {
      final areas = await _repository.getActive();
      if (!ref.mounted) return false;
      _hasLoaded = true;
      _loaded(areas);
      return true;
    } catch (error) {
      if (ref.mounted) _failed(error);
      return false;
    }
  }

  Future<bool> _save(Future<List<FocusArea>> Function() operation) =>
      _enqueue(() async {
        // Retry a failed initial load before merging mutation results.
        if (!_hasLoaded && !await _load()) return false;
        state = FocusAreasState(
          status: FocusAreasStatus.saving,
          areas: state.areas,
        );
        try {
          final changed = await operation();
          if (!ref.mounted) return false;
          final byId = {for (final area in state.areas) area.id: area};
          for (final area in changed) {
            if (area.isArchived) {
              byId.remove(area.id);
            } else {
              byId[area.id] = area;
            }
          }
          _loaded(byId.values);
          return true;
        } catch (error) {
          if (ref.mounted) _failed(error);
          return false;
        }
      });

  void _loaded(Iterable<FocusArea> areas) {
    final sorted = areas.where((area) => !area.isArchived).toList()
      ..sort((a, b) {
        final priority = a.priority.compareTo(b.priority);
        return priority == 0 ? a.id.compareTo(b.id) : priority;
      });
    state = FocusAreasState(
      status: sorted.isEmpty ? FocusAreasStatus.empty : FocusAreasStatus.loaded,
      areas: sorted,
    );
  }

  void _failed(Object error) {
    state = FocusAreasState(
      status: FocusAreasStatus.error,
      areas: state.areas,
      error: error,
    );
  }

  List<FocusArea> _applyPriorities(
    List<FocusArea> areas,
    List<FocusAreaPriorityInput> priorities,
  ) {
    final byId = {for (final area in areas) area.id: area};
    final reordered = <FocusArea>[];
    for (final item in priorities) {
      final area = byId.remove(item.id);
      if (area != null) reordered.add(_withPriority(area, item.priority));
    }
    reordered.addAll(byId.values);
    return reordered;
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
}
