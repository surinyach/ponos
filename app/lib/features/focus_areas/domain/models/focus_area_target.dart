class FocusAreaTarget {
  const FocusAreaTarget({
    required this.id,
    required this.focusAreaId,
    required this.weekday,
    required this.targetMinutes,
    required this.validFrom,
    this.validUntil,
  }) : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
       assert(targetMinutes >= 0);

  final int id;
  final int focusAreaId;
  final int weekday;
  final int targetMinutes;
  final DateTime validFrom;
  final DateTime? validUntil;

  Duration get targetDuration => Duration(minutes: targetMinutes);

  bool appliesOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final starts = DateTime(validFrom.year, validFrom.month, validFrom.day);
    final end = validUntil == null
        ? null
        : DateTime(validUntil!.year, validUntil!.month, validUntil!.day);

    return day.weekday == weekday &&
        !day.isBefore(starts) &&
        (end == null || !day.isAfter(end));
  }
}
