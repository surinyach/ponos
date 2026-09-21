import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class TodaySummary extends StatelessWidget {
  const TodaySummary({
    required this.workedDuration,
    required this.expectedDuration,
    required this.completedFocusAreas,
    required this.totalFocusAreas,
    this.restDuration,
    this.trackedDuration,
    this.weekFocusedDuration,
    this.weekRestDuration,
    super.key,
  });

  final Duration workedDuration;
  final Duration expectedDuration;
  final int completedFocusAreas;
  final int totalFocusAreas;
  final Duration? restDuration;
  final Duration? trackedDuration;
  final Duration? weekFocusedDuration;
  final Duration? weekRestDuration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
            Text('Today', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.schedule,
                    value: _formatDuration(workedDuration),
                    label: 'Focused today',
                    iconColor: colors.primary,
                  ),
                ),
                Container(width: 1, height: 40, color: colors.outlineVariant),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.timelapse_outlined,
                    value: _formatDuration(expectedDuration),
                    label: 'Expected today',
                    iconColor: colors.secondary,
                  ),
                ),
              ],
            ),
            if (restDuration != null && trackedDuration != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.self_improvement_outlined,
                      value: _formatDuration(restDuration!),
                      label: 'Rest today',
                      iconColor: colors.secondary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: colors.outlineVariant),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.access_time_outlined,
                      value: _formatDuration(trackedDuration!),
                      label: 'Tracked today',
                      iconColor: colors.primary,
                    ),
                  ),
                ],
              ),
            ],
            if (weekFocusedDuration != null && weekRestDuration != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'This week · ${_formatDuration(weekFocusedDuration!)} focused · '
                '${_formatDuration(weekRestDuration!)} rest',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _AreasProgress(
              completed: completedFocusAreas,
              total: totalFocusAreas,
            ),
          ],
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

class _AreasProgress extends StatelessWidget {
  const _AreasProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.control,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '$completed / $total focus areas completed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
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
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.control,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
