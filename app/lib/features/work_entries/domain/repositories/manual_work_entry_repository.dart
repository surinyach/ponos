import '../models/manual_work_entry.dart';

abstract interface class ManualWorkEntryRepository {
  Future<List<ManualWorkEntry>> getAll();
  Future<ManualWorkEntry> create(ManualWorkEntryCreateInput input);
  Future<ManualWorkEntry> update(int id, ManualWorkEntryUpdateInput input);
  Future<void> delete(int id);
}
