import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ponos_app/core/config/api_config.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/work_entries/data/data_sources/work_entries_api_client.dart';
import 'package:ponos_app/features/work_entries/data/repositories/remote_manual_work_entry_repository.dart';
import 'package:ponos_app/features/work_entries/data/repositories/remote_special_activity_repository.dart';
import 'package:ponos_app/features/work_entries/domain/models/manual_work_entry.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';

void main() {
  group('RemoteSpecialActivityRepository', () {
    test('maps active activities into domain models', () async {
      final repository = _specialRepository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/ponos/api/v1/special-activities');
        return http.Response(jsonEncode([_activityResponse()]), 200);
      });

      final activities = await repository.getActive();

      expect(activities.single.name, 'Release day');
    });

    test('serializes create and partial update inputs', () async {
      final requests = <http.Request>[];
      final repository = _specialRepository((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_activityResponse()), 200);
      });

      await repository.create(
        SpecialActivityCreateInput(name: 'Release day', description: 'Deploy'),
      );
      await repository.update(
        4,
        const SpecialActivityUpdateInput(
          description: OptionalValue.present(null),
        ),
      );

      expect(jsonDecode(requests.first.body), {
        'name': 'Release day',
        'description': 'Deploy',
      });
      expect(jsonDecode(requests.last.body), {'description': null});
      expect(requests.last.method, 'PATCH');
    });

    test('uses get and delete endpoints', () async {
      final seen = <String>[];
      final repository = _specialRepository((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.method == 'DELETE') return http.Response('', 204);
        return http.Response(jsonEncode(_activityResponse()), 200);
      });

      await repository.getById(4);
      await repository.delete(4);

      expect(seen, [
        'GET /ponos/api/v1/special-activities/4',
        'DELETE /ponos/api/v1/special-activities/4',
      ]);
    });

    test('maps duplicate name and referenced-work conflicts', () async {
      final repository = _specialRepository(
        (_) async => http.Response(
          '{"detail":"A Special Activity with this name already exists"}',
          409,
        ),
      );
      expect(
        () => repository.create(
          const SpecialActivityCreateInput(name: 'Duplicate'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });
  });

  group('RemoteManualWorkEntryRepository', () {
    test('maps seconds from list responses to domain durations', () async {
      final repository = _manualRepository((request) async {
        expect(request.method, 'GET');
        return http.Response(jsonEncode([_entryResponse()]), 200);
      });

      final entries = await repository.getAll();

      expect(entries.single.focusAreaId, 7);
      expect(entries.single.focusedTime, const Duration(minutes: 30));
      expect(entries.single.restTime, const Duration(minutes: 5));
    });

    test('serializes create and explicit owner reassignment', () async {
      final requests = <http.Request>[];
      final repository = _manualRepository((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_entryResponse()), 200);
      });

      await repository.create(
        ManualWorkEntryCreateInput(
          focusAreaId: 7,
          workDate: DateTime(2026, 9, 9),
          focusedTime: const Duration(minutes: 30),
          restTime: const Duration(minutes: 5),
        ),
      );
      await repository.update(
        12,
        const ManualWorkEntryUpdateInput(
          specialActivityId: 4,
          changeOwner: true,
          restTime: Duration(minutes: 10),
        ),
      );

      expect(jsonDecode(requests.first.body), {
        'focus_area_id': 7,
        'special_activity_id': null,
        'work_date': '2026-09-09',
        'focused_seconds': 1800,
        'rest_seconds': 300,
      });
      expect(jsonDecode(requests.last.body), {
        'focus_area_id': null,
        'special_activity_id': 4,
        'rest_seconds': 600,
      });
    });

    test('sends delete without requiring a response body', () async {
      final repository = _manualRepository((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/ponos/api/v1/manual-work-entries/12');
        return http.Response('', 204);
      });

      await repository.delete(12);
    });
  });

  group('WorkEntriesApiClient errors', () {
    for (final entry in <int, Type>{
      404: NotFoundException,
      409: ConflictException,
      422: ValidationException,
      500: ServerException,
    }.entries) {
      test('maps ${entry.key} to ${entry.value}', () {
        final client = _api(
          (_) async =>
              http.Response(jsonEncode({'detail': 'Mapped'}), entry.key),
        );

        expect(
          client.getSpecialActivity(4),
          throwsA(
            isA<AppException>().having(
              (error) => error.runtimeType,
              'type',
              entry.value,
            ),
          ),
        );
      });
    }

    test('maps malformed successful JSON', () {
      final client = _api((_) async => http.Response('not-json', 200));
      expect(
        client.getManualWorkEntries(),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('maps transport failures and timeouts', () {
      final offline = _api((_) async => throw http.ClientException('offline'));
      final timeout = WorkEntriesApiClient(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response('[]', 200);
        }),
        ApiConfig('https://home.example/ponos'),
        requestTimeout: Duration.zero,
      );

      expect(
        offline.getActiveSpecialActivities(),
        throwsA(isA<NetworkException>()),
      );
      expect(timeout.getManualWorkEntries(), throwsA(isA<NetworkException>()));
    });
  });
}

RemoteSpecialActivityRepository _specialRepository(
  Future<http.Response> Function(http.Request) handler,
) => RemoteSpecialActivityRepository(_api(handler));

RemoteManualWorkEntryRepository _manualRepository(
  Future<http.Response> Function(http.Request) handler,
) => RemoteManualWorkEntryRepository(_api(handler));

WorkEntriesApiClient _api(
  Future<http.Response> Function(http.Request) handler,
) => WorkEntriesApiClient(
  MockClient(handler),
  ApiConfig('https://home.example/ponos'),
);

Map<String, Object?> _activityResponse() => {
  'id': 4,
  'name': 'Release day',
  'description': 'Deploy',
};

Map<String, Object?> _entryResponse() => {
  'id': 12,
  'focus_area_id': 7,
  'special_activity_id': null,
  'work_date': '2026-09-09',
  'focused_seconds': 1800,
  'rest_seconds': 300,
};
