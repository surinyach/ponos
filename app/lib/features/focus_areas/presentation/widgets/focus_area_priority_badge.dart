import 'package:flutter/material.dart';

import '../../../../app/theme/app_priority_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class FocusAreaPriorityBadge extends StatelessWidget {
  const FocusAreaPriorityBadge({required this.priority, super.key});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final colors = AppPriorityColors.forPriority(priority);
    return Semantics(
      label: 'Priority $priority',
      child: ExcludeSemantics(
        child: Container(
          key: Key('priority-badge-$priority'),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs / 2,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              'P$priority',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
