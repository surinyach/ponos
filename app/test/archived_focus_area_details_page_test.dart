import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/archived_focus_area_details_page.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_state.dart';

void main() {
  testWidgets('shows read-only archived details and seven weekday targets', (
    tester,
  ) async {
    final area = archivedArea();
    await pumpDetails(tester, FakeDetailsRepository(area), area);

    expect(find.text('Archived project'), findsOneWidget);
    expect(find.text('An archived description'), findsOneWidget);
    expect(find.text('Daily targets (last configured)'), findsOneWidget);
    expect(find.byKey(const Key('archived-target-monday')), findsOneWidget);
    expect(find.byKey(const Key('archived-target-sunday')), findsOneWidget);
    expect(find.text('2h 00m'), findsOneWidget);
    expect(find.text('15 Jul 2026'), findsOneWidget);
    expect(find.text('20 Jul 2026'), findsOneWidget);
    expect(find.text('Total focused time'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows an explicit empty description and missing finish date', (
    tester,
  ) async {
    final area = archivedArea(description: null, includeTargetEndDate: false);
    await pumpDetails(tester, FakeDetailsRepository(area), area);

    expect(find.text('No description provided.'), findsOneWidget);
    expect(find.text('No finish date'), findsOneWidget);
  });

  testWidgets('restores and returns to the archived list route', (
    tester,
  ) async {
    final area = archivedArea();
    final repository = FakeDetailsRepository(area);
    await pumpDetails(tester, repository, area);

    final restore = find.byKey(
      const Key('restore-archived-focus-area-details'),
    );
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(repository.restoredId, area.id);
    expect(find.byKey(const Key('open-details')), findsOneWidget);
  });

  testWidgets('keeps details open and reports restore failures', (
    tester,
  ) async {
    final area = archivedArea();
    final repository = FakeDetailsRepository(area)..failRestore = true;
    await pumpDetails(tester, repository, area);

    final restore = find.byKey(
      const Key('restore-archived-focus-area-details'),
    );
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(find.text('Archived project'), findsOneWidget);
    expect(find.text('Restore failed'), findsOneWidget);
  });

  testWidgets('deletes after the existing confirmation and returns', (
    tester,
  ) async {
    final area = archivedArea();
    final repository = FakeDetailsRepository(area);
    await pumpDetails(tester, repository, area);

    final delete = find.byKey(
      const Key('delete-archived-focus-area-details'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently').last);
    await tester.pumpAndSettle();

    expect(repository.deletedId, area.id);
    expect(find.byKey(const Key('open-details')), findsOneWidget);
  });

  testWidgets('requires the historical-data warning before deletion', (
    tester,
  ) async {
    final area = archivedArea();
    final repository = FakeDetailsRepository(area)..historicalWork = true;
    await pumpDetails(tester, repository, area);

    final delete = find.byKey(
      const Key('delete-archived-focus-area-details'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently').last);
    await tester.pumpAndSettle();

    expect(find.text('Delete historical work too?'), findsOneWidget);
    await tester.tap(find.text('Delete all permanently'));
    await tester.pumpAndSettle();
    expect(repository.confirmedHistoricalWork, isTrue);
  });

  testWidgets('keeps details open after deletion failure', (tester) async {
    final area = archivedArea();
    final repository = FakeDetailsRepository(area)..failDelete = true;
    await pumpDetails(tester, repository, area);

    final delete = find.byKey(
      const Key('delete-archived-focus-area-details'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently').last);
    await tester.pumpAndSettle();

    expect(find.text('Archived project'), findsOneWidget);
    expect(find.text('Delete failed'), findsOneWidget);
  });

  testWidgets('blocks deletion while the linked timer is active', (
    tester,
  ) async {
    final area = archivedArea();
    await pumpDetails(
      tester,
      FakeDetailsRepository(area),
      area,
      activeTimerFocusAreaId: area.id,
    );

    final delete = find.byKey(
      const Key('delete-archived-focus-area-details'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This Focus Area cannot be deleted while its timer is active or paused.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('back navigation returns to the archived list route', (
    tester,
  ) async {
    final area = archivedArea();
    await pumpDetails(tester, FakeDetailsRepository(area), area);

    await tester.tap(
      find.byKey(const Key('back-from-archived-focus-area-details')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-details')), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(500, 700),
    Size(768, 1024),
    Size(1440, 900),
  ]) {
    testWidgets(
      'details remain overflow free at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final area = archivedArea();
        await pumpDetails(tester, FakeDetailsRepository(area), area, size: size);

        expect(
          find.byKey(const Key('archived-focus-area-details-scroll-view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('supports 200% text scaling and 48px action targets', (
    tester,
  ) async {
    final area = archivedArea();
    await pumpDetails(
      tester,
      FakeDetailsRepository(area),
      area,
      textScaler: const TextScaler.linear(2),
    );

    final restore = tester.getRect(
      find.byKey(const Key('restore-archived-focus-area-details')),
    );
    final delete = tester.getRect(
      find.byKey(const Key('delete-archived-focus-area-details')),
    );
    expect(restore.height, greaterThanOrEqualTo(48));
    expect(delete.height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(
      find.byKey(const Key('restore-archived-focus-area-details')),
    );
    await tester.pump();
    expect(
      tester.getRect(
        find.byKey(const Key('restore-archived-focus-area-details')),
      ).bottom,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> pumpDetails(
  WidgetTester tester,
  FakeDetailsRepository repository,
  FocusArea area, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  int? activeTimerFocusAreaId,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        focusAreaRepositoryProvider.overrideWithValue(repository),
        focusTimerProvider.overrideWith(
          () => TestFocusTimerController(activeTimerFocusAreaId),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-details'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: PonosViewportScope(
                        size: size,
                        child: ArchivedFocusAreaDetailsPage(area: area),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-details')));
  await tester.pumpAndSettle();
}

FocusArea archivedArea({
  String? description = 'An archived description',
  bool includeTargetEndDate = true,
}) {
  final archivedAt = DateTime.utc(2026, 7, 20, 12);
  return FocusArea(
    id: 7,
    name: 'Archived project',
    description: description,
    priority: 1,
    targetEndDate: includeTargetEndDate ? DateTime(2026, 7, 15) : null,
    archivedAt: archivedAt,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: archivedAt,
    targets: [
      FocusAreaTarget(
        id: 1,
        focusAreaId: 7,
        weekday: DateTime.monday,
        targetMinutes: 60,
        validFrom: DateTime(2026, 1, 1),
        validUntil: DateTime(2026, 5, 31),
      ),
      FocusAreaTarget(
        id: 2,
        focusAreaId: 7,
        weekday: DateTime.monday,
        targetMinutes: 120,
        validFrom: DateTime(2026, 6, 1),
      ),
      for (var weekday = DateTime.tuesday; weekday <= DateTime.sunday; weekday++)
        FocusAreaTarget(
          id: weekday + 10,
          focusAreaId: 7,
          weekday: weekday,
          targetMinutes: weekday <= DateTime.friday ? 90 : 0,
          validFrom: DateTime(2026, 1, 1),
        ),
    ],
  );
}

class TestFocusTimerController extends FocusTimerController {
  TestFocusTimerController(this.focusAreaId);

  final int? focusAreaId;

  @override
  FocusTimerState build() {
    if (focusAreaId == null) return const FocusTimerState.inactive();
    return FocusTimerState(
      status: FocusTimerStatus.paused,
      activeTimer: ActiveFocusTimer(
        focusAreaId: focusAreaId,
        workDate: DateTime(2026, 7, 20),
        startedAt: DateTime.utc(2026, 7, 20, 8),
        startedAtUtcOffset: const Duration(hours: 2),
        focusDuration: const Duration(minutes: 25),
        restDuration: const Duration(minutes: 5),
        phase: FocusTimerPhase.focus,
        activity: FocusTimerActivity.paused,
        accumulatedFocusTime: const Duration(minutes: 2),
        accumulatedRestTime: Duration.zero,
        focusTransitionNotified: false,
      ),
    );
  }
}

class FakeDetailsRepository implements FocusAreaRepository {
  FakeDetailsRepository(this.area);

  final FocusArea area;
  bool failRestore = false;
  bool failDelete = false;
  bool historicalWork = false;
  int? restoredId;
  int? deletedId;
  bool? confirmedHistoricalWork;

  @override
  Future<List<FocusArea>> getActive() async => const [];

  @override
  Future<List<FocusArea>> getArchived() async => [area];

  @override
  Future<FocusArea> restore(int id) async {
    if (failRestore) throw const ServerException('Restore failed');
    restoredId = id;
    return FocusArea(
      id: area.id,
      name: area.name,
      description: area.description,
      priority: area.priority,
      targetEndDate: area.targetEndDate,
      createdAt: area.createdAt,
      updatedAt: area.updatedAt,
      targets: area.targets,
    );
  }

  @override
  Future<bool> hasHistoricalWork(int id) async => historicalWork;

  @override
  Future<void> permanentlyDelete(
    int id, {
    required bool confirmHistoricalWork,
  }) async {
    if (failDelete) throw const ServerException('Delete failed');
    deletedId = id;
    confirmedHistoricalWork = confirmHistoricalWork;
  }

  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) =>
      throw UnimplementedError();
  @override
  Future<FocusArea> getById(int id) => throw UnimplementedError();
  @override
  Future<FocusArea> create(FocusAreaCreateInput input) =>
      throw UnimplementedError();
  @override
  Future<FocusArea> update(int id, FocusAreaUpdateInput input) =>
      throw UnimplementedError();
  @override
  Future<FocusArea> archive(int id) => throw UnimplementedError();
  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> priorities,
  ) => throw UnimplementedError();
}
