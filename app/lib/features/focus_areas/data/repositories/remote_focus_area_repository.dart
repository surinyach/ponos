import '../../domain/models/focus_area.dart';
import '../../domain/models/focus_area_input.dart';
import '../../domain/models/today_overview.dart';
import '../../domain/repositories/focus_area_repository.dart';
import '../data_sources/focus_area_api_client.dart';
import '../dtos/focus_area_dto.dart';

class RemoteFocusAreaRepository implements FocusAreaRepository {
  const RemoteFocusAreaRepository(this._apiClient);
  final FocusAreaApiClient _apiClient;
  @override
  Future<List<FocusArea>> getActive() async =>
      _domain(await _apiClient.getActive());
  @override
  Future<List<FocusArea>> getArchived() async =>
      _domain(await _apiClient.getArchived());
  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) async =>
      (await _apiClient.getTodayOverview(localDate)).toDomain();
  @override
  Future<FocusArea> getById(int id) async =>
      (await _apiClient.getById(id)).toDomain();
  @override
  Future<FocusArea> create(FocusAreaCreateInput input) async =>
      (await _apiClient.create(FocusAreaDto.createToJson(input))).toDomain();
  @override
  Future<FocusArea> update(int id, FocusAreaUpdateInput input) async =>
      (await _apiClient.update(
        id,
        FocusAreaDto.updateToJson(input),
      )).toDomain();
  @override
  Future<FocusArea> archive(int id) async =>
      (await _apiClient.archive(id)).toDomain();
  @override
  Future<FocusArea> restore(int id) async =>
      (await _apiClient.restore(id)).toDomain();
  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> priorities,
  ) async {
    final response = await _apiClient.updatePriorities({
      'items': priorities
          .map((item) => {'id': item.id, 'priority': item.priority})
          .toList(growable: false),
    });
    return _domain(response);
  }

  List<FocusArea> _domain(List<FocusAreaDto> values) =>
      values.map((value) => value.toDomain()).toList(growable: false);
}
