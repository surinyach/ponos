import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/focus_area_providers.dart';
import '../../../focus_areas/domain/models/today_overview.dart';

final overviewClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final currentDateTimeProvider = Provider<DateTime>(
  (ref) => ref.watch(overviewClockProvider)(),
);

final todayOverviewProvider = FutureProvider.autoDispose<TodayOverview>((ref) {
  final now = ref.watch(currentDateTimeProvider);
  final localDate = DateTime(now.year, now.month, now.day);
  return ref.watch(focusAreaRepositoryProvider).getTodayOverview(localDate);
});
