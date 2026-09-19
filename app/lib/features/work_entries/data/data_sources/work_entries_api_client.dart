import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../dtos/manual_work_entry_dto.dart';
import '../dtos/special_activity_dto.dart';

class WorkEntriesApiClient {
  const WorkEntriesApiClient(
    this._client,
    this._config, {
    this.requestTimeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final ApiConfig _config;
  final Duration requestTimeout;

  Future<List<SpecialActivityDto>> getActiveSpecialActivities() =>
      _specialActivityList('/api/v1/special-activities');
  Future<List<SpecialActivityDto>> getArchivedSpecialActivities() =>
      _specialActivityList('/api/v1/special-activities/archived');
  Future<SpecialActivityDto> getSpecialActivity(int id) =>
      _specialActivity('GET', '/api/v1/special-activities/$id');
  Future<SpecialActivityDto> createSpecialActivity(
    Map<String, Object?> body,
  ) => _specialActivity('POST', '/api/v1/special-activities', body: body);
  Future<SpecialActivityDto> updateSpecialActivity(
    int id,
    Map<String, Object?> body,
  ) => _specialActivity('PATCH', '/api/v1/special-activities/$id', body: body);
  Future<SpecialActivityDto> archiveSpecialActivity(int id) =>
      _specialActivity('POST', '/api/v1/special-activities/$id/archive');
  Future<SpecialActivityDto> restoreSpecialActivity(int id) =>
      _specialActivity('POST', '/api/v1/special-activities/$id/restore');

  Future<List<ManualWorkEntryDto>> getManualWorkEntries() async {
    final value = await _request('GET', '/api/v1/manual-work-entries');
    if (value is! List<Object?>) {
      throw const InvalidResponseException('Expected a JSON list');
    }
    try {
      return value
          .map((item) => ManualWorkEntryDto.fromJson(_object(item)))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<ManualWorkEntryDto> createManualWorkEntry(
    Map<String, Object?> body,
  ) => _manualWorkEntry('POST', '/api/v1/manual-work-entries', body: body);
  Future<ManualWorkEntryDto> updateManualWorkEntry(
    int id,
    Map<String, Object?> body,
  ) => _manualWorkEntry(
    'PATCH',
    '/api/v1/manual-work-entries/$id',
    body: body,
  );
  Future<void> deleteManualWorkEntry(int id) async {
    await _request('DELETE', '/api/v1/manual-work-entries/$id');
  }

  Future<List<SpecialActivityDto>> _specialActivityList(String path) async {
    final value = await _request('GET', path);
    if (value is! List<Object?>) {
      throw const InvalidResponseException('Expected a JSON list');
    }
    try {
      return value
          .map((item) => SpecialActivityDto.fromJson(_object(item)))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<SpecialActivityDto> _specialActivity(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final value = await _request(method, path, body: body);
    try {
      return SpecialActivityDto.fromJson(_object(value));
    } on FormatException catch (error) {
      throw InvalidResponseException(error.message);
    }
  }

  Future<ManualWorkEntryDto> _manualWorkEntry(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final value = await _request(method, path, body: body);
    try {
      return ManualWorkEntryDto.fromJson(_object(value));
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
    return 'Work entries request failed';
  }

  Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    return value;
  }
}
