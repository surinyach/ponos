import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/work_entry_providers.dart';
import '../../domain/models/manual_work_entry.dart';
import '../../domain/repositories/manual_work_entry_repository.dart';
import 'manual_work_entries_state.dart';

final manualWorkEntriesProvider =
    NotifierProvider<ManualWorkEntriesController, ManualWorkEntriesState>(
      ManualWorkEntriesController.new,
    );

class ManualWorkEntriesController extends Notifier<ManualWorkEntriesState> {
  late ManualWorkEntryRepository _repository;
  Future<void> _tail = Future<void>.value();
  bool _hasLoaded = false;

  @override
  ManualWorkEntriesState build() {
    _repository = ref.watch(manualWorkEntryRepositoryProvider);
    _tail = Future<void>.microtask(() async {
      if (ref.mounted) await _load();
    });
    return ManualWorkEntriesState(status: ManualWorkEntriesStatus.loading);
  }

  Future<bool> refresh() => _enqueue(_load);
  Future<bool> create(ManualWorkEntryCreateInput input) =>
      _save(() => _repository.create(input));
  Future<bool> update(int id, ManualWorkEntryUpdateInput input) =>
      _save(() => _repository.update(id, input));
  Future<bool> delete(int id) => _enqueue(() async {
    if (!_hasLoaded && !await _load()) return false;
    state = ManualWorkEntriesState(
      status: ManualWorkEntriesStatus.saving,
      entries: state.entries,
    );
    try {
      await _repository.delete(id);
      if (!ref.mounted) return false;
      _loaded(state.entries.where((entry) => entry.id != id));
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
    state = ManualWorkEntriesState(
      status: ManualWorkEntriesStatus.loading,
      entries: state.entries,
    );
    try {
      final entries = await _repository.getAll();
      if (!ref.mounted) return false;
      _hasLoaded = true;
      _loaded(entries);
      return true;
    } catch (error) {
      if (ref.mounted) _failed(error);
      return false;
    }
  }

  Future<bool> _save(Future<ManualWorkEntry> Function() operation) =>
      _enqueue(() async {
        if (!_hasLoaded && !await _load()) return false;
        state = ManualWorkEntriesState(
          status: ManualWorkEntriesStatus.saving,
          entries: state.entries,
        );
        try {
          final changed = await operation();
          if (!ref.mounted) return false;
          final entries = {for (final item in state.entries) item.id: item};
          entries[changed.id] = changed;
          _loaded(entries.values);
          return true;
        } catch (error) {
          if (ref.mounted) _failed(error);
          return false;
        }
      });

  void _loaded(Iterable<ManualWorkEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final date = b.workDate.compareTo(a.workDate);
        return date == 0 ? a.id.compareTo(b.id) : date;
      });
    state = ManualWorkEntriesState(
      status: sorted.isEmpty
          ? ManualWorkEntriesStatus.empty
          : ManualWorkEntriesStatus.loaded,
      entries: sorted,
    );
  }

  void _failed(Object error) {
    state = ManualWorkEntriesState(
      status: ManualWorkEntriesStatus.error,
      entries: state.entries,
      error: error,
    );
  }
}
