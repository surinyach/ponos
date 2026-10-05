import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_areas/data/dtos/focus_area_target_dto.dart';
import 'work_goals_dto.dart';

class WorkGoalsApiClient {
  const WorkGoalsApiClient(
    this._client,
    this._config, {
    this.requestTimeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final ApiConfig _config;
  final Duration requestTimeout;

  Future<WorkGoalsDto> get(DateTime localDate) => _request('GET', localDate);

  Future<WorkGoalsDto> save(DateTime localDate, Map<String, Object?> body) =>
      _request('PUT', localDate, body: body);

  Future<WorkGoalsDto> _request(
    String method,
    DateTime localDate, {
    Map<String, Object?>? body,
  }) async {
    final query = Uri(queryParameters: {'date': dateToJson(localDate)}).query;
    final request = http.Request(
      method,
      _config.endpoint('/api/v1/work-goals?$query'),
    );
    request.headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
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
    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const InvalidResponseException('Server returned invalid JSON');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Work Goals request failed';
      if (decoded is Map<String, Object?> && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
      if (response.statusCode == 422) throw ValidationException(message);
      if (response.statusCode >= 500) throw ServerException(message);
      throw InvalidResponseException(message);
    }
    if (decoded is! Map<String, Object?>) {
      throw const InvalidResponseException('Expected a JSON object');
    }
    try {
      return WorkGoalsDto.fromJson(decoded);
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }
}
