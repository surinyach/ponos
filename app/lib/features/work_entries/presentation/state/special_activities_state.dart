import '../../domain/models/special_activity.dart';

enum SpecialActivitiesStatus { loading, loaded, empty, saving, error }

class SpecialActivitiesState {
  SpecialActivitiesState({
    required this.status,
    List<SpecialActivity> active = const [],
    List<SpecialActivity> archived = const [],
    this.error,
  }) : active = List.unmodifiable(active),
       archived = List.unmodifiable(archived);

  final SpecialActivitiesStatus status;
  final List<SpecialActivity> active;
  final List<SpecialActivity> archived;
  final Object? error;
}
