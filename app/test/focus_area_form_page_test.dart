import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_target.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/focus_areas/presentation/focus_area_form_data.dart';
import 'package:ponos_app/features/focus_areas/presentation/focus_area_form_page.dart';

void main() {
  test('empty Focus Area form contains exactly seven weekdays', () {
    expect(FocusAreaFormData.empty().targets, hasLength(7));
  });

  testWidgets('validates required fields and weekday targets', (tester) async {
    final repository = FormRepository();
    await openForm(tester, repository);

    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pump();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enable at least one weekday'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('requires positive minutes for an enabled weekday', (
    tester,
  ) async {
    final repository = FormRepository();
    await openForm(tester, repository);

    await tester.enterText(find.byKey(const Key('focus-area-name')), 'Area');
    await tester.tap(find.byKey(const Key('target-enabled-1')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('target-minutes-1')), '0');
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pump();

    expect(find.text('Must be at least 1 minute'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('creates through Riverpod and exposes the saving state', (
    tester,
  ) async {
    final pending = Completer<FocusArea>();
    final repository = FormRepository()..createResult = pending.future;
    await openForm(tester, repository);

    await tester.enterText(
      find.byKey(const Key('focus-area-name')),
      'Deep work',
    );
    await tester.tap(find.byKey(const Key('target-enabled-1')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('target-minutes-1')), '7');
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pump();

    expect(find.byKey(const Key('focus-area-form-saving')), findsOneWidget);
    expect(repository.created?.name, 'Deep work');
    expect(repository.created?.targets.single.weekday, DateTime.monday);
    expect(repository.created?.targets.single.targetMinutes, 7);

    pending.complete(area(name: 'Deep work'));
    await tester.pumpAndSettle();
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('pre-fills edit values and updates through Riverpod', (
    tester,
  ) async {
    final repository = FormRepository();
    await openForm(tester, repository, editing: area());

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('focus-area-name')),
    );
    expect(nameField.controller?.text, 'Existing area');
    expect(find.text('Edit Focus Area'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('focus-area-name')),
      'Renamed area',
    );
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pumpAndSettle();

    expect(repository.updated?.name, 'Renamed area');
    expect(repository.updated?.targets, isNull);
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('keeps the form open and maps backend errors', (tester) async {
    final repository = FormRepository()
      ..createError = const ValidationException('Target period conflicts');
    await openForm(tester, repository);

    await tester.enterText(find.byKey(const Key('focus-area-name')), 'Area');
    await tester.tap(find.byKey(const Key('target-enabled-1')));
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-area-form-error')), findsOneWidget);
    expect(find.text('Target period conflicts'), findsOneWidget);
    expect(find.byKey(const Key('focus-area-form-title')), findsOneWidget);
  });

  testWidgets('protects unsaved changes before leaving', (tester) async {
    await openForm(tester, FormRepository());
    await tester.enterText(find.byKey(const Key('focus-area-name')), 'Draft');
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-area-form-title')), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('uses two columns on web and one column on mobile', (
    tester,
  ) async {
    Future<void> pumpAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FocusAreaForm(
                initialData: FocusAreaFormData.empty(),
                submitLabel: 'Create',
                onChanged: (_) {},
                onSubmit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAt(const Size(1100, 900));
    final wideDetails = tester.getTopLeft(find.text('Details')).dy;
    final wideTargets = tester.getTopLeft(find.text('Weekly targets')).dy;
    expect(wideDetails, wideTargets);

    await pumpAt(const Size(390, 900));
    final mobileDetails = tester.getTopLeft(find.text('Details')).dy;
    final mobileTargets = tester.getTopLeft(find.text('Weekly targets')).dy;
    expect(mobileTargets, greaterThan(mobileDetails));
  });

  testWidgets('weekday rows use eight pixels of whitespace without dividers', (
    tester,
  ) async {
    await openForm(tester, FormRepository());

    final monday = tester.getRect(find.byKey(const Key('target-row-1')));
    final tuesday = tester.getRect(find.byKey(const Key('target-row-2')));

    expect(monday.height, greaterThanOrEqualTo(AppSpacing.minimumTouchTarget));
    expect(tuesday.top - monday.bottom, AppSpacing.xs);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('weekday spacing survives enabled, focused, and error states', (
    tester,
  ) async {
    await openForm(tester, FormRepository());
    await tester.tap(find.byKey(const Key('target-enabled-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('target-minutes-1')));
    await tester.enterText(find.byKey(const Key('target-minutes-1')), '0');
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('target-row-1')));

    final monday = tester.getRect(find.byKey(const Key('target-row-1')));
    final tuesday = tester.getRect(find.byKey(const Key('target-row-2')));
    expect(find.text('Must be at least 1 minute'), findsOneWidget);
    expect(tuesday.top - monday.bottom, AppSpacing.xs);
    expect(monday.height, greaterThan(AppSpacing.minimumTouchTarget));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('creates with an explicitly selected P1-P5 priority', (
    tester,
  ) async {
    final repository = FormRepository();
    await openForm(tester, repository);

    expect(find.byKey(const Key('focus-area-priority-1')), findsOneWidget);
    expect(find.byKey(const Key('focus-area-priority-5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-area-priority-4')));
    await tester.enterText(find.byKey(const Key('focus-area-name')), 'Area');
    await tester.tap(find.byKey(const Key('target-enabled-1')));
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pumpAndSettle();

    expect(repository.created?.priority, 4);
  });

  testWidgets('preserves a legacy priority above P5 on unrelated edits', (
    tester,
  ) async {
    final repository = FormRepository();
    await openForm(tester, repository, editing: area(priority: 8));

    expect(find.byKey(const Key('focus-area-priority-8')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('focus-area-name')),
      'Renamed legacy area',
    );
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pumpAndSettle();

    expect(repository.updated?.name, 'Renamed legacy area');
    expect(repository.updated?.priority, isNull);
  });

  testWidgets('shows local-date expiration and not on the finish date', (
    tester,
  ) async {
    final repository = FormRepository();
    await openForm(
      tester,
      repository,
      editing: area(targetEndDate: DateTime(2026, 9, 6)),
    );

    expect(find.text('Expired 1 day ago'), findsOneWidget);
    expect(
      find.text('This Focus Area stays active until you archive it.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openForm(
      tester,
      FormRepository(),
      editing: area(targetEndDate: DateTime(2026, 9, 7)),
    );
    expect(
      find.byKey(const Key('focus-area-expiration-warning')),
      findsNothing,
    );
  });

  testWidgets('archives from edit after confirmation', (tester) async {
    final repository = FormRepository();
    await openForm(tester, repository, editing: area());

    await tester.ensureVisible(find.byKey(const Key('focus-area-secondary')));
    await tester.tap(find.byKey(const Key('focus-area-secondary')));
    await tester.pumpAndSettle();
    expect(find.text('Archive Existing area?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-archive-focus-area')));
    await tester.pumpAndSettle();

    expect(repository.archivedId, 1);
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('keeps edit open when archiving fails', (tester) async {
    final repository = FormRepository()
      ..archiveError = const ConflictException('Archive is unavailable');
    await openForm(tester, repository, editing: area());

    await tester.ensureVisible(find.byKey(const Key('focus-area-secondary')));
    await tester.tap(find.byKey(const Key('focus-area-secondary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-archive-focus-area')));
    await tester.pumpAndSettle();

    expect(find.text('Archive is unavailable'), findsOneWidget);
    expect(find.byKey(const Key('focus-area-form-title')), findsOneWidget);
  });

  testWidgets('date picker permits past finish dates', (tester) async {
    await openForm(tester, FormRepository());

    await tester.tap(find.byKey(const Key('focus-area-end-date')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.firstDate, DateTime(1900));
  });

  testWidgets('all weekday controls and actions remain reachable at 320px', (
    tester,
  ) async {
    final repository = FormRepository();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [focusAreaRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: FocusAreaFormPage(today: DateTime(2026, 9, 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('target-enabled-7')));
    expect(find.text('Sunday'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    expect(find.byKey(const Key('focus-area-secondary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile form remains reachable at 200 percent text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusAreaRepositoryProvider.overrideWithValue(FormRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: FocusAreaFormPage(today: DateTime(2026, 9, 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('target-enabled-7')));
    await tester.ensureVisible(find.byKey(const Key('focus-area-secondary')));
    expect(
      tester.getSize(find.byKey(const Key('focus-area-submit'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(390, 844),
    Size(500, 700),
    Size(768, 1024),
    Size(1440, 900),
  ]) {
    testWidgets(
      'form is overflow free and scrollable at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              focusAreaRepositoryProvider.overrideWithValue(FormRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: FocusAreaFormPage(today: DateTime(2026, 9, 7)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('target-enabled-7')));
        await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('edit input is partial and creates a historical target version', () {
    final existing = area();
    final initial = FocusAreaFormData.fromArea(existing, DateTime(2026, 9, 7));
    final changedTargets = [...initial.targets];
    changedTargets[0] = const WeekdayTargetFormData(
      enabled: true,
      minutes: 120,
    );
    final changed = FocusAreaFormData(
      name: initial.name,
      description: 'Updated description',
      priority: initial.priority,
      targetEndDate: initial.targetEndDate,
      targets: changedTargets,
    );

    final input = changed.toUpdateInput(
      existing,
      initial,
      DateTime(2026, 9, 7),
    );

    expect(input.name, isNull);
    expect(input.priority, isNull);
    expect(input.description.isChanged, isTrue);
    expect(input.description.value, 'Updated description');
    expect(input.targets, hasLength(1));
    expect(input.targets!.single.weekday, DateTime.monday);
    expect(input.targets!.single.targetMinutes, 120);
    expect(input.targets!.single.validFrom, DateTime(2026, 9, 8));
  });
}

Future<void> openForm(
  WidgetTester tester,
  FormRepository repository, {
  FocusArea? editing,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [focusAreaRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: _Launcher(area: editing),
      ),
    ),
  );
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

class _Launcher extends StatelessWidget {
  const _Launcher({this.area});
  final FocusArea? area;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                FocusAreaFormPage(area: area, today: DateTime(2026, 9, 7)),
          ),
        ),
        child: const Text('Open form'),
      ),
    ),
  );
}

FocusArea area({
  String name = 'Existing area',
  int priority = 2,
  DateTime? targetEndDate,
}) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: 1,
    name: name,
    priority: priority,
    targetEndDate: targetEndDate,
    createdAt: timestamp,
    updatedAt: timestamp,
    targets: [
      FocusAreaTarget(
        id: 1,
        focusAreaId: 1,
        weekday: DateTime.monday,
        targetMinutes: 60,
        validFrom: DateTime(2026, 9, 7),
      ),
    ],
  );
}

class FormRepository implements FocusAreaRepository {
  FocusAreaCreateInput? created;
  FocusAreaUpdateInput? updated;
  Future<FocusArea>? createResult;
  Object? createError;
  int? archivedId;
  Object? archiveError;

  @override
  Future<bool> hasHistoricalWork(int id) => throw UnimplementedError();

  @override
  Future<void> permanentlyDelete(
    int id, {
    required bool confirmHistoricalWork,
  }) => throw UnimplementedError();

  @override
  Future<List<FocusArea>> getActive() async => [];

  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) =>
      throw UnimplementedError();

  @override
  Future<FocusArea> create(FocusAreaCreateInput input) {
    created = input;
    if (createError != null) return Future.error(createError!);
    return createResult ?? Future.value(area(name: input.name));
  }

  @override
  Future<FocusArea> update(int id, FocusAreaUpdateInput input) async {
    updated = input;
    return area();
  }

  @override
  Future<FocusArea> archive(int id) async {
    archivedId = id;
    if (archiveError != null) throw archiveError!;
    return area();
  }

  @override
  Future<List<FocusArea>> getArchived() => throw UnimplementedError();

  @override
  Future<FocusArea> getById(int id) => throw UnimplementedError();

  @override
  Future<FocusArea> restore(int id) => throw UnimplementedError();

  @override
  Future<List<FocusArea>> updatePriorities(
    List<FocusAreaPriorityInput> priorities,
  ) => throw UnimplementedError();
}
