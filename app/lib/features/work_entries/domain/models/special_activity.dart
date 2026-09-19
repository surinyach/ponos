class SpecialActivity {
  const SpecialActivity({
    required this.id,
    required this.name,
    required this.workDate,
    required this.isArchived,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final DateTime workDate;
  final bool isArchived;
}

class SpecialActivityCreateInput {
  const SpecialActivityCreateInput({
    required this.name,
    required this.workDate,
    this.description,
  });

  final String name;
  final String? description;
  final DateTime workDate;
}

class SpecialActivityUpdateInput {
  const SpecialActivityUpdateInput({
    this.name,
    this.description = const OptionalValue.absent(),
    this.workDate,
  });

  final String? name;
  final OptionalValue<String> description;
  final DateTime? workDate;
}

class OptionalValue<T> {
  const OptionalValue.absent() : isPresent = false, value = null;
  const OptionalValue.present(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;
}
