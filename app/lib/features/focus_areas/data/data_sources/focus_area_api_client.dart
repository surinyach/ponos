import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../dtos/focus_area_dto.dart';
import '../dtos/focus_area_target_dto.dart';
import '../dtos/today_overview_dto.dart';

class FocusAreaApiClient {
  FocusAreaApiClient(
    this._client,
    this._config, {
    this.requestTimeout = const Duration(seconds: 10),
  });
  final http.Client _client;
  final ApiConfig _config;
  final Duration requestTimeout;
  Future<List<FocusAreaDto>> getActive() => _list('/api/v1/focus-areas');
  Future<List<FocusAreaDto>> getArchived() =>
      _list('/api/v1/focus-areas/archived');
  Future<TodayOverviewDto> getTodayOverview(DateTime localDate) async {
    final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
    final dayEnd = DateTime(localDate.year, localDate.month, localDate.day + 1);
    final query = Uri(
      queryParameters: {
        'date': dateToJson(localDate),
        'day_start_utc': dayStart.toUtc().toIso8601String(),
        'day_end_utc': dayEnd.toUtc().toIso8601String(),
      },
    ).query;
    final value = await _request('GET', '/api/v1/overview/today?$query');
    try {
      return TodayOverviewDto.fromJson(_object(value));
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<FocusAreaDto> getById(int id) =>
      _one('GET', '/api/v1/focus-areas/$id');
  Future<FocusAreaDto> create(Map<String, Object?> body) =>
      _one('POST', '/api/v1/focus-areas', body: body);
  Future<FocusAreaDto> update(int id, Map<String, Object?> body) =>
      _one('PATCH', '/api/v1/focus-areas/$id', body: body);
  Future<FocusAreaDto> archive(int id) =>
      _one('POST', '/api/v1/focus-areas/$id/archive');
  Future<FocusAreaDto> restore(int id) =>
      _one('POST', '/api/v1/focus-areas/$id/restore');
  Future<List<FocusAreaDto>> updatePriorities(Map<String, Object?> body) =>
      _list('/api/v1/focus-areas/priorities', method: 'PATCH', body: body);

  Future<FocusAreaDto> _one(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final value = await _request(method, path, body: body);
    try {
      return FocusAreaDto.fromJson(_object(value));
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<List<FocusAreaDto>> _list(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final value = await _request(method, path, body: body);
    if (value is! List<Object?>) {
      throw const InvalidResponseException('Expected a JSON list');
    }
    try {
      return value
          .map((item) => FocusAreaDto.fromJson(_object(item)))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _config.endpoint(path));
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
    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    final message = _message(decoded);
    switch (response.statusCode) {
      case 404:
        throw NotFoundException(message);
      case 409:
        throw ConflictException(message);
      case 422:
        throw ValidationException(message);
      default:
        if (response.statusCode >= 500) throw ServerException(message);
        throw InvalidResponseException(message);
    }
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const InvalidResponseException('Server returned invalid JSON');
    }
  }

  String _message(Object? body) {
    if (body case {'detail': final Object? detail}) return detail.toString();
    return 'Focus Areas request failed';
  }

  Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    return value;
  }
}
