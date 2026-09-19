class ManualWorkEntry {
  const ManualWorkEntry({
    required this.id,
    required this.workDate,
    required this.focusedTime,
    required this.restTime,
    this.focusAreaId,
    this.specialActivityId,
  });

  final int id;
  final int? focusAreaId;
  final int? specialActivityId;
  final DateTime workDate;
  final Duration focusedTime;
  final Duration restTime;
}

class ManualWorkEntryCreateInput {
  const ManualWorkEntryCreateInput({
    required this.workDate,
    required this.focusedTime,
    required this.restTime,
    this.focusAreaId,
    this.specialActivityId,
  });

  final int? focusAreaId;
  final int? specialActivityId;
  final DateTime workDate;
  final Duration focusedTime;
  final Duration restTime;
}

class ManualWorkEntryUpdateInput {
  const ManualWorkEntryUpdateInput({
    this.focusAreaId,
    this.specialActivityId,
    this.changeOwner = false,
    this.workDate,
    this.focusedTime,
    this.restTime,
  });

  final int? focusAreaId;
  final int? specialActivityId;
  final bool changeOwner;
  final DateTime? workDate;
  final Duration? focusedTime;
  final Duration? restTime;
}
