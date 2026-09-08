import '../../domain/models/focus_area_input.dart';
import '../../domain/models/focus_area_target.dart';

class FocusAreaTargetDto {
  const FocusAreaTargetDto({
    required this.id,
    required this.weekday,
    required this.targetMinutes,
    required this.validFrom,
    this.validUntil,
  });
  factory FocusAreaTargetDto.fromJson(Map<String, Object?> json) =>
      FocusAreaTargetDto(
        id: requiredInt(json, 'id'),
        weekday: requiredInt(json, 'weekday'),
        targetMinutes: requiredInt(json, 'target_minutes'),
        validFrom: requiredDate(json, 'valid_from'),
        validUntil: nullableDate(json, 'valid_until'),
      );
  final int id;
  final int weekday;
  final int targetMinutes;
  final DateTime validFrom;
  final DateTime? validUntil;
  FocusAreaTarget toDomain(int focusAreaId) => FocusAreaTarget(
    id: id,
    focusAreaId: focusAreaId,
    weekday: weekday,
    targetMinutes: targetMinutes,
    validFrom: validFrom,
    validUntil: validUntil,
  );
  static Map<String, Object?> inputToJson(FocusAreaTargetInput input) => {
    'weekday': input.weekday,
    'target_minutes': input.targetMinutes,
    'valid_from': dateToJson(input.validFrom),
  };
}

int requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

DateTime requiredDate(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a date');
  return DateTime.parse(value);
}

DateTime? nullableDate(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a date or null');
  return DateTime.parse(value);
}

String dateToJson(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
