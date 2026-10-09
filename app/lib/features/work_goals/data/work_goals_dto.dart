import '../domain/models/work_goals.dart';

class WorkGoalsDto {
  const WorkGoalsDto({
    required this.date,
    required this.dailyGoals,
    required this.weeklyGoalMinutes,
    required this.weeklyGoalEffectiveFrom,
  });

  factory WorkGoalsDto.fromJson(Map<String, Object?> json) {
    final daily = json['daily_goals'];
    if (daily is! List<Object?>) {
      throw const FormatException('Expected daily_goals to be a list');
    }
    return WorkGoalsDto(
      date: _requiredDate(json, 'date'),
      dailyGoals: daily
          .map((value) {
            final item = _asObject(value);
            return DailyWorkGoal(
              weekday: _required<int>(item, 'weekday'),
              targetMinutes: _required<int>(item, 'target_minutes'),
            );
          })
          .toList(growable: false),
      weeklyGoalMinutes: _required<int>(json, 'weekly_goal_minutes'),
      weeklyGoalEffectiveFrom: _nullableDate(
        json,
        'weekly_goal_effective_from',
      ),
    );
  }

  final DateTime date;
  final List<DailyWorkGoal> dailyGoals;
  final int weeklyGoalMinutes;
  final DateTime? weeklyGoalEffectiveFrom;

  WorkGoals toDomain() => WorkGoals(
    date: date,
    dailyGoals: dailyGoals,
    weeklyGoalMinutes: weeklyGoalMinutes,
    weeklyGoalEffectiveFrom: weeklyGoalEffectiveFrom,
  );

  static Map<String, Object?> toJson(WorkGoals goals) => {
    'daily_goals': goals.dailyGoals
        .map(
          (goal) => {
            'weekday': goal.weekday,
            'target_minutes': goal.targetMinutes,
          },
        )
        .toList(growable: false),
    'weekly_goal_minutes': goals.weeklyGoalMinutes,
  };
}

T _required<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('$key has an invalid type');
  return value;
}

Map<String, Object?> _asObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

DateTime _requiredDate(Map<String, Object?> json, String key) =>
    DateTime.parse(_required<String>(json, key));

DateTime? _nullableDate(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key has an invalid type');
  return DateTime.parse(value);
}
