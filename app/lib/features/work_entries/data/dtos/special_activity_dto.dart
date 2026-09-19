import '../../domain/models/special_activity.dart';
import 'work_entry_json.dart';

class SpecialActivityDto {
  const SpecialActivityDto({
    required this.id,
    required this.name,
    required this.isArchived,
    this.description,
  });

  factory SpecialActivityDto.fromJson(Map<String, Object?> json) =>
      SpecialActivityDto(
        id: requiredValue<int>(json, 'id'),
        name: requiredValue<String>(json, 'name'),
        description: nullableValue<String>(json, 'description'),
        isArchived: requiredValue<bool>(json, 'is_archived'),
      );

  final int id;
  final String name;
  final String? description;
  final bool isArchived;

  SpecialActivity toDomain() => SpecialActivity(
    id: id,
    name: name,
    description: description,
    isArchived: isArchived,
  );

  static Map<String, Object?> createToJson(SpecialActivityCreateInput input) =>
      {'name': input.name, 'description': input.description};

  static Map<String, Object?> updateToJson(SpecialActivityUpdateInput input) {
    final json = <String, Object?>{};
    if (input.name != null) json['name'] = input.name;
    if (input.description.isPresent) {
      json['description'] = input.description.value;
    }
    return json;
  }
}
