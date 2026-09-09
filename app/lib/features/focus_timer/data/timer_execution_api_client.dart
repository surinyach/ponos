import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/errors/app_exception.dart';
import 'dtos/timer_execution_dto.dart';

class TimerExecutionApiClient {
  const TimerExecutionApiClient(
    this._client,
    this._config, {
    this.requestTimeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final ApiConfig _config;
  final Duration requestTimeout;

  Future<void> create(TimerExecutionCreateDto execution) async {
    final request =
        http.Request('POST', _config.endpoint('/api/v1/timer-executions'))
          ..headers['accept'] = 'application/json'
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(execution.toJson());

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
