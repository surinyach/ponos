import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../work_entries/presentation/special_activities_page.dart';
import '../domain/models/focus_area.dart';
import 'focus_areas_page.dart';
import 'state/focus_areas_controller.dart';

class WorkAreasPage extends ConsumerStatefulWidget {
  const WorkAreasPage({
    required this.onCreateFocusArea,
    required this.onCreateSpecialActivity,
    required this.onFocusAreaSelected,
    super.key,
  });

  final VoidCallback onCreateFocusArea;
  final VoidCallback onCreateSpecialActivity;
  final ValueChanged<FocusArea> onFocusAreaSelected;

  @override
  ConsumerState<WorkAreasPage> createState() => _WorkAreasPageState();
}

class _WorkAreasPageState extends ConsumerState<WorkAreasPage> {
  int _selectedType = 0;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final viewport = PonosViewportScope.sizeOf(context);
    final layout = AppBreakpoints.layoutFor(viewport.width);
    final archivedCount = ref.watch(
      archivedFocusAreasProvider.select((value) => value.value?.length ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactContent = constraints.maxWidth < AppBreakpoints.medium;
        final horizontalPadding = switch (layout) {
          AppLayoutSize.compact => 14.0,
          AppLayoutSize.medium => 20.0,
          AppLayoutSize.expanded => 40.0,
        };
        final topPadding = layout == AppLayoutSize.compact
            ? AppSpacing.xxs
            : AppSpacing.lg;
        final showHeaderActions = !compactContent;

        return PonosPageScaffold(
          maxContentWidth: double.infinity,
          background: SvgPicture.asset(
            layout == AppLayoutSize.compact
                ? AppAssets.appCanvasMobile
                : AppAssets.appCanvasDesktop,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkAreasHeader(
                trailing: showHeaderActions && layout == AppLayoutSize.expanded
                    ? _headerActions(archivedCount)
                    : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: PonosInlineTabs(
                      key: const Key('work-area-type'),
                      tabs: const ['Focus Areas', 'Special Activities'],
                      selectedIndex: _selectedType,
                      semanticLabel: 'Work Area type',
                      onSelected: (index) {
                        setState(() {
                          _selectedType = index;
                          if (index != 0) _showArchived = false;
                        });
                      },
                    ),
                  ),
                  if (layout == AppLayoutSize.medium && showHeaderActions) ...[
                    const SizedBox(width: AppSpacing.md),
                    _headerActions(archivedCount),
                  ],
                ],
              ),
              Expanded(
                child: _selectedType == 0
                    ? FocusAreasPage(
                        archived: _showArchived,
                        archivedCount: archivedCount,
                        showCompactActions: !showHeaderActions,
                        onCreate: widget.onCreateFocusArea,
                        onAreaSelected: widget.onFocusAreaSelected,
                        onViewArchived: () =>
                            setState(() => _showArchived = true),
                        onBackFromArchived: () =>
                            setState(() => _showArchived = false),
                        layout: layout,
                      )
                    : SpecialActivitiesPage(
                        embedded: true,
                        showCreateAction: !showHeaderActions,
                        onCreate: widget.onCreateSpecialActivity,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerActions(int archivedCount) {
    if (_selectedType == 1) {
      return _WorkAreaAction(
        key: const Key('new-special-activity'),
        label: 'New Special Activity',
        icon: Icons.add,
        onPressed: widget.onCreateSpecialActivity,
        primary: true,
        width: 190,
      );
    }
    if (_showArchived) {
      return _WorkAreaAction(
        label: 'Back to Focus Areas',
        icon: Icons.arrow_back,
        onPressed: () => setState(() => _showArchived = false),
        primary: false,
        width: 184,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WorkAreaAction(
          key: const Key('view-archived-focus-areas'),
          label: 'View archived ($archivedCount)',
          icon: Icons.inventory_2_outlined,
          onPressed: () => setState(() => _showArchived = true),
          primary: false,
          width: 170,
        ),
        const SizedBox(width: AppSpacing.xs),
        _WorkAreaAction(
          key: const Key('new-focus-area'),
          label: 'New Focus Area',
          icon: Icons.add,
          onPressed: widget.onCreateFocusArea,
          primary: true,
          width: 180,
        ),
      ],
    );
  }
}

class _WorkAreaAction extends StatelessWidget {
  const _WorkAreaAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
    required this.width,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? AppColors.white : AppColors.primary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        width: width,
        height: AppSpacing.minimumTouchTarget,
        child: Center(
          child: Material(
            color: primary ? AppColors.primary : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: primary
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFCBDFEF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: width,
                height: 42,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
        ),
      ),
    );
  }
}

class _WorkAreasHeader extends StatelessWidget {
  const _WorkAreasHeader({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Areas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Manage your Focus Areas and Special Activities.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: AppSpacing.md),
        trailing!,
      ],
    ],
  );
}
