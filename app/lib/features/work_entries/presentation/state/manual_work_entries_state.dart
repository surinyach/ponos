import '../../domain/models/manual_work_entry.dart';

enum ManualWorkEntriesStatus { loading, loaded, empty, saving, error }

class ManualWorkEntriesState {
  ManualWorkEntriesState({
    required this.status,
    List<ManualWorkEntry> entries = const [],
    this.error,
  }) : entries = List.unmodifiable(entries);

  final ManualWorkEntriesStatus status;
  final List<ManualWorkEntry> entries;
  final Object? error;
}
