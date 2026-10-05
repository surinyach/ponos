import '../domain/models/work_goals.dart';
import '../domain/repositories/work_goals_repository.dart';
import 'work_goals_api_client.dart';
import 'work_goals_dto.dart';

class RemoteWorkGoalsRepository implements WorkGoalsRepository {
  const RemoteWorkGoalsRepository(this._apiClient);

  final WorkGoalsApiClient _apiClient;

  @override
  Future<WorkGoals> get(DateTime localDate) async =>
      (await _apiClient.get(localDate)).toDomain();

  @override
  Future<WorkGoals> save(DateTime localDate, WorkGoals goals) async =>
      (await _apiClient.save(localDate, WorkGoalsDto.toJson(goals))).toDomain();
}
