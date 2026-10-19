import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/app/providers/work_entry_providers.dart';
import 'package:ponos_app/core/errors/app_exception.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/work_entries/domain/models/manual_work_entry.dart';
import 'package:ponos_app/features/work_entries/domain/models/special_activity.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/manual_work_entry_repository.dart';
import 'package:ponos_app/features/work_entries/domain/repositories/special_activity_repository.dart';
import 'package:ponos_app/features/work_entries/presentation/log_work_page.dart';
import 'package:ponos_app/features/work_entries/presentation/create_special_activity_page.dart';
import 'package:ponos_app/features/work_entries/presentation/special_activities_page.dart';
import 'package:ponos_app/features/focus_timer/domain/models/active_focus_timer.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_controller.dart';
import 'package:ponos_app/features/focus_timer/presentation/state/focus_timer_state.dart';

void main() {
  late FakeManualEntries entries;
  late FakeSpecialActivities activities;

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 800),
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
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

  Future<void> pumpSpecialActivities(
    WidgetTester tester, {
    Size size = const Size(390, 800),
    bool embedded = false,
    double textScale = 1,
    int? activeSpecialActivityId,
    FocusTimerStatus activeTimerStatus = FocusTimerStatus.paused,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          specialActivityRepositoryProvider.overrideWithValue(activities),
          focusTimerProvider.overrideWith(
            () => StaticFocusTimerController(
              activeSpecialActivityId,
              activeTimerStatus,
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: SpecialActivitiesPage(
                embedded: embedded,
                onSelected: (activity) => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateSpecialActivityPage(activity: activity),
                  ),
                ),
                onCreate: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const CreateSpecialActivityPage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    entries = FakeManualEntries();
    activities = FakeSpecialActivities();
  });

  testWidgets('embedded create action aligns with compact activity cards', (
    tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ];

    for (final size in sizes) {
      await pumpSpecialActivities(tester, size: size, embedded: true);

      final button = tester.getRect(
        find.byKey(const Key('new-special-activity')),
      );
      final card = tester.getRect(
        find.ancestor(
          of: find.text('Release day'),
          matching: find.byType(Card),
        ),
      );

      expect(button.left, closeTo(card.left, 0.1));
      expect(button.right, closeTo(card.right, 0.1));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(card.top - button.bottom, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
  });

  testWidgets('embedded create action remains accessible at 200 percent', (
    tester,
  ) async {
    await pumpSpecialActivities(
      tester,
      size: const Size(390, 844),
      embedded: true,
      textScale: 2,
    );

    final button = tester.getRect(
      find.byKey(const Key('new-special-activity')),
    );
    final card = tester.getRect(
      find.ancestor(of: find.text('Release day'), matching: find.byType(Card)),
    );
    expect(button.left, closeTo(card.left, 0.1));
    expect(button.right, closeTo(card.right, 0.1));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(card.top - button.bottom, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Special Activities load errors are announced and retryable', (
    tester,
  ) async {
    activities.loadError = const NetworkException('Activities unavailable');
    await pumpSpecialActivities(tester, embedded: true);

    expect(find.text('Activities unavailable'), findsOneWidget);
    expect(find.byKey(const Key('retry-special-activities')), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const Key('special-activity-delete-error')),
    );
    expect(semantics.flagsCollection.isLiveRegion, isTrue);

    activities.loadError = null;
    await tester.tap(find.byKey(const Key('retry-special-activities')));
    await tester.pumpAndSettle();

    expect(find.text('Release day'), findsOneWidget);
    expect(find.text('Activities unavailable'), findsNothing);
    expect(activities.loadCalls, 2);
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

    await tester.tap(find.byKey(const Key('work-subject-focusArea')));
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

  testWidgets('rejects out-of-range seconds before saving on web', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1100, 800));
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject-focusArea')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Placement').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-seconds')), '60');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pump();

    expect(find.text('Use 0–59'), findsOneWidget);
    expect(entries.created, isNull);
  });

  testWidgets('creates for a Special Activity on a chosen date', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1100, 800));
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing special'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject-existingSpecial')));
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
    await tester.tap(find.byKey(const Key('work-subject-focusArea')));
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
    await tester.tap(find.byKey(const Key('work-subject-focusArea')));
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

  testWidgets('creates a Special Activity without logging time', (
    tester,
  ) async {
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-date')), findsNothing);
    expect(find.byKey(const Key('focus-minutes')), findsNothing);
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(activities.createCalls, 0);

    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Conference',
    );
    await tester.enterText(
      find.byKey(const Key('special-activity-description')),
      'Talk prep',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();

    expect(activities.createCalls, 1);
    expect(activities.created!.name, 'Conference');
    expect(activities.created!.description, 'Talk prep');
    expect(entries.created, isNull);

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing special'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject-existingSpecial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conference').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-minutes')), '25');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();
    expect(entries.created!.specialActivityId, 5);
  });

  testWidgets('entry save failure does not recreate an existing activity', (
    tester,
  ) async {
    entries.failSave = true;
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Conference',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();
    expect(activities.createCalls, 1);
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('new-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing special'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-subject-existingSpecial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conference').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rest-minutes')), '10');
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-save-error')), findsOneWidget);

    entries.failSave = false;
    await tester.ensureVisible(find.byKey(const Key('save-work-entry')));
    await tester.tap(find.byKey(const Key('save-work-entry')));
    await tester.pumpAndSettle();
    expect(activities.createCalls, 1);
    expect(entries.created!.specialActivityId, 5);
    expect(find.byKey(const Key('save-work-entry')), findsNothing);
  });

  testWidgets('activity creation failure keeps creation form open', (
    tester,
  ) async {
    activities.failCreate = true;
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Conference',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('special-activity-save-error')),
      findsOneWidget,
    );
    expect(entries.created, isNull);
  });

  testWidgets('shows a clear duplicate Special Activity name error', (
    tester,
  ) async {
    activities.createError = const ConflictException(
      'A Special Activity with this name already exists',
    );
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Release day',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();
    expect(
      find.text('A Special Activity with this name already exists'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('special-activity-name')), findsOneWidget);
  });

  testWidgets('selecting an activity opens and saves the populated edit form', (
    tester,
  ) async {
    await pumpSpecialActivities(tester);
    await tester.tap(find.text('Release day'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Special Activity'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('special-activity-name')),
          )
          .controller!
          .text,
      'Release day',
    );
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Conference',
    );
    await tester.enterText(
      find.byKey(const Key('special-activity-description')),
      'Annual event',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();

    expect(activities.updatedId, 4);
    expect(activities.updated?.name, 'Conference');
    expect(activities.updated?.description.value, 'Annual event');
    expect(find.text('Conference'), findsOneWidget);
  });

  testWidgets('edit form back returns to the Special Activities list', (
    tester,
  ) async {
    await pumpSpecialActivities(tester);
    await tester.tap(find.text('Release day'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Special Activity'), findsOneWidget);
    await tester.tap(find.byKey(const Key('special-activity-back')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Special Activity'), findsNothing);
    expect(find.text('Special Activities'), findsOneWidget);
    expect(find.text('Release day'), findsOneWidget);
  });

  testWidgets('edit failure remains visible and unsaved back requires confirmation', (
    tester,
  ) async {
    activities.failUpdate = true;
    await pumpSpecialActivities(tester);
    await tester.tap(find.text('Release day'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Duplicate',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();
    expect(find.text('Activity update failed'), findsOneWidget);
    expect(find.text('Edit Special Activity'), findsOneWidget);

    await tester.tap(find.byKey(const Key('special-activity-back')));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-discard-special-activity')));
    await tester.pumpAndSettle();
    expect(find.text('Special Activities'), findsOneWidget);
  });

  testWidgets('edit form deletes only after confirmation and returns to list', (
    tester,
  ) async {
    await pumpSpecialActivities(tester);
    await tester.tap(find.text('Release day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-special-activity')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Release day?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-special-activity')));
    await tester.pumpAndSettle();
    expect(activities.deletedId, 4);
    expect(find.text('Edit Special Activity'), findsNothing);
  });

  testWidgets('edit form keeps referenced-work deletion errors actionable', (
    tester,
  ) async {
    activities.failDelete = true;
    await pumpSpecialActivities(tester);
    await tester.tap(find.text('Release day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-special-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-special-activity')));
    await tester.pumpAndSettle();
    expect(
      find.text('Special Activity has recorded work and cannot be deleted'),
      findsOneWidget,
    );
    expect(find.text('Edit Special Activity'), findsOneWidget);
  });

  testWidgets('Special Activity form is card-free and responsive', (
    tester,
  ) async {
    const sizes = [
      Size(390, 844),
      Size(500, 700),
      Size(768, 1024),
      Size(1440, 900),
    ];
    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            specialActivityRepositoryProvider.overrideWithValue(activities),
            focusTimerProvider.overrideWith(
              () => StaticFocusTimerController(null, FocusTimerStatus.inactive),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light.copyWith(
              platform: size.width == 390
                  ? TargetPlatform.android
                  : TargetPlatform.windows,
            ),
            home: PonosViewportScope(
              size: size,
              child: const Scaffold(body: CreateSpecialActivityPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing, reason: 'viewport: $size');
      expect(
        tester.getRect(find.byKey(const Key('save-special-activity'))).height,
        greaterThanOrEqualTo(48),
      );
      final nameField = tester.getRect(
        find.byKey(const Key('special-activity-name')),
      );
      if (size.width >= 768) {
        expect(nameField.width, closeTo(620, 0.1));
        expect(nameField.center.dx, closeTo(size.width / 2, 0.1));
        expect(
          tester.getRect(find.byKey(const Key('special-activity-back'))).left,
          closeTo(size.width >= 840 ? 40 : 20, 0.1),
        );

        final primary = tester.getRect(
          find.byKey(const Key('save-special-activity')),
        );
        final secondary = tester.getRect(
          find.byKey(const Key('cancel-special-activity')),
        );
        expect(primary.width, closeTo(200, 0.1));
        expect(secondary.width, closeTo(200, 0.1));
        expect(secondary.left - primary.right, closeTo(12, 0.1));
        expect(
          (primary.left + secondary.right) / 2,
          closeTo(nameField.center.dx, 0.1),
        );
      } else if (size.width == 390) {
        expect(nameField.left, closeTo(16, 0.1));
        expect(nameField.right, closeTo(374, 0.1));
      }
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Special Activity form remains reachable at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          specialActivityRepositoryProvider.overrideWithValue(activities),
          focusTimerProvider.overrideWith(
            () => StaticFocusTimerController(null, FocusTimerStatus.inactive),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: CreateSpecialActivityPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('cancel-special-activity')),
    );
    expect(
      tester.getRect(find.byKey(const Key('cancel-special-activity'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes an unused Special Activity only after confirmation', (
    tester,
  ) async {
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-activity-name')),
      'Conference',
    );
    await tester.tap(find.byKey(const Key('save-special-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-special-activity-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(activities.deletedId, isNull);
    await tester.tap(find.byKey(const Key('delete-special-activity-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-special-activity')));
    await tester.pumpAndSettle();
    expect(activities.deletedId, 5);
    expect(find.text('Conference'), findsNothing);
  });

  testWidgets('shows referenced-work conflict without removing activity', (
    tester,
  ) async {
    activities.failDelete = true;
    await pumpSpecialActivities(tester);
    await tester.tap(find.byKey(const Key('delete-special-activity-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-special-activity')));
    await tester.pumpAndSettle();
    expect(
      find.text('Special Activity has recorded work and cannot be deleted'),
      findsOneWidget,
    );
    expect(find.text('Release day'), findsOneWidget);
  });

  testWidgets('Special Activity creation remains usable on a narrow phone', (
    tester,
  ) async {
    await pumpSpecialActivities(tester, size: const Size(320, 700));
    await tester.tap(find.byKey(const Key('new-special-activity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('special-activity-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks deletion while a Special Activity timer is active', (
    tester,
  ) async {
    await pumpSpecialActivities(tester, activeSpecialActivityId: 4);
    await tester.tap(find.byKey(const Key('delete-special-activity-4')));
    await tester.pump();
    expect(
      find.text(
        'This Special Activity is linked to the active timer. Stop or reset it before deleting.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('confirm-delete-special-activity')),
      findsNothing,
    );
    expect(activities.deletedId, isNull);
  });

  testWidgets('blocks deletion while a Special Activity timer is running', (
    tester,
  ) async {
    await pumpSpecialActivities(
      tester,
      activeSpecialActivityId: 4,
      activeTimerStatus: FocusTimerStatus.running,
    );
    await tester.tap(find.byKey(const Key('delete-special-activity-4')));
    await tester.pump();
    expect(find.textContaining('linked to the active timer'), findsOneWidget);
    expect(activities.deletedId, isNull);
  });

  testWidgets('Log Work exposes logging only, not area management', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('new-work-entry')), findsOneWidget);
    expect(find.byKey(const Key('new-special-activity')), findsNothing);
    expect(find.byKey(const Key('manage-special-activities')), findsNothing);
  });
}

class StaticFocusTimerController extends FocusTimerController {
  StaticFocusTimerController(this.specialActivityId, this.timerStatus);
  final int? specialActivityId;
  final FocusTimerStatus timerStatus;

  @override
  FocusTimerState build() {
    if (specialActivityId == null) return const FocusTimerState.inactive();
    final timer = ActiveFocusTimer(
      specialActivityId: specialActivityId,
      workDate: DateTime(2026, 9, 21),
      startedAt: DateTime.utc(2026, 9, 21, 8),
      startedAtUtcOffset: const Duration(hours: 2),
      focusDuration: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 5),
      phase: FocusTimerPhase.focus,
      activity: timerStatus == FocusTimerStatus.running
          ? FocusTimerActivity.running
          : FocusTimerActivity.paused,
      accumulatedFocusTime: const Duration(minutes: 2),
      accumulatedRestTime: Duration.zero,
      focusTransitionNotified: false,
      runningSince: timerStatus == FocusTimerStatus.running
          ? DateTime.utc(2026, 9, 21, 8)
          : null,
    );
    return FocusTimerState(
      status: timerStatus,
      activeTimer: timer,
      elapsedFocusTime: const Duration(minutes: 2),
    );
  }
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
  SpecialActivityCreateInput? created;
  int createCalls = 0;
  bool failCreate = false;
  Object? createError;
  bool failDelete = false;
  bool failUpdate = false;
  int? deletedId;
  int? updatedId;
  SpecialActivityUpdateInput? updated;
  Object? loadError;
  int loadCalls = 0;
  final List<SpecialActivity> values = [];
  @override
  Future<List<SpecialActivity>> getActive() async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    return [SpecialActivity(id: 4, name: 'Release day'), ...values];
  }
  @override
  Future<SpecialActivity> getById(int id) => throw UnimplementedError();
  @override
  Future<SpecialActivity> create(SpecialActivityCreateInput input) async {
    createCalls++;
    created = input;
    if (failCreate) throw const ValidationException('Activity failed');
    if (createError != null) throw createError!;
    final activity = SpecialActivity(
      id: 5,
      name: input.name,
      description: input.description,
    );
    values.add(activity);
    return activity;
  }

  @override
  Future<SpecialActivity> update(
    int id,
    SpecialActivityUpdateInput input,
  ) async {
    if (failUpdate) throw const ConflictException('Activity update failed');
    updatedId = id;
    updated = input;
    return SpecialActivity(
      id: id,
      name: input.name ?? 'Release day',
      description: input.description.isPresent
          ? input.description.value
          : null,
    );
  }
  @override
  Future<void> delete(int id) async {
    if (failDelete) {
      throw const ConflictException(
        'Special Activity has recorded work and cannot be deleted',
      );
    }
    deletedId = id;
    values.removeWhere((activity) => activity.id == id);
  }
}

class FakeFocusAreas implements FocusAreaRepository {
  @override
  Future<bool> hasHistoricalWork(int id) => throw UnimplementedError();
  @override
  Future<void> permanentlyDelete(
    int id, {
    required bool confirmHistoricalWork,
  }) => throw UnimplementedError();
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
