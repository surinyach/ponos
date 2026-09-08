import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/timer_execution_draft.dart';

class TimerExecutionApiClient {
  const TimerExecutionApiClient(
    this._client,
    this._config, {
    this.requestTimeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final ApiConfig _config;
  final Duration requestTimeout;

  Future<void> create(TimerExecutionDraft execution) async {
    final request =
        http.Request('POST', _config.endpoint('/api/v1/timer-executions'))
          ..headers['accept'] = 'application/json'
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode({
            'focus_area_id': execution.focusAreaId,
            'work_date': _date(execution.workDate),
            'started_at': _timestamp(
              execution.startedAt,
              execution.startedAtUtcOffset,
            ),
            'ended_at': _timestamp(
              execution.endedAt,
              execution.endedAtUtcOffset,
            ),
            'focused_seconds': execution.focusedTime.inSeconds,
            'rest_seconds': execution.restTime.inSeconds,
          });

    late http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const NetworkException('The server took too long to respond');
    } on http.ClientException catch (error) {
      throw NetworkException(error.message);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = _message(response.body);
    switch (response.statusCode) {
      case 404:
        throw NotFoundException(message);
      case 422:
        throw ValidationException(message);
      default:
        if (response.statusCode >= 500) throw ServerException(message);
        throw InvalidResponseException(message);
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _timestamp(DateTime instant, Duration offset) {
    final localParts = instant.toUtc().add(offset);
    final timestamp = localParts.toIso8601String().replaceFirst(
      RegExp(r'Z$'),
      '',
    );
    final minutes = offset.inMinutes;
    final sign = minutes < 0 ? '-' : '+';
    final absolute = minutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final remainder = (absolute % 60).toString().padLeft(2, '0');
    return '$timestamp$sign$hours:$remainder';
  }

  String _message(String body) {
    if (body.isEmpty) return 'Timer execution request failed';
    try {
      final decoded = jsonDecode(body);
      if (decoded case {'detail': final Object? detail}) {
        return detail.toString();
      }
    } on FormatException {
      return 'Server returned invalid JSON';
    }
    return 'Timer execution request failed';
  }
}
