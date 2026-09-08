import '../../domain/models/focus_area.dart';

enum FocusAreasStatus { loading, loaded, empty, saving, error, refreshing }

class FocusAreasState {
  FocusAreasState({
    required this.status,
    List<FocusArea> areas = const [],
    this.error,
  }) : areas = List.unmodifiable(areas);

  final FocusAreasStatus status;
  final List<FocusArea> areas;
  final Object? error;
}
