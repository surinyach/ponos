import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/work_entries/data/data_sources/work_entries_api_client.dart';
import '../../features/work_entries/data/repositories/remote_manual_work_entry_repository.dart';
import '../../features/work_entries/data/repositories/remote_special_activity_repository.dart';
import '../../features/work_entries/domain/repositories/manual_work_entry_repository.dart';
import '../../features/work_entries/domain/repositories/special_activity_repository.dart';
import 'focus_area_providers.dart';

final workEntriesApiClientProvider = Provider<WorkEntriesApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WorkEntriesApiClient(client, ref.watch(apiConfigProvider));
});

final specialActivityRepositoryProvider = Provider<SpecialActivityRepository>(
  (ref) =>
      RemoteSpecialActivityRepository(ref.watch(workEntriesApiClientProvider)),
);

final manualWorkEntryRepositoryProvider = Provider<ManualWorkEntryRepository>(
  (ref) =>
      RemoteManualWorkEntryRepository(ref.watch(workEntriesApiClientProvider)),
);
