import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_priority_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../focus_timer/presentation/state/focus_timer_controller.dart';
import '../domain/models/focus_area.dart';
import '../domain/models/focus_area_target.dart';
import 'archived_focus_area_actions.dart';
import 'state/focus_areas_controller.dart';
import 'state/focus_areas_state.dart';
import 'widgets/focus_area_priority_badge.dart';

class ArchivedFocusAreaDetailsPage extends ConsumerWidget {
  const ArchivedFocusAreaDetailsPage({required this.area, super.key});

  final FocusArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = PonosViewportScope.sizeOf(context);
    final layout = AppBreakpoints.layoutFor(viewport.width);
    final desktopPlatform = _isDesktopPlatform(context);
    final activeTimerAreaId = ref.watch(
      focusTimerProvider.select((state) => state.activeTimer?.focusAreaId),
    );
    final busy = ref.watch(
      focusAreasProvider.select(
        (state) => state.status == FocusAreasStatus.saving,
      ),
    );
    final horizontalPadding = switch (layout) {
      AppLayoutSize.compact => desktopPlatform ? 20.0 : 14.0,
      AppLayoutSize.medium => 20.0,
      AppLayoutSize.expanded => 36.0,
    };
    final topPadding = layout == AppLayoutSize.compact && !desktopPlatform
        ? AppSpacing.xs
        : AppSpacing.lg;

    return PonosPageScaffold(
      maxContentWidth: double.infinity,
      contentPadding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        AppSpacing.lg,
      ),
      background: SvgPicture.asset(
        layout == AppLayoutSize.compact
            ? AppAssets.appCanvasMobile
            : AppAssets.appCanvasDesktop,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
      child: SingleChildScrollView(
        key: const Key('archived-focus-area-details-scroll-view'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailsHeader(area: area),
            const SizedBox(height: AppSpacing.sm),
            if (busy) ...[
              const LinearProgressIndicator(
                key: Key('archived-focus-area-details-saving'),
                minHeight: 2,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (layout == AppLayoutSize.expanded)
              _ExpandedDetails(
                area: area,
                busy: busy,
                blockedByTimer: activeTimerAreaId == area.id,
                onRestore: () => _restore(context, ref),
                onDelete: () => _delete(
                  context,
                  ref,
                  blockedByTimer: activeTimerAreaId == area.id,
                ),
              )
            else
              _StackedDetails(
                area: area,
                busy: busy,
                blockedByTimer: activeTimerAreaId == area.id,
                onRestore: () => _restore(context, ref),
                onDelete: () => _delete(
                  context,
                  ref,
                  blockedByTimer: activeTimerAreaId == area.id,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final restored = await restoreArchivedFocusArea(context, ref, area);
    if (restored && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref, {
    required bool blockedByTimer,
  }) async {
    final deleted = await deleteArchivedFocusArea(
      context,
      ref,
      area,
      blockedByTimer: blockedByTimer,
    );
    if (deleted && context.mounted) Navigator.of(context).pop();
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.area});

  final FocusArea area;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: AppSpacing.minimumTouchTarget,
        child: IconButton(
          key: const Key('back-from-archived-focus-area-details'),
          tooltip: 'Back to archived Focus Areas',
          onPressed: () => Navigator.of(context).maybePop(),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        ),
      ),
      Expanded(
        child: Text(
          area.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      FocusAreaPriorityBadge(priority: area.priority),
    ],
  );
}

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 56,
        child: PonosCard(
          borderColor: AppColors.borderStrong,
          padding: PonosCardPadding.compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Description(area: area),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              _Targets(area: area),
            ],
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.lg),
      Expanded(
        flex: 44,
        child: PonosCard(
          color: AppPriorityColors.forPriority(area.priority).background,
          borderColor: AppColors.borderStrong,
          padding: PonosCardPadding.compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Metadata(area: area),
              const SizedBox(height: AppSpacing.xs),
              _ArchivedActions(
                busy: busy,
                blockedByTimer: blockedByTimer,
                onRestore: onRestore,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _StackedDetails extends StatelessWidget {
  const _StackedDetails({
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PonosCard(
        borderColor: AppColors.borderStrong,
        padding: PonosCardPadding.compact,
        child: _Description(area: area),
      ),
      const SizedBox(height: AppSpacing.sm),
      PonosCard(
        borderColor: AppColors.borderStrong,
        padding: PonosCardPadding.compact,
        child: _Targets(area: area),
      ),
      const SizedBox(height: AppSpacing.sm),
      PonosCard(
        borderColor: AppColors.borderStrong,
        padding: PonosCardPadding.compact,
        child: _Metadata(area: area),
      ),
      const SizedBox(height: AppSpacing.sm),
      _ArchivedActions(
        busy: busy,
        blockedByTimer: blockedByTimer,
        onRestore: onRestore,
        onDelete: onDelete,
      ),
    ],
  );
}

class _Description extends StatelessWidget {
  const _Description({required this.area});

  final FocusArea area;

  @override
  Widget build(BuildContext context) {
    final description = area.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          description?.isNotEmpty == true
              ? description!
              : 'No description provided.',
          key: const Key('archived-focus-area-description'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: description?.isNotEmpty == true
                ? FontStyle.normal
                : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.area});

  final FocusArea area;

  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final targets = _targetsAtArchive(area);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily targets (last configured)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
          _TargetRow(
            weekday: weekdays[weekday - 1],
            minutes: targets[weekday]?.targetMinutes ?? 0,
            showDivider: weekday != DateTime.sunday,
          ),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.weekday,
    required this.minutes,
    required this.showDivider,
  });

  final String weekday;
  final int minutes;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$weekday, ${_duration(minutes)}',
    child: ExcludeSemantics(
      child: Container(
        key: Key('archived-target-${weekday.toLowerCase()}'),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                weekday,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              _duration(minutes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.area});

  final FocusArea area;

  @override
  Widget build(BuildContext context) {
    final colors = AppPriorityColors.forPriority(area.priority);
    return Column(
      children: [
        _MetadataRow(
          icon: Icons.calendar_today_outlined,
          label: 'Finish date',
          value: area.targetEndDate == null
              ? 'No finish date'
              : _formatDate(area.targetEndDate!),
        ),
        _MetadataRow(
          icon: Icons.inventory_2_outlined,
          label: 'Archived at',
          value: area.archivedAt == null
              ? 'Unavailable'
              : _formatDate(area.archivedAt!.toLocal()),
        ),
        _MetadataRow(
          icon: Icons.flag_outlined,
          label: 'Priority',
          value: 'P${area.priority}',
          valueColor: colors.foreground,
          showDivider: false,
        ),
      ],
    );
  }
}

class _ArchivedActions extends StatelessWidget {
  const _ArchivedActions({
    required this.busy,
    required this.blockedByTimer,
    required this.onRestore,
    required this.onDelete,
  });

  final bool busy;
  final bool blockedByTimer;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _DangerButton(
        label: blockedByTimer
            ? 'Delete unavailable while timer is active'
            : 'Delete permanently',
        onPressed: busy ? null : onDelete,
      ),
      const SizedBox(height: AppSpacing.xs),
      PonosButton.primary(
        key: const Key('restore-archived-focus-area-details'),
        label: 'Restore',
        icon: const Icon(Icons.restore, size: 18),
        visualHeight: 42,
        onPressed: busy ? null : onRestore,
      ),
    ],
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 55),
    decoration: showDivider
        ? const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          )
        : null,
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor ?? AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(
        color: onPressed == null
            ? AppColors.error.withValues(alpha: 0.45)
            : AppColors.error,
      ),
      borderRadius: AppRadius.control,
      color: AppColors.white,
    ),
    child: SizedBox(
      width: double.infinity,
      child: PonosButton.danger(
        key: const Key('delete-archived-focus-area-details'),
        label: label,
        icon: const Icon(Icons.delete_forever_outlined, size: 18),
        visualHeight: 42,
        onPressed: onPressed,
      ),
    ),
  );
}

Map<int, FocusAreaTarget> _targetsAtArchive(FocusArea area) {
  final archiveDate = area.archivedAt?.toLocal();
  final snapshot = archiveDate == null
      ? null
      : DateTime(archiveDate.year, archiveDate.month, archiveDate.day);
  final result = <int, FocusAreaTarget>{};
  for (final target in area.targets) {
    final starts = DateTime(
      target.validFrom.year,
      target.validFrom.month,
      target.validFrom.day,
    );
    if (snapshot != null && starts.isAfter(snapshot)) continue;
    final validUntil = target.validUntil;
    if (snapshot != null && validUntil != null) {
      final ends = DateTime(
        validUntil.year,
        validUntil.month,
        validUntil.day,
      );
      if (snapshot.isAfter(ends)) continue;
    }
    final current = result[target.weekday];
    if (current == null || target.validFrom.isAfter(current.validFrom)) {
      result[target.weekday] = target;
    }
  }
  return result;
}

bool _isDesktopPlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return kIsWeb ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
}

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours}h ${remainder.toString().padLeft(2, '0')}m';
}

String _formatDate(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
