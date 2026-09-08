import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../focus_areas/domain/models/focus_area.dart';

class FocusAreas extends StatelessWidget {
  const FocusAreas({
    required this.areas,
    required this.workedTodayByAreaId,
    this.dailyTargetByAreaId,
    this.completedByAreaId,
    this.targetDate,
    this.onAreaPressed,
    super.key,
  });

  final List<FocusArea> areas;
  final Map<int, Duration> workedTodayByAreaId;
  final Map<int, Duration?>? dailyTargetByAreaId;
  final Map<int, bool>? completedByAreaId;
  final DateTime? targetDate;
  final ValueChanged<FocusArea>? onAreaPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = targetDate ?? DateTime.now();
    final sortedAreas = [...areas]
      ..sort((first, second) => first.priority.compareTo(second.priority));
    final backgroundColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.07),
      colors.surfaceContainerLow,
    );

    return Card(
      color: backgroundColor,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus areas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            if (sortedAreas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'No focus areas configured.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...List.generate(sortedAreas.length, (index) {
                final area = sortedAreas[index];
                final target =
                    dailyTargetByAreaId?.containsKey(area.id) ?? false
                    ? dailyTargetByAreaId![area.id]
                    : area.targetFor(date)?.targetDuration;
                final workedToday =
                    workedTodayByAreaId[area.id] ?? Duration.zero;

                return Column(
                  children: [
                    _FocusAreaRow(
                      area: area,
                      dailyTarget: target,
                      workedToday: workedToday,
                      completed: completedByAreaId?[area.id],
                      onPressed: onAreaPressed == null
                          ? null
                          : () => onAreaPressed!(area),
                    ),
                    if (index < sortedAreas.length - 1)
                      Divider(color: colors.outlineVariant),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FocusAreaRow extends StatelessWidget {
  const _FocusAreaRow({
    required this.area,
    required this.dailyTarget,
    required this.workedToday,
    this.completed,
    this.onPressed,
  });

  final FocusArea area;
  final Duration? dailyTarget;
  final Duration workedToday;
  final bool? completed;
  final VoidCallback? onPressed;

  bool get isCompleted =>
      completed ?? (dailyTarget != null && workedToday >= dailyTarget!);

  double get progress {
    if (dailyTarget == null) return 0;
    if (dailyTarget!.inMinutes == 0) return 1;
    return (workedToday.inMinutes / dailyTarget!.inMinutes).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: onPressed != null,
      label: dailyTarget == null
          ? '${area.name}: no target for today'
          : '${area.name}: ${_formatDuration(workedToday)} of ${_formatDuration(dailyTarget!)}',
      value: isCompleted
          ? 'Daily target completed'
          : 'Daily target in progress',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      area.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (isCompleted)
                    Icon(Icons.check_circle, size: 20, color: colors.primary)
                  else
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                dailyTarget == null
                    ? '${_formatDuration(workedToday)} today · No target today'
                    : '${_formatDuration(workedToday)} today · ${_formatDuration(dailyTarget!)}/day target',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.full),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}
