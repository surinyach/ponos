import '../../domain/models/manual_work_entry.dart';
import 'work_entry_json.dart';

class ManualWorkEntryDto {
  const ManualWorkEntryDto({
    required this.id,
    required this.workDate,
    required this.focusedSeconds,
    required this.restSeconds,
    this.focusAreaId,
    this.specialActivityId,
  });

  factory ManualWorkEntryDto.fromJson(Map<String, Object?> json) =>
      ManualWorkEntryDto(
        id: requiredValue<int>(json, 'id'),
        focusAreaId: nullableValue<int>(json, 'focus_area_id'),
        specialActivityId: nullableValue<int>(json, 'special_activity_id'),
        workDate: requiredDate(json, 'work_date'),
        focusedSeconds: requiredValue<int>(json, 'focused_seconds'),
        restSeconds: requiredValue<int>(json, 'rest_seconds'),
      );

  final int id;
  final int? focusAreaId;
  final int? specialActivityId;
  final DateTime workDate;
  final int focusedSeconds;
  final int restSeconds;

  ManualWorkEntry toDomain() => ManualWorkEntry(
    id: id,
    focusAreaId: focusAreaId,
    specialActivityId: specialActivityId,
    workDate: workDate,
    focusedTime: Duration(seconds: focusedSeconds),
    restTime: Duration(seconds: restSeconds),
  );

  static Map<String, Object?> createToJson(ManualWorkEntryCreateInput input) => {
    'focus_area_id': input.focusAreaId,
    'special_activity_id': input.specialActivityId,
    'work_date': dateToJson(input.workDate),
    'focused_seconds': input.focusedTime.inSeconds,
    'rest_seconds': input.restTime.inSeconds,
  };

  static Map<String, Object?> updateToJson(ManualWorkEntryUpdateInput input) {
    final json = <String, Object?>{};
    if (input.changeOwner) {
      json['focus_area_id'] = input.focusAreaId;
      json['special_activity_id'] = input.specialActivityId;
    }
    if (input.workDate != null) json['work_date'] = dateToJson(input.workDate!);
    if (input.focusedTime != null) {
      json['focused_seconds'] = input.focusedTime!.inSeconds;
    }
    if (input.restTime != null) {
      json['rest_seconds'] = input.restTime!.inSeconds;
    }
    return json;
  }
}
