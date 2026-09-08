import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ponos_app/core/config/api_config.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/data/data_sources/focus_area_api_client.dart';
import 'package:ponos_app/features/focus_areas/data/repositories/remote_focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';

void main() {
  group('RemoteFocusAreaRepository', () {
    test('maps an active API response into domain models', () async {
      final repository = _repository((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://home.example/ponos/api/v1/focus-areas',
        );
        return http.Response(jsonEncode([_response()]), 200);
      });

      final areas = await repository.getActive();

      expect(areas.single.name, 'Work placement');
      expect(areas.single.targets.single.focusAreaId, 7);
      expect(areas.single.targets.single.targetMinutes, 480);
    });

    test(
      'loads and maps the daily overview using the local timezone',
      () async {
        final localDate = DateTime(2026, 9, 7);
        final repository = _repository((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/ponos/api/v1/overview/today');
          expect(request.url.queryParameters['date'], '2026-09-07');
          expect(
            DateTime.parse(request.url.queryParameters['day_start_utc']!),
            DateTime(2026, 9, 7).toUtc(),
          );
          expect(
            DateTime.parse(request.url.queryParameters['day_end_utc']!),
            DateTime(2026, 9, 8).toUtc(),
          );
          return http.Response(
            jsonEncode({
              'date': '2026-09-07',
              'expected_focus_seconds': 3600,
              'actual_focused_seconds': 1800,
              'completed_focus_areas': 0,
              'targeted_focus_areas': 1,
              'areas': [
                {
                  'focus_area': _response(),
                  'target_seconds': 3600,
                  'focused_seconds': 1800,
                  'completed': false,
                },
              ],
            }),
            200,
          );
        });

        final overview = await repository.getTodayOverview(localDate);

        expect(overview.expectedFocusTime, const Duration(hours: 1));
        expect(overview.actualFocusedTime, const Duration(minutes: 30));
        expect(overview.areas.single.focusArea.name, 'Work placement');
        expect(overview.areas.single.completed, isFalse);
      },
    );

    test('serializes create inputs using the backend field names', () async {
      final repository = _repository((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(request.method, 'POST');
        expect(body['target_end_date'], '2026-12-31');
        expect((body['targets'] as List).single, {
          'weekday': 1,
          'target_minutes': 480,
          'valid_from': '2026-09-07',
        });
        return http.Response(jsonEncode(_response()), 201);
      });

      await repository.create(
        FocusAreaCreateInput(
          name: 'Work placement',
          priority: 1,
          targetEndDate: DateTime(2026, 12, 31),
          targets: [
            FocusAreaTargetInput(
              weekday: DateTime.monday,
              targetMinutes: 480,
              validFrom: DateTime(2026, 9, 7),
            ),
          ],
        ),
      );
    });

    test(
      'distinguishes unchanged and explicitly cleared nullable fields',
      () async {
        final bodies = <Map<String, Object?>>[];
        final repository = _repository((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, Object?>);
          return http.Response(jsonEncode(_response()), 200);
        });

        await repository.update(7, const FocusAreaUpdateInput(name: 'Updated'));
        await repository.update(
          7,
          const FocusAreaUpdateInput(
            description: NullableUpdate.set(null),
            targetEndDate: NullableUpdate.set(null),
          ),
        );

        expect(bodies.first, {'name': 'Updated'});
        expect(bodies.last, {'description': null, 'target_end_date': null});
      },
    );

    test('sends duplicate priorities without changing them', () async {
      final repository = _repository((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['items'], [
          {'id': 7, 'priority': 2},
          {'id': 8, 'priority': 2},
        ]);
        return http.Response(jsonEncode([_response(), _response(id: 8)]), 200);
      });

      final result = await repository.updatePriorities(const [
        FocusAreaPriorityInput(id: 7, priority: 2),
        FocusAreaPriorityInput(id: 8, priority: 2),
      ]);

      expect(result, hasLength(2));
    });

    test('maps the daily overview and sends local day context', () async {
      final localDate = DateTime(2026, 9, 7);
      final repository = _repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/ponos/api/v1/overview/today');
        expect(request.url.queryParameters['date'], '2026-09-07');
        expect(
          DateTime.parse(request.url.queryParameters['day_start_utc']!),
          DateTime(2026, 9, 7).toUtc(),
        );
        expect(
          DateTime.parse(request.url.queryParameters['day_end_utc']!),
          DateTime(2026, 9, 8).toUtc(),
        );
        return http.Response(
          jsonEncode({
            'date': '2026-09-07',
            'expected_focus_seconds': 3600,
            'actual_focused_seconds': 1800,
            'completed_focus_areas': 0,
            'targeted_focus_areas': 1,
            'areas': [
              {
                'focus_area': _response(),
                'target_seconds': 3600,
                'focused_seconds': 1800,
                'completed': false,
              },
            ],
          }),
          200,
        );
      });

      final overview = await repository.getTodayOverview(localDate);

      expect(overview.expectedFocusTime, const Duration(hours: 1));
      expect(overview.actualFocusedTime, const Duration(minutes: 30));
      expect(overview.areas.single.focusArea.name, 'Work placement');
      expect(overview.areas.single.completed, isFalse);
    });
  });

  group('FocusAreaApiClient errors', () {
    for (final entry in <int, Type>{
      404: NotFoundException,
      409: ConflictException,
      422: ValidationException,
      500: ServerException,
    }.entries) {
      test('maps ${entry.key} to ${entry.value}', () async {
        final client = _api(
          (_) async =>
              http.Response(jsonEncode({'detail': 'Mapped error'}), entry.key),
        );

        expect(
          client.getById(7),
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

    test('maps malformed success responses', () async {
      final client = _api((_) async => http.Response('not-json', 200));
      expect(client.getActive(), throwsA(isA<InvalidResponseException>()));
    });

    test('maps HTTP transport failures', () async {
      final client = _api((_) async => throw http.ClientException('offline'));
      expect(client.getActive(), throwsA(isA<NetworkException>()));
    });

    test('maps request timeouts instead of loading indefinitely', () async {
      final client = FocusAreaApiClient(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response('[]', 200);
        }),
        ApiConfig('https://home.example/ponos'),
        requestTimeout: Duration.zero,
      );

      expect(
        client.getActive(),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            'The server took too long to respond',
          ),
        ),
      );
    });
  });

  test('ApiConfig rejects invalid URLs', () {
    expect(() => ApiConfig('localhost:8000'), throwsArgumentError);
  });
}

RemoteFocusAreaRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => RemoteFocusAreaRepository(_api(handler));

FocusAreaApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    FocusAreaApiClient(
      MockClient(handler),
      ApiConfig('https://home.example/ponos'),
    );

Map<String, Object?> _response({int id = 7}) => {
  'id': id,
  'name': 'Work placement',
  'description': null,
  'priority': 1,
  'target_end_date': null,
  'archived_at': null,
  'created_at': '2026-09-01T08:00:00Z',
  'updated_at': '2026-09-01T08:00:00Z',
  'targets': [
    {
      'id': 11,
      'weekday': 1,
      'target_minutes': 480,
      'valid_from': '2026-09-07',
      'valid_until': null,
    },
  ],
};
