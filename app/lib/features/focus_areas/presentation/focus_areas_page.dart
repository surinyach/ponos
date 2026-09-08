import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/focus_area.dart';
import '../domain/models/focus_area_input.dart';
import 'state/focus_areas_controller.dart';
import 'state/focus_areas_state.dart';

class FocusAreasPage extends ConsumerStatefulWidget {
  const FocusAreasPage({
    this.onCreate,
    this.onAreaSelected,
    this.today,
    super.key,
  });

  final VoidCallback? onCreate;
  final ValueChanged<FocusArea>? onAreaSelected;
  final DateTime? today;

  @override
  ConsumerState<FocusAreasPage> createState() => _FocusAreasPageState();
}

class _FocusAreasPageState extends ConsumerState<FocusAreasPage> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Active')),
            ButtonSegment(value: true, label: Text('Archived')),
          ],
          selected: {_archived},
          onSelectionChanged: (values) =>
              setState(() => _archived = values.single),
        ),
      ),
      Expanded(
        child: _archived
            ? const _ArchivedAreas()
            : _ActiveAreas(
                onCreate: widget.onCreate,
                onAreaSelected: widget.onAreaSelected,
                today: widget.today,
              ),
      ),
    ],
  );
}

class _ActiveAreas extends ConsumerWidget {
  const _ActiveAreas({this.onCreate, this.onAreaSelected, this.today});
  final VoidCallback? onCreate;
  final ValueChanged<FocusArea>? onAreaSelected;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusAreasProvider);
    final currentDate = today ?? DateTime.now();
    final refresh = ref.read(focusAreasProvider.notifier).refresh;
    final reorder = ref.read(focusAreasProvider.notifier).reorder;

    return switch (state.status) {
      FocusAreasStatus.loading => const Center(
        child: CircularProgressIndicator(key: Key('focus-areas-loading')),
      ),
      FocusAreasStatus.empty => _EmptyState(onCreate: onCreate),
      FocusAreasStatus.error when state.areas.isEmpty => _ErrorState(
        message: _errorMessage(state.error),
        onRetry: refresh,
      ),
      _ => _AreaList(
        state: state,
        today: currentDate,
        onCreate: onCreate,
        onAreaSelected: onAreaSelected,
        onRefresh: refresh,
        onReorder: reorder,
      ),
    };
  }
}

class _AreaList extends StatefulWidget {
  const _AreaList({
    required this.state,
    required this.today,
    required this.onRefresh,
    required this.onReorder,
    this.onCreate,
    this.onAreaSelected,
  });

  final FocusAreasState state;
  final DateTime today;
  final Future<bool> Function() onRefresh;
  final Future<bool> Function(List<FocusAreaPriorityInput>) onReorder;
  final VoidCallback? onCreate;
  final ValueChanged<FocusArea>? onAreaSelected;

  @override
  State<_AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<_AreaList> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final areas = widget.state.areas;
    final scheduled = areas.where(
      (area) => area.targetFor(widget.today) != null,
    );
    final totalMinutes = scheduled.fold(
      0,
      (total, area) => total + area.targetFor(widget.today)!.targetMinutes,
    );
    final busy = {
      FocusAreasStatus.refreshing,
      FocusAreasStatus.saving,
    }.contains(widget.state.status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 900;
        final padding = constraints.maxWidth < 600
            ? const EdgeInsets.all(AppSpacing.md)
            : AppSpacing.pagePadding;

        return RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: padding.copyWith(bottom: AppSpacing.sm),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        onCreate: widget.onCreate,
                        onRefresh: busy ? null : widget.onRefresh,
                        isReordering: _reordering,
                        onToggleReordering: busy || areas.length < 2
                            ? null
                            : () => setState(() => _reordering = !_reordering),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DailySummary(
                        totalMinutes: totalMinutes,
                        scheduledAreas: scheduled.length,
                      ),
                      if (widget.state.status == FocusAreasStatus.error) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ErrorNotice(
                          message: _errorMessage(widget.state.error),
                          onRetry: widget.onRefresh,
                        ),
                      ],
                      if (busy) ...[
                        const SizedBox(height: AppSpacing.md),
                        const LinearProgressIndicator(
                          key: Key('focus-areas-busy'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: padding.copyWith(top: AppSpacing.sm),
                sliver: useGrid
                    ? SliverGrid(
                        key: const Key('focus-areas-grid'),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 128,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                        delegate: _delegate(
                          areas,
                          showMoveButtons: _reordering,
                          busy: busy,
                        ),
                      )
                    : _reordering
                    ? SliverReorderableList(
                        key: const Key('focus-areas-list'),
                        itemCount: areas.length,
                        onReorderItem: busy ? (_, _) {} : _move,
                        itemBuilder: (context, index) => Padding(
                          key: ValueKey(areas[index].id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AreaCard(
                            area: areas[index],
                            today: widget.today,
                            reorderHandle: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        key: const Key('focus-areas-list'),
                        delegate: _delegate(areas, addSpacing: true),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverChildBuilderDelegate _delegate(
    List<FocusArea> areas, {
    bool addSpacing = false,
    bool showMoveButtons = false,
    bool busy = false,
  }) => SliverChildBuilderDelegate(
    (context, index) => Padding(
      padding: EdgeInsets.only(bottom: addSpacing ? AppSpacing.sm : 0),
      child: _AreaCard(
        area: areas[index],
        today: widget.today,
        archiveAction: _reordering ? null : _ArchiveAction(area: areas[index]),
        onPressed: _reordering || widget.onAreaSelected == null
            ? null
            : () => widget.onAreaSelected!(areas[index]),
        onMoveUp: showMoveButtons && !busy && index > 0
            ? () => _move(index, index - 1)
            : null,
        onMoveDown: showMoveButtons && !busy && index < areas.length - 1
            ? () => _move(index, index + 1)
            : null,
        showMoveButtons: showMoveButtons,
      ),
    ),
    childCount: areas.length,
  );

  void _move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final ordered = [...widget.state.areas];
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    widget.onReorder([
      for (var index = 0; index < ordered.length; index++)
        FocusAreaPriorityInput(id: ordered[index].id, priority: index + 1),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isReordering,
    this.onCreate,
    this.onRefresh,
    this.onToggleReordering,
  });
  final VoidCallback? onCreate;
  final Future<bool> Function()? onRefresh;
  final bool isReordering;
  final VoidCallback? onToggleReordering;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Areas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Your ongoing commitments, ordered by priority.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Refresh Focus Areas',
        onPressed: onRefresh == null ? null : () => onRefresh!(),
        icon: const Icon(Icons.refresh),
      ),
      IconButton(
        key: const Key('focus-areas-reorder-toggle'),
        tooltip: isReordering ? 'Finish reordering' : 'Reorder Focus Areas',
        onPressed: onToggleReordering,
        icon: Icon(isReordering ? Icons.check : Icons.swap_vert),
      ),
      const SizedBox(width: AppSpacing.xs),
      FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('New area'),
      ),
    ],
  );
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({
    required this.totalMinutes,
    required this.scheduledAreas,
  });
  final int totalMinutes;
  final int scheduledAreas;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadius.card,
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.today_outlined, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Today · ${_duration(totalMinutes)} across '
              '$scheduledAreas ${scheduledAreas == 1 ? 'area' : 'areas'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.today,
    this.onPressed,
    this.onMoveUp,
    this.onMoveDown,
    this.reorderHandle,
    this.showMoveButtons = false,
    this.archiveAction,
  });
  final FocusArea area;
  final DateTime today;
  final VoidCallback? onPressed;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Widget? reorderHandle;
  final bool showMoveButtons;
  final Widget? archiveAction;

  @override
  Widget build(BuildContext context) {
    final target = area.targetFor(today);
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: AppRadius.control,
                ),
                child: Text(
                  '${area.priority}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      target == null
                          ? 'No target today'
                          : '${_duration(target.targetMinutes)} target today',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ?archiveAction,
              if (showMoveButtons)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('move-up-${area.id}'),
                      tooltip: 'Move ${area.name} up',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      key: Key('move-down-${area.id}'),
                      tooltip: 'Move ${area.name} down',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                )
              else if (reorderHandle != null)
                reorderHandle!
              else if (onPressed != null)
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveAction extends ConsumerWidget {
  const _ArchiveAction({required this.area});
  final FocusArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(focusAreasProvider).status == FocusAreasStatus.saving;
    return IconButton(
      tooltip: 'Archive ${area.name}',
      icon: const Icon(Icons.archive_outlined),
      onPressed: busy
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Archive ${area.name}?'),
                  content: const Text(
                    'This area will move to Archived. Historical targets and recorded work will be preserved. You can restore it later.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Archive'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(focusAreasProvider.notifier).archive(area.id);
              }
            },
    );
  }
}

class _ArchivedAreas extends ConsumerWidget {
  const _ArchivedAreas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedFocusAreasProvider);
    final active = ref.watch(focusAreasProvider);
    final busy = active.status == FocusAreasStatus.saving;
    return archived.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(
        message: _errorMessage(error),
        onRetry: () async {
          ref.invalidate(archivedFocusAreasProvider);
          return true;
        },
      ),
      data: (areas) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(archivedFocusAreasProvider);
          await ref.read(archivedFocusAreasProvider.future);
        },
        child: ListView(
          padding: AppSpacing.pagePadding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Archived Focus Areas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text('Historical targets and recorded work are preserved.'),
            const SizedBox(height: AppSpacing.md),
            if (busy) const LinearProgressIndicator(),
            if (areas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('No archived Focus Areas'),
              ),
            for (final area in areas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  child: ListTile(
                    title: Text(area.name),
                    subtitle: const Text('Archived'),
                    trailing: TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final success = await ref
                                  .read(focusAreasProvider.notifier)
                                  .restore(area.id);
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _errorMessage(
                                        ref.read(focusAreasProvider).error,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Restore'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.track_changes_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Focus Areas yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Create one to define what deserves your time.'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Focus Area'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unable to load Focus Areas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});
  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(message),
      trailing: TextButton(
        onPressed: () => onRetry(),
        child: const Text('Retry'),
      ),
    ),
  );
}

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'Focus Areas could not be loaded.',
};

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}
