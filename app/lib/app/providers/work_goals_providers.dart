import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/home/presentation/state/today_overview_provider.dart';
import '../../features/work_goals/data/remote_work_goals_repository.dart';
import '../../features/work_goals/data/work_goals_api_client.dart';
import '../../features/work_goals/domain/models/work_goals.dart';
import '../../features/work_goals/domain/repositories/work_goals_repository.dart';
import 'focus_area_providers.dart';

final workGoalsRepositoryProvider = Provider<WorkGoalsRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RemoteWorkGoalsRepository(
    WorkGoalsApiClient(client, ref.watch(apiConfigProvider)),
  );
});

final workGoalsProvider = FutureProvider.autoDispose<WorkGoals>((ref) {
  final now = ref.watch(currentDateTimeProvider);
  final localDate = DateTime(now.year, now.month, now.day);
  return ref.watch(workGoalsRepositoryProvider).get(localDate);
});
