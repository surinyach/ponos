import '../../domain/models/special_activity.dart';
import 'work_entry_json.dart';

class SpecialActivityDto {
  const SpecialActivityDto({
    required this.id,
    required this.name,
    required this.workDate,
    required this.isArchived,
    this.description,
  });

  factory SpecialActivityDto.fromJson(Map<String, Object?> json) =>
      SpecialActivityDto(
        id: requiredValue<int>(json, 'id'),
        name: requiredValue<String>(json, 'name'),
        description: nullableValue<String>(json, 'description'),
        workDate: requiredDate(json, 'work_date'),
        isArchived: requiredValue<bool>(json, 'is_archived'),
      );

  final int id;
  final String name;
  final String? description;
  final DateTime workDate;
  final bool isArchived;

  SpecialActivity toDomain() => SpecialActivity(
    id: id,
    name: name,
    description: description,
    workDate: workDate,
    isArchived: isArchived,
  );

  static Map<String, Object?> createToJson(SpecialActivityCreateInput input) => {
    'name': input.name,
    'description': input.description,
    'work_date': dateToJson(input.workDate),
  };

  static Map<String, Object?> updateToJson(SpecialActivityUpdateInput input) {
    final json = <String, Object?>{};
    if (input.name != null) json['name'] = input.name;
    if (input.description.isPresent) {
      json['description'] = input.description.value;
    }
    if (input.workDate != null) json['work_date'] = dateToJson(input.workDate!);
    return json;
  }
}
