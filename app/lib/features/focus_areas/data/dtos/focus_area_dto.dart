import '../../domain/models/focus_area.dart';
import '../../domain/models/focus_area_input.dart';
import 'focus_area_target_dto.dart';

class FocusAreaDto {
  const FocusAreaDto({
    required this.id,
    required this.name,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.targets,
    this.description,
    this.targetEndDate,
    this.archivedAt,
  });
  factory FocusAreaDto.fromJson(Map<String, Object?> json) {
    final rawTargets = json['targets'];
    if (rawTargets is! List<Object?>) {
      throw const FormatException('targets must be a list');
    }
    return FocusAreaDto(
      id: required<int>(json, 'id'),
      name: required<String>(json, 'name'),
      description: nullable<String>(json, 'description'),
      priority: required<int>(json, 'priority'),
      targetEndDate: nullableDate(json, 'target_end_date'),
      archivedAt: nullableDateTime(json, 'archived_at'),
      createdAt: requiredDateTime(json, 'created_at'),
      updatedAt: requiredDateTime(json, 'updated_at'),
      targets: rawTargets
          .map((value) => FocusAreaTargetDto.fromJson(asObject(value)))
          .toList(growable: false),
    );
  }
  final int id;
  final String name;
  final String? description;
  final int priority;
  final DateTime? targetEndDate;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FocusAreaTargetDto> targets;
  FocusArea toDomain() => FocusArea(
    id: id,
    name: name,
    description: description,
    priority: priority,
    targetEndDate: targetEndDate,
    archivedAt: archivedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    targets: targets
        .map((target) => target.toDomain(id))
        .toList(growable: false),
  );
  static Map<String, Object?> createToJson(FocusAreaCreateInput input) => {
    'name': input.name,
    'description': input.description,
    'priority': input.priority,
    'target_end_date': input.targetEndDate == null
        ? null
        : dateToJson(input.targetEndDate!),
    'targets': input.targets
        .map(FocusAreaTargetDto.inputToJson)
        .toList(growable: false),
  };
  static Map<String, Object?> updateToJson(FocusAreaUpdateInput input) {
    final json = <String, Object?>{};
    if (input.name != null) json['name'] = input.name;
    if (input.description.isChanged) {
      json['description'] = input.description.value;
    }
    if (input.priority != null) json['priority'] = input.priority;
    if (input.targetEndDate.isChanged) {
      json['target_end_date'] = input.targetEndDate.value == null
          ? null
          : dateToJson(input.targetEndDate.value!);
    }
    if (input.targets != null) {
      json['targets'] = input.targets!
          .map(FocusAreaTargetDto.inputToJson)
          .toList(growable: false);
    }
    return json;
  }
}

T required<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('$key has an invalid type');
  return value;
}

T? nullable<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! T) throw FormatException('$key has an invalid type');
  return value as T;
}

DateTime requiredDateTime(Map<String, Object?> json, String key) =>
    DateTime.parse(required<String>(json, key));
DateTime? nullableDateTime(Map<String, Object?> json, String key) {
  final value = nullable<String>(json, key);
  return value == null ? null : DateTime.parse(value);
}

Map<String, Object?> asObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}
