import '../models/special_activity.dart';

abstract interface class SpecialActivityRepository {
  Future<List<SpecialActivity>> getActive();
  Future<List<SpecialActivity>> getArchived();
  Future<SpecialActivity> getById(int id);
  Future<SpecialActivity> create(SpecialActivityCreateInput input);
  Future<SpecialActivity> update(int id, SpecialActivityUpdateInput input);
  Future<SpecialActivity> archive(int id);
  Future<SpecialActivity> restore(int id);
}
