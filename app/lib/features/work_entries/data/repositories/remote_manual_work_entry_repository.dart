import '../../domain/models/manual_work_entry.dart';
import '../../domain/repositories/manual_work_entry_repository.dart';
import '../data_sources/work_entries_api_client.dart';
import '../dtos/manual_work_entry_dto.dart';

class RemoteManualWorkEntryRepository implements ManualWorkEntryRepository {
  const RemoteManualWorkEntryRepository(this._apiClient);

  final WorkEntriesApiClient _apiClient;

  @override
  Future<List<ManualWorkEntry>> getAll() async =>
      (await _apiClient.getManualWorkEntries())
          .map((value) => value.toDomain())
          .toList(growable: false);
  @override
  Future<ManualWorkEntry> create(ManualWorkEntryCreateInput input) async =>
      (await _apiClient.createManualWorkEntry(
        ManualWorkEntryDto.createToJson(input),
      )).toDomain();
  @override
  Future<ManualWorkEntry> update(
    int id,
    ManualWorkEntryUpdateInput input,
  ) async => (await _apiClient.updateManualWorkEntry(
    id,
    ManualWorkEntryDto.updateToJson(input),
  )).toDomain();
  @override
  Future<void> delete(int id) => _apiClient.deleteManualWorkEntry(id);
}
