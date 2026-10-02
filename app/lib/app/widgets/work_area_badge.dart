import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum WorkAreaType { focusArea, specialActivity }

class WorkAreaBadge extends StatelessWidget {
  const WorkAreaBadge({super.key, required this.type});

  final WorkAreaType type;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (type) {
      WorkAreaType.focusArea => (
        'Focus Area',
        Icons.track_changes_outlined,
        AppColors.primary,
        AppColors.surfaceTinted,
      ),
      WorkAreaType.specialActivity => (
        'Special Activity',
        Icons.bolt_outlined,
        AppColors.primaryDark,
        AppColors.accent.withValues(alpha: 0.16),
      ),
    };
    return Semantics(
      label: 'Work area type: $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: foreground.withValues(alpha: 0.45)),
            borderRadius: AppRadius.pill,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
