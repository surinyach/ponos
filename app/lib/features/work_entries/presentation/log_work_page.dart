import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_areas/presentation/state/focus_areas_controller.dart';
import '../domain/models/manual_work_entry.dart';
import 'create_special_activity_page.dart';
import 'log_work_form_page.dart';
import 'state/manual_work_entries_controller.dart';
import 'state/manual_work_entries_state.dart';
import 'state/special_activities_controller.dart';

class LogWorkPage extends ConsumerWidget {
  const LogWorkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(manualWorkEntriesProvider);
    final areas = ref.watch(focusAreasProvider).areas;
    final activities = ref.watch(specialActivitiesProvider);
    final subjectNames = <String, String>{
      for (final area in areas) 'focus:${area.id}': area.name,
      for (final activity in [...activities.active, ...activities.archived])
        'special:${activity.id}': activity.name,
    };
    final busy = state.status == ManualWorkEntriesStatus.saving;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log work',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        key: const Key('new-work-entry'),
                        onPressed: busy ? null : () => _openForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add entry'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('new-special-activity'),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const CreateSpecialActivityPage(),
                          ),
                        ),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('New Special Activity'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Record focused and rest time for a day.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (busy) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(key: Key('log-work-saving')),
                  ],
                  if (state.status == ManualWorkEntriesStatus.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorNotice(
                      message: _errorMessage(state.error),
                      onRetry: () => ref
                          .read(manualWorkEntriesProvider.notifier)
                          .refresh(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: switch (state.status) {
                ManualWorkEntriesStatus.loading when state.entries.isEmpty =>
                  const Center(child: CircularProgressIndicator()),
                ManualWorkEntriesStatus.empty => const Center(
                  child: Text('No work entries yet. Add your first entry.'),
                ),
                ManualWorkEntriesStatus.error when state.entries.isEmpty =>
                  const Center(child: Text('Unable to load work entries.')),
                _ => RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(manualWorkEntriesProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: state.entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _EntryCard(
                      entry: state.entries[index],
                      subjectName:
                          subjectNames[state.entries[index].focusAreaId != null
                              ? 'focus:${state.entries[index].focusAreaId}'
                              : 'special:${state.entries[index].specialActivityId}'],
                      busy: busy,
                      onEdit: () => _openForm(context, state.entries[index]),
                      onDelete: () =>
                          _confirmDelete(context, ref, state.entries[index]),
                    ),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [ManualWorkEntry? entry]) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => LogWorkFormPage(entry: entry)),
      );

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ManualWorkEntry entry,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete work entry?'),
            content: const Text('This entry will be removed permanently.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-delete-work-entry'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await ref.read(manualWorkEntriesProvider.notifier).delete(entry.id);
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.subjectName,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final ManualWorkEntry entry;
  final String? subjectName;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            entry.specialActivityId == null
                ? Icons.track_changes_outlined
                : Icons.star_outline,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(entry.workDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  subjectName ??
                      (entry.focusAreaId != null
                          ? 'Focus Area #${entry.focusAreaId}'
                          : 'Special Activity #${entry.specialActivityId}'),
                ),
                Text(
                  'Focus ${_formatDuration(entry.focusedTime)} · '
                  'Rest ${_formatDuration(entry.restTime)}',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit entry',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete entry',
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _errorMessage(Object? error) =>
    error is AppException ? error.message : 'Something went wrong. Try again.';

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '${minutes}m ${seconds}s';
}
