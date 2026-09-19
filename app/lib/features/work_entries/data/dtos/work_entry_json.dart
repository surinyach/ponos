DateTime requiredDate(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key has an invalid type');
  return DateTime.parse(value);
}

T requiredValue<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('$key has an invalid type');
  return value;
}

T? nullableValue<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! T) throw FormatException('$key has an invalid type');
  return value as T;
}

String dateToJson(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
