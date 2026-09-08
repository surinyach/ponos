class FocusAreaTargetInput {
  const FocusAreaTargetInput({
    required this.weekday,
    required this.targetMinutes,
    required this.validFrom,
  }) : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
       assert(targetMinutes >= 0);
  final int weekday;
  final int targetMinutes;
  final DateTime validFrom;
}

class FocusAreaCreateInput {
  const FocusAreaCreateInput({
    required this.name,
    required this.priority,
    required this.targets,
    this.description,
    this.targetEndDate,
  });
  final String name;
  final String? description;
  final int priority;
  final DateTime? targetEndDate;
  final List<FocusAreaTargetInput> targets;
}

class NullableUpdate<T> {
  const NullableUpdate.unchanged() : isChanged = false, value = null;
  const NullableUpdate.set(this.value) : isChanged = true;
  final bool isChanged;
  final T? value;
}

class FocusAreaUpdateInput {
  const FocusAreaUpdateInput({
    this.name,
    this.description = const NullableUpdate.unchanged(),
    this.priority,
    this.targetEndDate = const NullableUpdate.unchanged(),
    this.targets,
  });
  final String? name;
  final NullableUpdate<String> description;
  final int? priority;
  final NullableUpdate<DateTime> targetEndDate;
  final List<FocusAreaTargetInput>? targets;
}

class FocusAreaPriorityInput {
  const FocusAreaPriorityInput({required this.id, required this.priority});
  final int id;
  final int priority;
}
