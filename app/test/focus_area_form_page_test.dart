import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
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
    await tester.enterText(find.byKey(const Key('target-minutes-1')), '90');
    await tester.ensureVisible(find.byKey(const Key('focus-area-submit')));
    await tester.tap(find.byKey(const Key('focus-area-submit')));
    await tester.pump();

    expect(find.byKey(const Key('focus-area-form-saving')), findsOneWidget);
    expect(repository.created?.name, 'Deep work');
    expect(repository.created?.targets.single.weekday, DateTime.monday);
    expect(repository.created?.targets.single.targetMinutes, 90);

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
    expect(find.text('New Focus Area'), findsOneWidget);
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
    expect(find.text('New Focus Area'), findsOneWidget);

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
            body: FocusAreaForm(
              initialData: FocusAreaFormData.empty(),
              submitLabel: 'Create',
              onChanged: (_) {},
              onSubmit: (_) {},
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

FocusArea area({String name = 'Existing area'}) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: 1,
    name: name,
    priority: 2,
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
  Future<FocusArea> archive(int id) => throw UnimplementedError();

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
