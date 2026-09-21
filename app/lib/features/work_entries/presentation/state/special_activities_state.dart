import '../../domain/models/special_activity.dart';

enum SpecialActivitiesStatus { loading, loaded, empty, saving, error }

class SpecialActivitiesState {
  SpecialActivitiesState({
    required this.status,
    List<SpecialActivity> active = const [],
    this.error,
  }) : active = List.unmodifiable(active);

  final SpecialActivitiesStatus status;
  final List<SpecialActivity> active;
  final Object? error;
}
