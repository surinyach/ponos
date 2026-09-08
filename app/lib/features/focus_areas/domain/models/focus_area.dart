import 'focus_area_target.dart';

class FocusArea {
  const FocusArea({
    required this.id,
    required this.name,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.targets,
    this.description,
    this.targetEndDate,
    this.archivedAt,
  });

  final int id;
  final String name;
  final String? description;
  final int priority;
  final DateTime? targetEndDate;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FocusAreaTarget> targets;

  bool get isArchived => archivedAt != null;

  FocusAreaTarget? targetFor(DateTime date) {
    for (final target in targets.reversed) {
      if (target.appliesOn(date)) return target;
    }
    return null;
  }
}
