import '../models/focus_area.dart';
import '../models/focus_area_input.dart';
import '../models/today_overview.dart';

abstract interface class FocusAreaRepository {
  Future<List<FocusArea>> getActive();
  Future<List<FocusArea>> getArchived();
  Future<TodayOverview> getTodayOverview(DateTime localDate);
  Future<FocusArea> getById(int id);
  Future<FocusArea> create(FocusAreaCreateInput input);
  Future<FocusArea> update(int id, FocusAreaUpdateInput input);
  Future<FocusArea> archive(int id);
  Future<FocusArea> restore(int id);
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> priorities,
  );
}
