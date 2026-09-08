import 'dart:convert';

import '../domain/models/active_focus_timer.dart';

class ActiveFocusTimerCodec {
  const ActiveFocusTimerCodec();

  String encode(ActiveFocusTimer timer) => jsonEncode({
    'version': 1,
    'focusAreaId': timer.focusAreaId,
    'workDate': _date(timer.workDate),
    'startedAt': timer.startedAt.toUtc().toIso8601String(),
    'startedAtUtcOffsetMinutes': timer.startedAtUtcOffset.inMinutes,
    'focusDurationMicros': timer.focusDuration.inMicroseconds,
    'restDurationMicros': timer.restDuration.inMicroseconds,
    'phase': timer.phase.name,
    'activity': timer.activity.name,
    'accumulatedFocusMicros': timer.accumulatedFocusTime.inMicroseconds,
    'accumulatedRestMicros': timer.accumulatedRestTime.inMicroseconds,
    'runningSince': timer.runningSince?.toUtc().toIso8601String(),
    'focusTransitionNotified': timer.focusTransitionNotified,
  });

  ActiveFocusTimer decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1) throw const FormatException('Unknown version');
    final workDateParts = (json['workDate'] as String)
        .split('-')
        .map(int.parse)
        .toList();
    return ActiveFocusTimer(
      focusAreaId: json['focusAreaId'] as int,
      workDate: DateTime(workDateParts[0], workDateParts[1], workDateParts[2]),
      startedAt: DateTime.parse(json['startedAt'] as String),
      startedAtUtcOffset: Duration(
        minutes:
            json['startedAtUtcOffsetMinutes'] as int? ??
            DateTime.parse(
              json['startedAt'] as String,
            ).toLocal().timeZoneOffset.inMinutes,
      ),
      focusDuration: Duration(microseconds: json['focusDurationMicros'] as int),
      restDuration: Duration(microseconds: json['restDurationMicros'] as int),
      phase: FocusTimerPhase.values.byName(json['phase'] as String),
      activity: FocusTimerActivity.values.byName(json['activity'] as String),
      accumulatedFocusTime: Duration(
        microseconds: json['accumulatedFocusMicros'] as int,
      ),
      accumulatedRestTime: Duration(
        microseconds: json['accumulatedRestMicros'] as int,
      ),
      runningSince: switch (json['runningSince']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      focusTransitionNotified: json['focusTransitionNotified'] as bool,
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
