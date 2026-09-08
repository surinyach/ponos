import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/providers/focus_area_providers.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area.dart';
import 'package:ponos_app/features/focus_areas/domain/models/focus_area_input.dart';
import 'package:ponos_app/features/focus_areas/domain/models/today_overview.dart';
import 'package:ponos_app/features/focus_areas/domain/repositories/focus_area_repository.dart';
import 'package:ponos_app/features/home/presentation/state/today_overview_provider.dart';

void main() {
  test(
    'loads today through the repository using the local calendar date',
    () async {
    final repository = OverviewRepository();
    final overview = TodayOverview(
      date: DateTime(2026, 9, 7),
      expectedFocusTime: const Duration(hours: 2),
      actualFocusedTime: const Duration(hours: 1),
      completedFocusAreas: 0,
      targetedFocusAreas: 1,
      areas: const [],
    );
    repository.load = () async => overview;
    final container = ProviderContainer(
      overrides: [
        focusAreaRepositoryProvider.overrideWithValue(repository),
        currentDateTimeProvider.overrideWithValue(
          DateTime(2026, 9, 7, 18, 30),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      todayOverviewProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      container.read(todayOverviewProvider),
      isA<AsyncLoading<TodayOverview>>(),
    );
    expect(await container.read(todayOverviewProvider.future), same(overview));
    expect(repository.requestedDate, DateTime(2026, 9, 7));
    expect(container.read(todayOverviewProvider).hasValue, isTrue);
    },
  );

  test('exposes repository failures through the Riverpod error state', () async {
    final repository = OverviewRepository()
      ..load = () async => throw Exception('offline');
    final container = ProviderContainer(
      overrides: [focusAreaRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      todayOverviewProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    expect(container.read(todayOverviewProvider).hasError, isTrue);
  });
}

class OverviewRepository implements FocusAreaRepository {
  late Future<TodayOverview> Function() load;
  DateTime? requestedDate;

  @override
  Future<TodayOverview> getTodayOverview(DateTime localDate) {
    requestedDate = localDate;
    return load();
  }

  @override
  Future<List<FocusArea>> getActive() => throw UnimplementedError();
  @override
  Future<List<FocusArea>> getArchived() => throw UnimplementedError();
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
}
