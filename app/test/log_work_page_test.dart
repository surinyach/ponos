import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/providers/work_entry_providers.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/work_entries/domain/models/manual_work_entry.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/manual_work_entry_repository.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/special_activity_repository.dart';
import 'package:ponos_app/features/work_entries/presentation/log_work_page.dart';

void main() {
  late FakeManualEntries entries;
  late FakeSpecialActivities activities;

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manualWorkEntryRepositoryProvider.overrideWithValue(entries),
          specialActivityRepositoryProvider.overrideWithValue(activities),
          focusAreaRepositoryProvider.overrideWithValue(FakeFocusAreas()),
        ],
        child: const MaterialApp(home: Scaffold(body: LogWorkPage())),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    entries = FakeManualEntries();
    activities = FakeSpecialActivities();
  });

  testWidgets('creates an entry for a Focus Area and rejects zero time', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pump();
    expect(find.text('Select an activity'), findsOneWidget);

    await tester.tap(find.byKey(const Key('work-subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Placement').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pump();
    expect(find.text('Enter focused or rest time.'), findsOneWidget);
    expect(entries.created, isNull);

    await tester.enterText(find.byKey(const Key('focus-minutes')), '45');
    await tester.enterText(find.byKey(const Key('rest-seconds')), '30');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();

    expect(entries.created!.focusAreaId, 7);
    expect(entries.created!.specialActivityId, isNull);
    expect(entries.created!.focusedTime, const Duration(minutes: 45));
    expect(entries.created!.restTime, const Duration(seconds: 30));
    expect(find.text('Placement'), findsOneWidget);
  });

  testWidgets('creates for a Special Activity on a chosen date', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1100, 800));
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rest-minutes')), '10');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();

    expect(entries.created!.specialActivityId, 4);
    expect(entries.created!.focusAreaId, isNull);
    expect(entries.created!.workDate.day, 15);
    expect(entries.created!.restTime, const Duration(minutes: 10));
  });

  testWidgets('edits an entry without changing its owner or dropping seconds', (
    tester,
  ) async {
    entries.values = [sampleEntry()];
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Edit entry'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Minutes'), findsWidgets);
    expect(find.text('Work date: 2026-09-09'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rest-minutes')), '5');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();

    expect(entries.updated!.changeOwner, isFalse);
    expect(
      entries.updated!.focusedTime,
      const Duration(minutes: 2, seconds: 3),
    );
    expect(entries.updated!.restTime, const Duration(minutes: 5));
  });

  testWidgets('deletes only after confirmation', (tester) async {
    entries.values = [sampleEntry()];
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(entries.deletedId, isNull);
    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-work-entry')));
    await tester.pumpAndSettle();
    expect(entries.deletedId, 12);
    expect(
      find.text('No work entries yet. Add your first entry.'),
      findsOneWidget,
    );
  });

  testWidgets('shows backend error and keeps the form open', (tester) async {
    entries.failSave = true;
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Placement').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-minutes')), '1');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-save-error')), findsOneWidget);
    expect(find.byKey(const Key('save-work-entry')), findsOneWidget);
  });

  testWidgets('shows saving state until the repository finishes', (
    tester,
  ) async {
    final pending = Completer<void>();
    entries.pendingSave = pending.future;
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Placement').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-minutes')), '1');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('work-form-saving')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-work-entry')))
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-form-saving')), findsNothing);
  });
}

ManualWorkEntry sampleEntry() => ManualWorkEntry(
  id: 12,
  focusAreaId: 7,
  workDate: DateTime(2026, 9, 9),
  focusedTime: const Duration(minutes: 2, seconds: 3),
  restTime: Duration.zero,
);

class FakeManualEntries implements ManualWorkEntryRepository {
  List<ManualWorkEntry> values = [];
  ManualWorkEntryCreateInput? created;
  ManualWorkEntryUpdateInput? updated;
  int? deletedId;
  bool failSave = false;
  Future<void>? pendingSave;

  @override
  Future<List<ManualWorkEntry>> getAll() async => values;
  @override
  Future<ManualWorkEntry> create(ManualWorkEntryCreateInput input) async {
    created = input;
    if (pendingSave != null) await pendingSave;
    if (failSave) throw const ValidationException('Save failed');
    final value = ManualWorkEntry(
      id: 12,
      focusAreaId: input.focusAreaId,
      specialActivityId: input.specialActivityId,
      workDate: input.workDate,
      focusedTime: input.focusedTime,
      restTime: input.restTime,
    );
    values = [...values, value];
    return value;
  }

  @override
  Future<ManualWorkEntry> update(
    int id,
    ManualWorkEntryUpdateInput input,
  ) async {
    updated = input;
    final value = ManualWorkEntry(
      id: id,
      focusAreaId: input.focusAreaId,
      specialActivityId: input.specialActivityId,
      workDate: input.workDate!,
      focusedTime: input.focusedTime!,
      restTime: input.restTime!,
    );
    values = [value];
    return value;
  }

  @override
  Future<void> delete(int id) async {
    deletedId = id;
    values = values.where((entry) => entry.id != id).toList();
  }
}

class FakeSpecialActivities implements SpecialActivityRepository {
  @override
  Future<List<SpecialActivity>> getActive() async => [
    SpecialActivity(
      id: 4,
      name: 'Release day',
      workDate: DateTime(2026, 9, 9),
      isArchived: false,
    ),
  ];
  @override
  Future<List<SpecialActivity>> getArchived() async => [];
  @override
  Future<SpecialActivity> getById(int id) => throw UnimplementedError();
  @override
  Future<SpecialActivity> create(SpecialActivityCreateInput input) =>
      throw UnimplementedError();
  @override
  Future<SpecialActivity> update(int id, SpecialActivityUpdateInput input) =>
      throw UnimplementedError();
  @override
  Future<SpecialActivity> archive(int id) => throw UnimplementedError();
  @override
  Future<SpecialActivity> restore(int id) => throw UnimplementedError();
}

class FakeFocusAreas implements FocusAreaRepository {
  @override
  Future<List<FocusArea>> getActive() async => [
    FocusArea(
      id: 7,
      name: 'Placement',
      priority: 1,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      targets: const [],
    ),
  ];
  @override
  Future<List<FocusArea>> getArchived() async => [];
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
  Future<FocusArea> restore(int id) => throw UnimplementedError();
  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> priorities,
  ) => throw UnimplementedError();
  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) =>
      throw UnimplementedError();
}
