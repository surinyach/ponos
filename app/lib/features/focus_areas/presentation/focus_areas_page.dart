import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_timer/presentation/state/focus_timer_controller.dart';
import '../../home/presentation/state/today_overview_provider.dart';
import '../domain/models/focus_area.dart';
import 'archived_focus_area_actions.dart';
import 'state/focus_areas_controller.dart';
import 'state/focus_areas_state.dart';
import 'widgets/focus_area_priority_badge.dart';

const _warningText = Color(0xFF995A00);
const _warningBackground = Color(0xFFFFF5DF);
const _warningBorder = Color(0xFFF1D99B);
const _warningIcon = Color(0xFFDA8400);
const _dangerText = Color(0xFFB42336);
const _dangerBackground = Color(0xFFFDEDF0);
const _dangerBorder = Color(0xFFF2CBD1);
const _dangerIcon = Color(0xFFCC2940);

class FocusAreasPage extends ConsumerWidget {
  const FocusAreasPage({
    this.archived = false,
    this.archivedCount = 0,
    this.showCompactActions = true,
    this.onCreate,
    this.onAreaSelected,
    this.onArchivedAreaSelected,
    this.onViewArchived,
    this.onBackFromArchived,
    this.today,
    this.layout,
    super.key,
  });

  final bool archived;
  final int archivedCount;
  final bool showCompactActions;
  final VoidCallback? onCreate;
  final ValueChanged<FocusArea>? onAreaSelected;
  final ValueChanged<FocusArea>? onArchivedAreaSelected;
  final VoidCallback? onViewArchived;
  final VoidCallback? onBackFromArchived;
  final DateTime? today;
  final AppLayoutSize? layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (archived) {
      return _ArchivedAreas(
        onBack: onBackFromArchived,
        onAreaSelected: onArchivedAreaSelected,
        layout:
            layout ??
            AppBreakpoints.layoutFor(PonosViewportScope.sizeOf(context).width),
      );
    }

    final state = ref.watch(focusAreasProvider);
    final currentDate = _dateOnly(today ?? DateTime.now());
    final focusedToday =
        ref.watch(todayOverviewProvider).value?.actualFocusedTime ??
        Duration.zero;
    final refresh = ref.read(focusAreasProvider.notifier).refresh;

    return switch (state.status) {
      FocusAreasStatus.loading => const PonosStatePanel.loading(
        key: Key('focus-areas-loading'),
        title: 'Loading Focus Areas',
      ),
      FocusAreasStatus.empty => _EmptyState(onCreate: onCreate),
      FocusAreasStatus.error when state.areas.isEmpty => _ErrorState(
        message: _errorMessage(state.error),
        onRetry: refresh,
      ),
      _ => _AreaList(
        state: state,
        today: currentDate,
        focusedToday: focusedToday,
        archivedCount: archivedCount,
        showCompactActions: showCompactActions,
        onCreate: onCreate,
        onAreaSelected: onAreaSelected,
        onViewArchived: onViewArchived,
        onRefresh: refresh,
        layout:
            layout ??
            AppBreakpoints.layoutFor(PonosViewportScope.sizeOf(context).width),
      ),
    };
  }
}

class _AreaList extends StatelessWidget {
  const _AreaList({
    required this.state,
    required this.today,
    required this.focusedToday,
    required this.archivedCount,
    required this.showCompactActions,
    required this.onRefresh,
    required this.layout,
    this.onCreate,
    this.onAreaSelected,
    this.onViewArchived,
  });

  final FocusAreasState state;
  final DateTime today;
  final Duration focusedToday;
  final int archivedCount;
  final bool showCompactActions;
  final Future<bool> Function() onRefresh;
  final AppLayoutSize layout;
  final VoidCallback? onCreate;
  final ValueChanged<FocusArea>? onAreaSelected;
  final VoidCallback? onViewArchived;

  @override
  Widget build(BuildContext context) {
    final scheduled = state.areas.where(
      (area) => area.targetFor(today) != null,
    );
    final totalMinutes = scheduled.fold(
      0,
      (total, area) => total + area.targetFor(today)!.targetMinutes,
    );
    final busy = {
      FocusAreasStatus.refreshing,
      FocusAreasStatus.saving,
    }.contains(state.status);
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        key: const Key('focus-areas-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxs),
                _DailySummary(
                  totalMinutes: totalMinutes,
                  focusedMinutes: focusedToday.inMinutes,
                ),
                if (showCompactActions) ...[
                  const SizedBox(height: 10),
                  _CompactActions(
                    archivedCount: archivedCount,
                    onViewArchived: onViewArchived,
                    onCreate: onCreate,
                  ),
                ],
                if (state.status == FocusAreasStatus.error) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ErrorNotice(
                    message: _errorMessage(state.error),
                    onRetry: onRefresh,
                  ),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: LinearProgressIndicator(
                      key: Key('focus-areas-busy'),
                      minHeight: 2,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (layout == AppLayoutSize.expanded)
                  _AreaTable(
                    areas: state.areas,
                    today: today,
                    onAreaSelected: onAreaSelected,
                  )
                else
                  _AreaCards(
                    areas: state.areas,
                    today: today,
                    onAreaSelected: onAreaSelected,
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActions extends StatelessWidget {
  const _CompactActions({
    required this.archivedCount,
    this.onViewArchived,
    this.onCreate,
  });

  final int archivedCount;
  final VoidCallback? onViewArchived;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.textScalerOf(context).scale(14) > 19;
    final archived = _CompactActionButton(
      key: const Key('view-archived-focus-areas'),
      label: 'View archived ($archivedCount)',
      icon: Icons.inventory_2_outlined,
      onPressed: onViewArchived,
      primary: false,
    );
    final create = _CompactActionButton(
      key: const Key('new-focus-area'),
      label: 'New Focus Area',
      icon: Icons.add,
      onPressed: onCreate,
      primary: true,
    );
    if (stack) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: archived),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(width: double.infinity, child: create),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: archived),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: create),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? AppColors.white : AppColors.primary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: primary ? AppColors.primary : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.control,
          side: primary
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFCBDFEF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minimumTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({
    required this.totalMinutes,
    required this.focusedMinutes,
  });

  final int totalMinutes;
  final int focusedMinutes;

  @override
  Widget build(BuildContext context) {
    final progress = totalMinutes == 0
        ? 0.0
        : (focusedMinutes / totalMinutes).clamp(0.0, 1.0);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('focus-areas-daily-summary'),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(13, 6, 13, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Daily targets (today)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _duration(totalMinutes),
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: const Color(0xFFDCE8F2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3581CE)),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_duration(focusedMinutes)} focused',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 12 / 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'of ${_duration(totalMinutes)} targeted',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 12 / 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AreaCards extends StatelessWidget {
  const _AreaCards({
    required this.areas,
    required this.today,
    this.onAreaSelected,
  });

  final List<FocusArea> areas;
  final DateTime today;
  final ValueChanged<FocusArea>? onAreaSelected;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('focus-areas-list'),
    children: [
      for (var index = 0; index < areas.length; index++) ...[
        _AreaCard(
          area: areas[index],
          today: today,
          onPressed: onAreaSelected == null
              ? null
              : () => onAreaSelected!(areas[index]),
        ),
        if (index != areas.length - 1) const SizedBox(height: AppSpacing.xs),
      ],
    ],
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.today, this.onPressed});

  final FocusArea area;
  final DateTime today;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final expiration = _expiration(area, today);
    final target = area.targetFor(today);
    final colors = _statusColors(expiration);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: onPressed != null,
      label: _areaSemanticLabel(area, target?.targetMinutes, expiration),
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: expiration == null ? 93 : 109,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FocusAreaPriorityBadge(priority: area.priority),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (area.description?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 1),
                          Text(
                            area.description!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              height: 14 / 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (expiration != null) ...[
                          const SizedBox(height: 3),
                          _ExpirationLabel(expiration: expiration),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.adjust,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Flexible(
                                    child: Text(
                                      target == null
                                          ? 'No target today'
                                          : '${_duration(target.targetMinutes)} today',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.labelSmall?.copyWith(
                                        fontSize: 11,
                                        height: 14 / 11,
                                        color: expiration == null
                                            ? AppColors.primaryDark
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (area.targetEndDate != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  _finishLabel(area.targetEndDate, today),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    height: 13 / 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: AppSpacing.xxs),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ArchiveMenu(area: area),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaTable extends StatelessWidget {
  const _AreaTable({
    required this.areas,
    required this.today,
    this.onAreaSelected,
  });

  final List<FocusArea> areas;
  final DateTime today;
  final ValueChanged<FocusArea>? onAreaSelected;

  @override
  Widget build(BuildContext context) {
    final priorityColumnWidth = _priorityColumnWidth(
      context,
      areas,
      minimum: 69,
    );
    return _focusAreaTableSurface(
      key: const Key('focus-areas-table'),
      child: Column(
        children: [
          _TableHeader(priorityColumnWidth: priorityColumnWidth),
          for (final area in areas)
            _TableRow(
              area: area,
              today: today,
              priorityColumnWidth: priorityColumnWidth,
              onPressed: onAreaSelected == null
                  ? null
                  : () => onAreaSelected!(area),
            ),
        ],
      ),
    );
  }
}

Widget _focusAreaTableSurface({required Key key, required Widget child}) =>
    Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        color: AppColors.white,
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: AppRadius.card,
      ),
      child: ClipRRect(borderRadius: AppRadius.card, child: child),
    );

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.priorityColumnWidth});

  final double priorityColumnWidth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    return Container(
      height: 34,
      color: AppColors.surfaceTinted,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: priorityColumnWidth,
            child: Text('Priority', style: style),
          ),
          Expanded(flex: 5, child: Text('Focus Area', style: style)),
          Expanded(flex: 3, child: Text('Today’s Target', style: style)),
          Expanded(flex: 3, child: Text('Finish Date', style: style)),
          SizedBox(
            width: 80,
            child: Text('Actions', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.area,
    required this.today,
    required this.priorityColumnWidth,
    this.onPressed,
  });

  final FocusArea area;
  final DateTime today;
  final double priorityColumnWidth;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final expiration = _expiration(area, today);
    final statusColors = _statusColors(expiration);
    final target = area.targetFor(today);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: onPressed != null,
      label: _areaSemanticLabel(area, target?.targetMinutes, expiration),
      child: Material(
        color: statusColors.background,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: BoxConstraints(
              minHeight: expiration == null ? 85 : 91,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: priorityColumnWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FocusAreaPriorityBadge(priority: area.priority),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (area.description?.trim().isNotEmpty == true)
                        Text(
                          area.description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            height: 16 / 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (expiration != null)
                        _ExpirationLabel(expiration: expiration),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.adjust,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          target == null
                              ? 'No target today'
                              : '${_duration(target.targetMinutes)} today',
                          style: textTheme.bodySmall?.copyWith(
                            color: target == null
                                ? AppColors.textSecondary
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          area.targetEndDate == null
                              ? 'No finish date'
                              : _formatDate(
                                  area.targetEndDate!,
                                  includeYear: true,
                                ),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onPressed != null)
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      _ArchiveMenu(area: area),
                    ],
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

double _priorityColumnWidth(
  BuildContext context,
  Iterable<FocusArea> areas, {
  required double minimum,
}) {
  final style = Theme.of(context).textTheme.labelSmall?.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  final scaler = MediaQuery.textScalerOf(context);
  var widestBadge = 32.0;
  for (final area in areas) {
    final painter = TextPainter(
      text: TextSpan(text: 'P${area.priority}', style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    widestBadge = math.max(
      widestBadge,
      painter.width + (AppSpacing.xxs / 2 * 2),
    );
  }
  return math.max(minimum, widestBadge + AppSpacing.md);
}

class _ExpirationLabel extends StatelessWidget {
  const _ExpirationLabel({required this.expiration});

  final _Expiration expiration;

  @override
  Widget build(BuildContext context) => Semantics(
    label: expiration.semanticLabel,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: expiration.critical ? _dangerIcon : _warningIcon,
          ),
          const SizedBox(width: 3),
          Text(
            'Expired ${expiration.days} ${expiration.days == 1 ? 'day' : 'days'} ago',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              height: 14 / 11,
              color: expiration.critical ? _dangerText : _warningText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArchiveMenu extends ConsumerWidget {
  const _ArchiveMenu({required this.area});

  final FocusArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(focusAreasProvider).status == FocusAreasStatus.saving;
    return SizedBox.square(
      dimension: AppSpacing.minimumTouchTarget,
      child: PopupMenuButton<String>(
        key: Key('focus-area-menu-${area.id}'),
        tooltip: 'Actions for ${area.name}',
        enabled: !busy,
        icon: const Icon(
          Icons.more_vert,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onSelected: (value) {
          if (value == 'archive') _confirmArchive(context, ref);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                Icon(Icons.archive_outlined, size: 20),
                SizedBox(width: AppSpacing.xs),
                Text('Archive'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
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
  }
}

class _ArchivedAreas extends ConsumerWidget {
  const _ArchivedAreas({
    required this.layout,
    this.onBack,
    this.onAreaSelected,
  });

  final AppLayoutSize layout;
  final VoidCallback? onBack;
  final ValueChanged<FocusArea>? onAreaSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedFocusAreasProvider);
    final active = ref.watch(focusAreasProvider);
    final activeTimerAreaId = ref.watch(
      focusTimerProvider.select((state) => state.activeTimer?.focusAreaId),
    );
    final busy = active.status == FocusAreasStatus.saving;
    Future<void> refresh() async {
      ref.invalidate(archivedFocusAreasProvider);
      await ref.read(archivedFocusAreasProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        key: const Key('archived-focus-areas-scroll-view'),
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ArchivedHeader(onBack: onBack),
          const SizedBox(height: AppSpacing.lg),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          archived.when(
            loading: () => const PonosStatePanel.loading(
              key: Key('archived-focus-areas-loading'),
              title: 'Loading archived Focus Areas',
            ),
            error: (error, stack) => PonosStatePanel.error(
              title: 'Unable to load archived Focus Areas',
              description: _errorMessage(error),
              actionLabel: 'Try again',
              onAction: refresh,
            ),
            data: (areas) {
              if (areas.isEmpty) {
                return const PonosStatePanel.empty(
                  key: Key('archived-focus-areas-empty'),
                  title: 'No archived Focus Areas',
                  description: 'Archived Focus Areas will appear here.',
                  illustrationAsset: AppAssets.emptyFocusAreas,
                );
              }
              return layout == AppLayoutSize.expanded
                  ? _ArchivedAreaTable(
                      areas: areas,
                      busy: busy,
                      activeTimerAreaId: activeTimerAreaId,
                      onSelected: onAreaSelected,
                      onRestore: (area) =>
                          restoreArchivedFocusArea(context, ref, area),
                      onDelete: (area) => deleteArchivedFocusArea(
                        context,
                        ref,
                        area,
                        blockedByTimer: activeTimerAreaId == area.id,
                      ),
                    )
                  : _ArchivedAreaCards(
                      areas: areas,
                      busy: busy,
                      activeTimerAreaId: activeTimerAreaId,
                      onSelected: onAreaSelected,
                      onRestore: (area) =>
                          restoreArchivedFocusArea(context, ref, area),
                      onDelete: (area) => deleteArchivedFocusArea(
                        context,
                        ref,
                        area,
                        blockedByTimer: activeTimerAreaId == area.id,
                      ),
                    );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ArchivedHeader extends StatelessWidget {
  const _ArchivedHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Archived Focus Areas',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack == null)
          title
        else
          Row(
            children: [
              SizedBox.square(
                dimension: AppSpacing.minimumTouchTarget,
                child: IconButton(
                  key: const Key('back-from-archived-focus-areas'),
                  tooltip: 'Back to Focus Areas',
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(child: title),
            ],
          ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Manage your archived Focus Areas. Restore them to make them active again or delete them permanently.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ArchivedAreaCards extends StatelessWidget {
  const _ArchivedAreaCards({
    required this.areas,
    required this.busy,
    required this.activeTimerAreaId,
    required this.onSelected,
    required this.onRestore,
    required this.onDelete,
  });

  final List<FocusArea> areas;
  final bool busy;
  final int? activeTimerAreaId;
  final ValueChanged<FocusArea>? onSelected;
  final ValueChanged<FocusArea> onRestore;
  final ValueChanged<FocusArea> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('archived-focus-areas-list'),
    children: [
      for (var index = 0; index < areas.length; index++) ...[
        _ArchivedAreaCard(
          area: areas[index],
          busy: busy,
          blockedByTimer: activeTimerAreaId == areas[index].id,
          onSelected: onSelected == null
              ? null
              : () => onSelected!(areas[index]),
          onRestore: () => onRestore(areas[index]),
          onDelete: () => onDelete(areas[index]),
        ),
        if (index != areas.length - 1) const SizedBox(height: AppSpacing.xs),
      ],
    ],
  );
}

class _ArchivedAreaCard extends StatelessWidget {
  const _ArchivedAreaCard({
    required this.area,
    required this.busy,
    required this.blockedByTimer,
    required this.onSelected,
    required this.onRestore,
    required this.onDelete,
  });

  final FocusArea area;
  final bool busy;
  final bool blockedByTimer;
  final VoidCallback? onSelected;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.card,
      side: const BorderSide(color: AppColors.borderStrong),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onSelected,
      child: Container(
        key: Key('archived-focus-area-card-${area.id}'),
        constraints: const BoxConstraints(minHeight: 106),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusAreaPriorityBadge(priority: area.priority),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (area.description?.trim().isNotEmpty == true)
                    Text(
                      area.description!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxs),
                  _ArchivedDateLine(
                    icon: Icons.calendar_today_outlined,
                    label: area.targetEndDate == null
                        ? 'No finish date'
                        : 'Finished: ${_formatDate(area.targetEndDate!, includeYear: true)}',
                  ),
                  _ArchivedDateLine(
                    icon: Icons.inventory_2_outlined,
                    label: area.archivedAt == null
                        ? 'Archive date unavailable'
                        : 'Archived: ${_formatDate(area.archivedAt!.toLocal(), includeYear: true)}',
                  ),
                ],
              ),
            ),
            _ArchivedOverflowActions(
              area: area,
              busy: busy,
              blockedByTimer: blockedByTimer,
              onRestore: onRestore,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ArchivedDateLine extends StatelessWidget {
  const _ArchivedDateLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.xxs),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            height: 14 / 10.5,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

class _ArchivedOverflowActions extends StatelessWidget {
  const _ArchivedOverflowActions({
    required this.area,
    required this.busy,
    required this.blockedByTimer,
    required this.onRestore,
    required this.onDelete,
  });

  final FocusArea area;
  final bool busy;
  final bool blockedByTimer;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.minimumTouchTarget,
    child: PopupMenuButton<String>(
      key: Key('archived-focus-area-menu-${area.id}'),
      tooltip: 'Actions for ${area.name}',
      enabled: !busy,
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      onSelected: (value) {
        if (value == 'restore') onRestore();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'restore',
          child: Row(
            children: [
              Icon(Icons.restore, color: AppColors.primary),
              SizedBox(width: AppSpacing.xs),
              Text('Restore'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_forever_outlined, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  blockedByTimer ? 'Delete unavailable' : 'Delete permanently',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ArchivedAreaTable extends StatelessWidget {
  const _ArchivedAreaTable({
    required this.areas,
    required this.busy,
    required this.activeTimerAreaId,
    required this.onSelected,
    required this.onRestore,
    required this.onDelete,
  });

  final List<FocusArea> areas;
  final bool busy;
  final int? activeTimerAreaId;
  final ValueChanged<FocusArea>? onSelected;
  final ValueChanged<FocusArea> onRestore;
  final ValueChanged<FocusArea> onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColumnWidth = _priorityColumnWidth(
      context,
      areas,
      minimum: 96,
    );
    return _focusAreaTableSurface(
      key: const Key('archived-focus-areas-table'),
      child: Column(
        children: [
          _ArchivedTableHeader(priorityColumnWidth: priorityColumnWidth),
          for (final area in areas)
            _ArchivedTableRow(
              area: area,
              busy: busy,
              priorityColumnWidth: priorityColumnWidth,
              onSelected: onSelected == null ? null : () => onSelected!(area),
              blockedByTimer: activeTimerAreaId == area.id,
              onRestore: () => onRestore(area),
              onDelete: () => onDelete(area),
            ),
        ],
      ),
    );
  }
}

class _ArchivedTableHeader extends StatelessWidget {
  const _ArchivedTableHeader({required this.priorityColumnWidth});

  final double priorityColumnWidth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceTinted,
      child: Row(
        children: [
          SizedBox(
            width: priorityColumnWidth,
            child: Text('Priority', style: style),
          ),
          Expanded(flex: 5, child: Text('Focus Area', style: style)),
          Expanded(flex: 2, child: Text('Finish Date', style: style)),
          Expanded(flex: 2, child: Text('Archived At', style: style)),
          SizedBox(
            width: 104,
            child: Text('Actions', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

class _ArchivedTableRow extends StatelessWidget {
  const _ArchivedTableRow({
    required this.area,
    required this.busy,
    required this.priorityColumnWidth,
    required this.onSelected,
    required this.blockedByTimer,
    required this.onRestore,
    required this.onDelete,
  });

  final FocusArea area;
  final bool busy;
  final double priorityColumnWidth;
  final VoidCallback? onSelected;
  final bool blockedByTimer;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    child: InkWell(
      onTap: onSelected,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: priorityColumnWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [FocusAreaPriorityBadge(priority: area.priority)],
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (area.description?.trim().isNotEmpty == true)
                    Text(
                      area.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                area.targetEndDate == null
                    ? 'No finish date'
                    : _formatDate(area.targetEndDate!, includeYear: true),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                area.archivedAt == null
                    ? 'Unavailable'
                    : _formatDate(
                        area.archivedAt!.toLocal(),
                        includeYear: true,
                      ),
              ),
            ),
            SizedBox(
              width: 104,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: Key('restore-archived-focus-area-${area.id}'),
                    tooltip: 'Restore ${area.name}',
                    onPressed: busy ? null : onRestore,
                    icon: const Icon(Icons.restore, color: AppColors.primary),
                  ),
                  IconButton(
                    key: Key('delete-archived-focus-area-${area.id}'),
                    tooltip: blockedByTimer
                        ? 'Cannot delete while this area has an active timer'
                        : 'Permanently delete ${area.name}',
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => PonosStatePanel.empty(
    title: 'No Focus Areas yet',
    description: 'Create one to define what deserves your time.',
    illustrationAsset: AppAssets.emptyFocusAreas,
    actionLabel: onCreate == null ? null : 'Create Focus Area',
    onAction: onCreate,
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) => PonosStatePanel.error(
    title: 'Unable to load Focus Areas',
    description: message,
    actionLabel: 'Try again',
    onAction: () => onRetry(),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) => PonosCard(
    color: Theme.of(context).colorScheme.errorContainer,
    padding: PonosCardPadding.compact,
    child: Row(
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
        TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
      ],
    ),
  );
}

class _AreaStatusColors {
  const _AreaStatusColors({required this.background, required this.border});

  final Color background;
  final Color border;
}

class _Expiration {
  const _Expiration(this.days) : critical = days >= 15;

  final int days;
  final bool critical;

  String get semanticLabel => critical
      ? 'Critical expiration warning. Expired $days days ago.'
      : 'Expiration warning. Expired $days days ago.';
}

_Expiration? _expiration(FocusArea area, DateTime today) {
  final endDate = area.targetEndDate;
  if (endDate == null) return null;
  final days = _dateOnly(today).difference(_dateOnly(endDate)).inDays;
  return days <= 0 ? null : _Expiration(days);
}

_AreaStatusColors _statusColors(_Expiration? expiration) {
  if (expiration?.critical == true) {
    return const _AreaStatusColors(
      background: _dangerBackground,
      border: _dangerBorder,
    );
  }
  if (expiration != null) {
    return const _AreaStatusColors(
      background: _warningBackground,
      border: _warningBorder,
    );
  }
  return const _AreaStatusColors(
    background: AppColors.white,
    border: AppColors.borderStrong,
  );
}

String _areaSemanticLabel(
  FocusArea area,
  int? targetMinutes,
  _Expiration? expiration,
) {
  final parts = <String>[
    area.name,
    'Priority ${area.priority}',
    targetMinutes == null
        ? 'No target today'
        : '${_duration(targetMinutes)} target today',
  ];
  if (expiration != null) parts.add(expiration.semanticLabel);
  return parts.join('. ');
}

String _finishLabel(DateTime? value, DateTime today) {
  if (value == null) return '';
  final prefix = _dateOnly(value).isBefore(_dateOnly(today)) ? 'Ended' : 'Ends';
  return '$prefix ${_formatDate(value)}';
}

String _formatDate(DateTime value, {bool includeYear = false}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${value.day} ${months[value.month - 1]}';
  return includeYear ? '$date ${value.year}' : date;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'Focus Areas could not be loaded.',
};

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h 00m';
  return '${hours}h ${remainder.toString().padLeft(2, '0')}m';
}
