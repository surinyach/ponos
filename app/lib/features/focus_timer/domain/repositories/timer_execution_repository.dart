import '../models/timer_execution_draft.dart';

abstract interface class TimerExecutionRepository {
  Future<void> save(TimerExecutionDraft execution);
}
