import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';

void main() {
  test('selects the target version that applies to a local workday', () {
    final area = FocusArea(
      id: 1,
      name: 'Personal project',
      priority: 2,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
      targets: [
        FocusAreaTarget(
          id: 1,
          focusAreaId: 1,
          weekday: DateTime.monday,
          targetMinutes: 120,
          validFrom: DateTime(2026, 9, 7),
          validUntil: DateTime(2026, 9, 13),
        ),
        FocusAreaTarget(
          id: 2,
          focusAreaId: 1,
          weekday: DateTime.monday,
          targetMinutes: 90,
          validFrom: DateTime(2026, 9, 14),
        ),
      ],
    );

    expect(area.targetFor(DateTime(2026, 9, 7))?.targetMinutes, 120);
    expect(area.targetFor(DateTime(2026, 9, 14))?.targetMinutes, 90);
    expect(area.targetFor(DateTime(2026, 9, 15)), isNull);
  });

  test('reports archive state from the backend timestamp', () {
    final timestamp = DateTime.utc(2026, 9, 1);
    final area = FocusArea(
      id: 1,
      name: 'Work placement',
      priority: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
      archivedAt: timestamp,
      targets: const [],
    );

    expect(area.isArchived, isTrue);
  });
}
