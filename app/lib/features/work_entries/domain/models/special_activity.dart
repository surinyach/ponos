class SpecialActivity {
  const SpecialActivity({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
}

class SpecialActivityCreateInput {
  const SpecialActivityCreateInput({required this.name, this.description});

  final String name;
  final String? description;
}

class SpecialActivityUpdateInput {
  const SpecialActivityUpdateInput({
    this.name,
    this.description = const OptionalValue.absent(),
  });

  final String? name;
  final OptionalValue<String> description;
}

class OptionalValue<T> {
  const OptionalValue.absent() : isPresent = false, value = null;
  const OptionalValue.present(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;
}
