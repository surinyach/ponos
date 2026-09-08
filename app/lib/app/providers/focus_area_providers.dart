import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../features/focus_areas/data/data_sources/focus_area_api_client.dart';
import '../../features/focus_areas/data/repositories/remote_focus_area_repository.dart';
import '../../features/focus_areas/domain/repositories/focus_area_repository.dart';

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig.fromEnvironment(),
);

final focusAreaRepositoryProvider = Provider<FocusAreaRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RemoteFocusAreaRepository(
    FocusAreaApiClient(client, ref.watch(apiConfigProvider)),
  );
});
