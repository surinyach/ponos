import '../../domain/models/special_activity.dart';
import '../../domain/repositories/special_activity_repository.dart';
import '../data_sources/work_entries_api_client.dart';
import '../dtos/special_activity_dto.dart';

class RemoteSpecialActivityRepository implements SpecialActivityRepository {
  const RemoteSpecialActivityRepository(this._apiClient);

  final WorkEntriesApiClient _apiClient;

  @override
  Future<List<SpecialActivity>> getActive() async =>
      _domain(await _apiClient.getActiveSpecialActivities());
  @override
  Future<SpecialActivity> getById(int id) async =>
      (await _apiClient.getSpecialActivity(id)).toDomain();
  @override
  Future<SpecialActivity> create(SpecialActivityCreateInput input) async =>
      (await _apiClient.createSpecialActivity(
        SpecialActivityDto.createToJson(input),
      )).toDomain();
  @override
  Future<SpecialActivity> update(
    int id,
    SpecialActivityUpdateInput input,
  ) async => (await _apiClient.updateSpecialActivity(
    id,
    SpecialActivityDto.updateToJson(input),
  )).toDomain();
  @override
  Future<void> delete(int id) => _apiClient.deleteSpecialActivity(id);

  List<SpecialActivity> _domain(List<SpecialActivityDto> values) => values
      .map((value) => value.toDomain())
      .toList(growable: false);
}
