import '../domain/models/timer_execution_draft.dart';
import '../domain/repositories/focus_timer_gateways.dart';
import 'timer_execution_api_client.dart';

class RemoteTimerExecutionRecorder implements TimerExecutionRecorder {
  const RemoteTimerExecutionRecorder(this._apiClient);

  final TimerExecutionApiClient _apiClient;

  @override
  Future<void> save(TimerExecutionDraft execution) =>
      _apiClient.create(execution);
}
