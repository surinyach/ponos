import '../models/work_goals.dart';

abstract interface class WorkGoalsRepository {
  Future<WorkGoals> get(DateTime localDate);
  Future<WorkGoals> save(DateTime localDate, WorkGoals goals);
}
