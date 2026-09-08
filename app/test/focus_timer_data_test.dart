import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ponos_app/core/config/api_config.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_timer/data/timer_execution_api_client.dart';
import 'package:ponos_app/features/focus_timer/domain/models/timer_execution_draft.dart';

void main() {
  test('posts execution values with the captured local offsets', () async {
    late http.Request captured;
    final client = TimerExecutionApiClient(
      MockClient((request) async {
        captured = request;
        return http.Response('{"id":1}', 201);
      }),
      ApiConfig('http://server.test'),
    );
    final execution = TimerExecutionDraft(
      focusAreaId: 7,
      workDate: DateTime(2026, 9, 8),
      startedAt: DateTime.utc(2026, 9, 7, 22, 30),
      startedAtUtcOffset: const Duration(hours: 2),
      endedAt: DateTime.utc(2026, 9, 7, 23, 5),
      endedAtUtcOffset: const Duration(hours: 2),
      focusedTime: const Duration(minutes: 25),
      restTime: const Duration(minutes: 5),
    );

    await client.create(execution);

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/timer-executions');
    expect(jsonDecode(captured.body), {
      'focus_area_id': 7,
      'work_date': '2026-09-08',
      'started_at': '2026-09-08T00:30:00.000+02:00',
      'ended_at': '2026-09-08T01:05:00.000+02:00',
      'focused_seconds': 1500,
      'rest_seconds': 300,
    });
  });

  test('maps backend validation failures', () async {
    final client = TimerExecutionApiClient(
      MockClient(
        (_) async => http.Response('{"detail":"Invalid execution"}', 422),
      ),
      ApiConfig('http://server.test'),
    );

    expect(
      () => client.create(
        TimerExecutionDraft(
          focusAreaId: 1,
          workDate: DateTime(2026, 9, 8),
          startedAt: DateTime.utc(2026, 9, 8, 8),
          startedAtUtcOffset: Duration.zero,
          endedAt: DateTime.utc(2026, 9, 8, 8, 1),
          endedAtUtcOffset: Duration.zero,
          focusedTime: const Duration(minutes: 1),
          restTime: Duration.zero,
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          'Invalid execution',
        ),
      ),
    );
  });
}
