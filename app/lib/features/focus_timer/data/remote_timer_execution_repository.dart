import '../domain/models/timer_execution_draft.dart';
import '../domain/repositories/timer_execution_repository.dart';
import 'dtos/timer_execution_dto.dart';
import 'timer_execution_api_client.dart';

class RemoteTimerExecutionRepository implements TimerExecutionRepository {
  const RemoteTimerExecutionRepository(this._apiClient);

  final TimerExecutionApiClient _apiClient;

  @override
  Future<void> save(TimerExecutionDraft execution) =>
      _apiClient.create(TimerExecutionCreateDto.fromDomain(execution));
}
