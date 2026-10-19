import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/ponos_button.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_timer/presentation/state/focus_timer_controller.dart';
import '../domain/models/special_activity.dart';
import 'state/special_activities_controller.dart';
import 'state/special_activities_state.dart';

class SpecialActivitiesPage extends ConsumerWidget {
  const SpecialActivitiesPage({
    this.onCreate,
    this.onSelected,
    this.embedded = false,
    this.showCreateAction = true,
    super.key,
  });

  final VoidCallback? onCreate;
  final ValueChanged<SpecialActivity>? onSelected;
  final bool embedded;
  final bool showCreateAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(specialActivitiesProvider);
    final activeSpecialActivityId = ref.watch(
      focusTimerProvider.select(
        (timer) => timer.activeTimer?.specialActivityId,
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: embedded
              ? const EdgeInsets.only(top: AppSpacing.xs)
              : AppSpacing.pagePadding,
          children: [
            if (!embedded)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Special Activities',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (showCreateAction)
                    FilledButton.icon(
                      key: const Key('new-special-activity'),
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                ],
              ),
            if (embedded && showCreateAction) ...[
              SizedBox(
                width: double.infinity,
                child: PonosButton.primary(
                  key: const Key('new-special-activity'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: 'New Special Activity',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (!embedded) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'One-off work without daily targets or priority.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (state.status == SpecialActivitiesStatus.saving ||
                state.status == SpecialActivitiesStatus.loading)
              const LinearProgressIndicator(),
            if (state.status == SpecialActivitiesStatus.error) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.error is AppException
                    ? (state.error as AppException).message
                    : 'Unable to update Special Activities.',
                key: const Key('special-activity-delete-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (state.active.isEmpty &&
                state.status == SpecialActivitiesStatus.empty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('No Special Activities yet.'),
              ),
            for (final activity in state.active)
              Card(
                color: AppColors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.card,
                  side: BorderSide(color: AppColors.borderStrong),
                ),
                child: ListTile(
                  onTap: onSelected == null ? null : () => onSelected!(activity),
                  leading: const Icon(
                    Icons.local_activity_outlined,
                    color: AppColors.textSecondary,
                  ),
                  title: Text(activity.name),
                  subtitle: activity.description == null
                      ? null
                      : Text(activity.description!),
                  trailing: activeSpecialActivityId == activity.id
                      ? IconButton(
                          key: Key('delete-special-activity-${activity.id}'),
                          tooltip: 'Stop or reset the active timer first',
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This Special Activity is linked to the active timer. Stop or reset it before deleting.',
                                  ),
                                ),
                              ),
                          icon: const Icon(Icons.lock_clock_outlined),
                        )
                      : IconButton(
                          key: Key('delete-special-activity-${activity.id}'),
                          tooltip: 'Delete ${activity.name}',
                          onPressed:
                              state.status == SpecialActivitiesStatus.saving
                              ? null
                              : () => _confirmDelete(context, ref, activity),
                          icon: const Icon(Icons.delete_outline),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SpecialActivity activity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${activity.name}?'),
        content: const Text(
          'This is only possible if no work is linked to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-special-activity'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(specialActivitiesProvider.notifier).delete(activity.id);
  }
}
