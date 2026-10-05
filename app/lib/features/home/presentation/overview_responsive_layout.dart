import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../focus_areas/domain/models/today_overview.dart';
import '../../work_goals/domain/models/work_goals.dart';
import 'widgets/focus_areas.dart';

const _streakSurface = Color(0xFFF8F2EA);
const _streakBorder = Color(0xFFE7D8C8);
const _overviewSuccess = Color(0xFF3B7A57);
const _overviewDanger = Color(0xFFC62828);

const _overviewSectionTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
  color: AppColors.primaryDark,
);
const _overviewSummaryLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 9,
  height: 12 / 9,
  fontWeight: FontWeight.w500,
  color: AppColors.textSecondary,
);
const _overviewSummaryValueStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 10,
  height: 14 / 10,
  fontWeight: FontWeight.w500,
  color: AppColors.textSecondary,
);

class OverviewResponsiveLayout extends StatelessWidget {
  const OverviewResponsiveLayout({
    required this.data,
    required this.workGoals,
    required this.layout,
    required this.onStartFocus,
    required this.onManageWorkAreas,
    required this.onLogWork,
    required this.onWorkGoals,
    this.compactDesktop = false,
    super.key,
  });

  static const double _normalMainRegionMinimumHeight = 260;
  static const double _normalStatisticsMinimumHeight = 148;
  static const double _expandedStreakMinimumHeight = 148;
  static const double _mediumStreakMinimumHeight = 154;

  static double minimumNormalHeight(AppLayoutSize layout) => switch (layout) {
    AppLayoutSize.compact => _CompactOverviewMetrics.minimumTotalHeight,
    AppLayoutSize.medium =>
      _mediumStreakMinimumHeight +
          (AppSpacing.md * 2) +
          _normalMainRegionMinimumHeight +
          _normalStatisticsMinimumHeight,
    AppLayoutSize.expanded =>
      _expandedStreakMinimumHeight + 40 + _normalMainRegionMinimumHeight + 150,
  };

  final TodayOverview data;
  final WorkGoals? workGoals;
  final AppLayoutSize layout;
  final VoidCallback onStartFocus;
  final VoidCallback onManageWorkAreas;
  final VoidCallback onLogWork;
  final VoidCallback onWorkGoals;
  final bool compactDesktop;

  @override
  Widget build(BuildContext context) {
    if (compactDesktop) {
      return _CompactDesktopOverview(
        data: data,
        workGoals: workGoals,
        onStartFocus: onStartFocus,
        onManageWorkAreas: onManageWorkAreas,
        onLogWork: onLogWork,
        onWorkGoals: onWorkGoals,
      );
    }
    if (layout == AppLayoutSize.compact) {
      return _CompactOverview(
        data: data,
        workGoals: workGoals,
        onStartFocus: onStartFocus,
        onManageWorkAreas: onManageWorkAreas,
        onLogWork: onLogWork,
        onWorkGoals: onWorkGoals,
      );
    }

    final today = _CompactTodaySection(
      data: data,
      onStartFocus: onStartFocus,
      onLogWork: onLogWork,
      pillarTopInset: layout == AppLayoutSize.expanded ? 8 : 16,
      pillarHorizontalOffset: layout == AppLayoutSize.expanded ? -15 : 0,
      pillarMaxWidth: layout == AppLayoutSize.expanded ? 86 : 96,
      pillarMaxHeight: 112,
      stretchPillar: layout == AppLayoutSize.expanded,
    );
    final streak = _ReferenceExpandedStreakSection(
      data: data,
      workGoals: workGoals,
      onEditGoals: onWorkGoals,
    );
    return switch (layout) {
      AppLayoutSize.compact => throw StateError('Handled above'),
      AppLayoutSize.medium => Column(
        key: const Key('overview-medium'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 154,
            child: _CompactStreakSection(
              data: data,
              workGoals: workGoals,
              onEditGoals: onWorkGoals,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 302, child: today),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 330,
                  child: _CompactWorkAreasSection(
                    data: data,
                    onManageWorkAreas: onManageWorkAreas,
                    referenceWideTypography: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 148, child: _ReferenceStatisticsSection(data: data)),
        ],
      ),
      AppLayoutSize.expanded => Column(
        key: const Key('overview-expanded'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 148, child: streak),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 430, child: today),
                const SizedBox(width: 20),
                Expanded(
                  flex: 710,
                  child: _CompactWorkAreasSection(
                    data: data,
                    onManageWorkAreas: onManageWorkAreas,
                    referenceWideTypography: true,
                    referenceDesktopSpacing: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: 150, child: _ReferenceStatisticsSection(data: data)),
        ],
      ),
    };
  }
}

abstract final class _CompactOverviewMetrics {
  static const double gap = AppSpacing.sm;
  static const double streakMinimumHeight = 164;
  static const double todayMinimumHeight = 196;
  static const double workAreasMinimumHeight = 120;
  static const double statisticsMinimumHeight = 168;
  static const double minimumTotalHeight =
      streakMinimumHeight +
      todayMinimumHeight +
      workAreasMinimumHeight +
      statisticsMinimumHeight +
      (gap * 3);
}

class _CompactOverview extends StatelessWidget {
  const _CompactOverview({
    required this.data,
    required this.workGoals,
    required this.onStartFocus,
    required this.onManageWorkAreas,
    required this.onLogWork,
    required this.onWorkGoals,
  });

  final TodayOverview data;
  final WorkGoals? workGoals;
  final VoidCallback onStartFocus;
  final VoidCallback onManageWorkAreas;
  final VoidCallback onLogWork;
  final VoidCallback onWorkGoals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaledMinimumHeight = MediaQuery.textScalerOf(
        context,
      ).scale(_CompactOverviewMetrics.minimumTotalHeight);
      final textScalingIncreasesContent =
          scaledMinimumHeight > _CompactOverviewMetrics.minimumTotalHeight;
      if (textScalingIncreasesContent &&
          scaledMinimumHeight > constraints.maxHeight) {
        return SingleChildScrollView(
          key: const Key('overview-accessibility-scroll'),
          primary: false,
          child: Column(
            key: const Key('overview-compact'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactStreakSection(
                data: data,
                workGoals: workGoals,
                onEditGoals: onWorkGoals,
                dense: true,
                accessibilityLayout: true,
              ),
              const SizedBox(height: _CompactOverviewMetrics.gap),
              _CompactTodaySection(
                data: data,
                onStartFocus: onStartFocus,
                onLogWork: onLogWork,
                dense: true,
              ),
              const SizedBox(height: _CompactOverviewMetrics.gap),
              _CompactWorkAreasSection(
                data: data,
                onManageWorkAreas: onManageWorkAreas,
                dense: true,
                accessibilityLayout: true,
              ),
              const SizedBox(height: _CompactOverviewMetrics.gap),
              _CompactStatisticsSection(data: data, dense: true),
            ],
          ),
        );
      }
      final canonicalFits =
          constraints.maxHeight >= _CompactOverviewMetrics.minimumTotalHeight;
      const denseMinimums = [150.0, 161.0, 82.0, 83.0];
      final denseTotal =
          denseMinimums.reduce((a, b) => a + b) +
          (_CompactOverviewMetrics.gap * 3);
      final extraHeight = canonicalFits
          ? constraints.maxHeight - _CompactOverviewMetrics.minimumTotalHeight
          : (constraints.maxHeight - denseTotal).clamp(0.0, double.infinity);

      double sectionHeight(double canonical, double dense, int share) =>
          (canonicalFits ? canonical : dense) + (extraHeight * share / 14);

      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          key: const Key('overview-compact'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: sectionHeight(
                _CompactOverviewMetrics.streakMinimumHeight,
                denseMinimums[0],
                5,
              ),
              child: _CompactStreakSection(
                data: data,
                workGoals: workGoals,
                onEditGoals: onWorkGoals,
                dense: !canonicalFits,
              ),
            ),
            const SizedBox(height: _CompactOverviewMetrics.gap),
            SizedBox(
              height: sectionHeight(
                _CompactOverviewMetrics.todayMinimumHeight,
                denseMinimums[1],
                5,
              ),
              child: _CompactTodaySection(
                data: data,
                onStartFocus: onStartFocus,
                onLogWork: onLogWork,
                dense: !canonicalFits,
                pillarTopInset: 6,
              ),
            ),
            const SizedBox(height: _CompactOverviewMetrics.gap),
            SizedBox(
              height: sectionHeight(
                _CompactOverviewMetrics.workAreasMinimumHeight,
                denseMinimums[2],
                2,
              ),
              child: _CompactWorkAreasSection(
                data: data,
                onManageWorkAreas: onManageWorkAreas,
                dense: !canonicalFits,
              ),
            ),
            const SizedBox(height: _CompactOverviewMetrics.gap),
            SizedBox(
              height: sectionHeight(
                _CompactOverviewMetrics.statisticsMinimumHeight,
                denseMinimums[3],
                2,
              ),
              child: _CompactStatisticsSection(
                data: data,
                dense: !canonicalFits,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactDesktopOverview extends StatelessWidget {
  const _CompactDesktopOverview({
    required this.data,
    required this.workGoals,
    required this.onStartFocus,
    required this.onManageWorkAreas,
    required this.onLogWork,
    required this.onWorkGoals,
  });

  static const double _minimumColumnWidth = 280;

  final TodayOverview data;
  final WorkGoals? workGoals;
  final VoidCallback onStartFocus;
  final VoidCallback onManageWorkAreas;
  final VoidCallback onLogWork;
  final VoidCallback onWorkGoals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumnsFit =
          constraints.maxWidth >=
          (_minimumColumnWidth * 2) + _CompactOverviewMetrics.gap;
      if (!twoColumnsFit) {
        const canonicalHeight = 150.0 + 190 + 110 + 124 + (12 * 3);
        if (constraints.maxHeight >= canonicalHeight) {
          return Column(
            key: const Key('overview-compact-desktop'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: _CompactStreakSection(
                  data: data,
                  workGoals: workGoals,
                  onEditGoals: onWorkGoals,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 190,
                child: _CompactTodaySection(
                  data: data,
                  onStartFocus: onStartFocus,
                  onLogWork: onLogWork,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 110,
                child: _CompactWorkAreasSection(
                  data: data,
                  onManageWorkAreas: onManageWorkAreas,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 124,
                child: _CompactStatisticsSection(data: data),
              ),
            ],
          );
        }
        return _CompactOverview(
          data: data,
          workGoals: workGoals,
          onStartFocus: onStartFocus,
          onManageWorkAreas: onManageWorkAreas,
          onLogWork: onLogWork,
          onWorkGoals: onWorkGoals,
        );
      }

      const lowerMinimumHeight =
          _CompactOverviewMetrics.workAreasMinimumHeight +
          _CompactOverviewMetrics.gap +
          _CompactOverviewMetrics.statisticsMinimumHeight;
      final extraHeight =
          constraints.maxHeight -
          _CompactOverviewMetrics.streakMinimumHeight -
          _CompactOverviewMetrics.gap -
          lowerMinimumHeight;
      final availableExtra = extraHeight > 0 ? extraHeight : 0.0;
      final streakHeight =
          _CompactOverviewMetrics.streakMinimumHeight + (availableExtra * 0.35);
      final lowerHeight = lowerMinimumHeight + (availableExtra * 0.65);
      final secondaryExtra =
          lowerHeight -
          _CompactOverviewMetrics.gap -
          _CompactOverviewMetrics.workAreasMinimumHeight -
          _CompactOverviewMetrics.statisticsMinimumHeight;

      return Column(
        key: const Key('overview-compact-desktop'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: streakHeight,
            child: _CompactStreakSection(
              data: data,
              workGoals: workGoals,
              onEditGoals: onWorkGoals,
            ),
          ),
          const SizedBox(height: _CompactOverviewMetrics.gap),
          SizedBox(
            height: lowerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CompactTodaySection(
                    data: data,
                    onStartFocus: onStartFocus,
                    onLogWork: onLogWork,
                  ),
                ),
                const SizedBox(width: _CompactOverviewMetrics.gap),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height:
                            _CompactOverviewMetrics.workAreasMinimumHeight +
                            (secondaryExtra * 0.4),
                        child: _CompactWorkAreasSection(
                          data: data,
                          onManageWorkAreas: onManageWorkAreas,
                        ),
                      ),
                      const SizedBox(height: _CompactOverviewMetrics.gap),
                      Expanded(child: _CompactStatisticsSection(data: data)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _CompactTodaySection extends StatelessWidget {
  const _CompactTodaySection({
    required this.data,
    required this.onStartFocus,
    required this.onLogWork,
    this.dense = false,
    this.pillarTopInset = 16,
    this.pillarHorizontalOffset = 0,
    this.pillarMaxWidth = 96,
    this.pillarMaxHeight = 112,
    this.stretchPillar = false,
  });

  final TodayOverview data;
  final VoidCallback onStartFocus;
  final VoidCallback onLogWork;
  final bool dense;
  final double pillarTopInset;
  final double pillarHorizontalOffset;
  final double pillarMaxWidth;
  final double pillarMaxHeight;
  final bool stretchPillar;

  @override
  Widget build(BuildContext context) {
    final targetMicros = data.expectedFocusTime.inMicroseconds;
    final progress = targetMicros == 0
        ? 0.0
        : (data.actualFocusedTime.inMicroseconds / targetMicros).clamp(
            0.0,
            1.0,
          );
    return LayoutBuilder(
      builder: (context, constraints) => _CompactCard(
        key: const Key('overview-today'),
        color: AppColors.surfaceTinted,
        dense: dense,
        padding: dense
            ? null
            : const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Today',
                        style: _overviewSectionTitleStyle.copyWith(
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatDuration(data.actualFocusedTime),
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 26,
                          height: 34 / 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'of ${_formatDuration(data.expectedFocusTime)} focused',
                        style: _overviewSummaryValueStyle.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: stretchPillar ? 9 : AppSpacing.xxs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: constraints.maxWidth * 0.416,
                          child: Semantics(
                            label: 'Daily focus goal',
                            value: '${(progress * 100).round()} percent',
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              color: AppColors.primary,
                              backgroundColor: const Color(0xFFD9E5F0),
                              borderRadius: AppRadius.pill,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: Transform.translate(
                    offset: Offset(
                      dense ? 0 : pillarHorizontalOffset,
                      dense ? 0 : pillarTopInset,
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: stretchPillar
                          ? SizedBox(
                              key: const Key('compact-today-pillar'),
                              width: pillarMaxWidth,
                              height: pillarMaxHeight,
                              child: SvgPicture.asset(
                                AppAssets.greekPillar,
                                fit: BoxFit.fill,
                                alignment: Alignment.topRight,
                                excludeFromSemantics: true,
                              ),
                            )
                          : ConstrainedBox(
                              key: const Key('compact-today-pillar'),
                              constraints: BoxConstraints(
                                maxWidth: pillarMaxWidth,
                                maxHeight: pillarMaxHeight,
                              ),
                              child: SvgPicture.asset(
                                AppAssets.greekPillar,
                                fit: BoxFit.contain,
                                alignment: Alignment.topRight,
                                excludeFromSemantics: true,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (dense)
              const SizedBox(height: AppSpacing.xxs)
            else
              const Spacer(),
            Transform.translate(
              offset: Offset(0, stretchPillar ? 3 : 0),
              child: Row(
                key: const Key('overview-actions'),
                children: [
                  Expanded(
                    child: _OverviewButtonTypography(
                      child: Stack(
                        fit: StackFit.passthrough,
                        alignment: Alignment.centerLeft,
                        children: [
                          PonosButton.primary(
                            label: 'Start Focus',
                            onPressed: onStartFocus,
                            visualHeight: stretchPillar ? 42 : null,
                          ),
                          const Positioned(
                            left: AppSpacing.sm,
                            child: ExcludeSemantics(
                              child: Icon(
                                Icons.play_arrow,
                                size: 14,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _OverviewButtonTypography(
                      child: PonosButton.secondary(
                        label: 'Log Work',
                        onPressed: onLogWork,
                        visualHeight: stretchPillar ? 42 : null,
                        borderColor: stretchPillar ? AppColors.primary : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewButtonTypography extends StatelessWidget {
  const _OverviewButtonTypography({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          labelLarge: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CompactWorkAreasSection extends StatelessWidget {
  const _CompactWorkAreasSection({
    required this.data,
    required this.onManageWorkAreas,
    this.dense = false,
    this.accessibilityLayout = false,
    this.referenceWideTypography = false,
    this.referenceDesktopSpacing = false,
  });

  final TodayOverview data;
  final VoidCallback onManageWorkAreas;
  final bool dense;
  final bool accessibilityLayout;
  final bool referenceWideTypography;
  final bool referenceDesktopSpacing;

  @override
  Widget build(BuildContext context) {
    final specialFocused = data.specialActivities.fold(
      Duration.zero,
      (total, item) => total + item.focusedTime,
    );
    final specialRest = data.specialActivities.fold(
      Duration.zero,
      (total, item) => total + item.restTime,
    );
    final specialSummary = data.specialActivities.isEmpty
        ? 'No special activity recorded today'
        : 'Special activities · ${_formatDuration(specialFocused)} focused · '
              '${_formatDuration(specialRest)} rest';
    return _CompactSummaryCard(
      key: const Key('overview-work-areas'),
      title: 'Work Areas',
      rows: [
        _SummaryRowData(
          label: 'Focus Areas',
          value:
              '${data.completedFocusAreas} / ${data.targetedFocusAreas} complete',
        ),
        _SummaryRowData(label: 'Special Activities', value: specialSummary),
      ],
      semanticHint: 'Show Work Areas details',
      onTap: () => _showOverviewSheet(
        context,
        key: const Key('work-areas-detail-sheet'),
        title: 'Work Areas',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusAreas(
              targetDate: data.date,
              specialActivities: data.specialActivities,
              areas: data.areas.map((item) => item.focusArea).toList(),
              workedTodayByAreaId: {
                for (final item in data.areas)
                  item.focusArea.id: item.focusedTime,
              },
              dailyTargetByAreaId: {
                for (final item in data.areas)
                  item.focusArea.id: item.targetTime,
              },
              completedByAreaId: {
                for (final item in data.areas)
                  item.focusArea.id: item.completed,
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            PonosButton.secondary(
              label: 'Manage Work Areas',
              onPressed: () {
                Navigator.of(context).pop();
                onManageWorkAreas();
              },
            ),
          ],
        ),
      ),
      dense: dense,
      accessibilityLayout: accessibilityLayout,
      referenceWideTypography: referenceWideTypography,
      referenceDesktopSpacing: referenceDesktopSpacing,
    );
  }
}

class _CompactStreakSection extends StatelessWidget {
  const _CompactStreakSection({
    required this.data,
    required this.workGoals,
    required this.onEditGoals,
    this.dense = false,
    this.accessibilityLayout = false,
  });

  final TodayOverview data;
  final WorkGoals? workGoals;
  final VoidCallback onEditGoals;
  final bool dense;
  final bool accessibilityLayout;

  @override
  Widget build(BuildContext context) {
    final dailyGoal = workGoals?.dailyGoals
        .where((goal) => goal.weekday == data.date.weekday)
        .firstOrNull
        ?.targetMinutes;
    final weeklyGoal = workGoals?.weeklyGoalMinutes;
    return _CompactCard(
      key: const Key('overview-streak'),
      color: _streakSurface,
      borderColor: _streakBorder,
      dense: dense,
      padding: dense ? null : const EdgeInsets.all(14),
      child: InkWell(
        key: const Key('compact-streak-summary'),
        borderRadius: AppRadius.control,
        onTap: () => _showOverviewSheet(
          context,
          key: const Key('streak-detail-sheet'),
          title: 'Streak consistency',
          child: _StreakDetails(data: data),
        ),
        child: dense
            ? _DenseStreakContent(
                data: data,
                workGoals: workGoals,
                onEditGoals: onEditGoals,
                accessibilityLayout: accessibilityLayout,
              )
            : Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: AppRadius.pill,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Streak consistency',
                            style: _overviewSectionTitleStyle,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.xs,
                    right: 0,
                    top: 36,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${data.streak.currentDailyStreak} day streak',
                            style: _overviewSummaryValueStyle.copyWith(
                              fontSize: 11,
                              height: 14 / 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${data.streak.currentWeeklyStreak} week streak',
                            style: _overviewSummaryValueStyle.copyWith(
                              fontSize: 11,
                              height: 14 / 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: -4,
                    top: 54,
                    child: _RecentDayIndicators(
                      days: data.streak.recentDays,
                      compact: true,
                      showLabels: true,
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.xs,
                    bottom: 0,
                    child: Row(
                      children: [
                        _GoalValue(
                          label: 'Today',
                          value: dailyGoal == null
                              ? '—'
                              : _formatDuration(Duration(minutes: dailyGoal)),
                          compact: true,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _GoalValue(
                          label: 'This week',
                          value: weeklyGoal == null
                              ? '—'
                              : _formatDuration(Duration(minutes: weeklyGoal)),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: SizedBox.square(
                      key: const Key('compact-edit-goals-action'),
                      dimension: AppSpacing.minimumTouchTarget,
                      child: PonosIconButton(
                        semanticLabel: 'Edit goals',
                        tooltip: 'Edit goals',
                        icon: const Icon(Icons.tune),
                        onPressed: onEditGoals,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DenseStreakContent extends StatelessWidget {
  const _DenseStreakContent({
    required this.data,
    required this.workGoals,
    required this.onEditGoals,
    this.accessibilityLayout = false,
  });

  final TodayOverview data;
  final WorkGoals? workGoals;
  final VoidCallback onEditGoals;
  final bool accessibilityLayout;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Streak consistency',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '${data.streak.currentDailyStreak} day streak',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              '${data.streak.currentWeeklyStreak} week streak',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      _RecentDayIndicators(days: data.streak.recentDays, compact: true),
      _StreakGoals(
        date: data.date,
        workGoals: workGoals,
        onEditGoals: onEditGoals,
        compact: true,
        accessibilityLayout: accessibilityLayout,
      ),
    ],
  );
}

class _CompactStatisticsSection extends StatelessWidget {
  const _CompactStatisticsSection({required this.data, this.dense = false});

  final TodayOverview data;
  final bool dense;

  @override
  Widget build(BuildContext context) => _CompactCard(
    key: const Key('overview-statistics'),
    dense: dense,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Work statistics', style: _overviewSectionTitleStyle),
        const SizedBox(height: AppSpacing.xxs),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                _CompactMetric(
                  label: 'Days',
                  value: '${data.overall.daysWorked}',
                  dense: dense,
                ),
                _CompactMetric(
                  label: 'Focused',
                  value: _formatDuration(data.overall.focusedTime),
                  dense: dense,
                ),
              ],
            ),
            Row(
              children: [
                _CompactMetric(
                  label: 'Rest',
                  value: _formatDuration(data.overall.restTime),
                  dense: dense,
                ),
                _CompactMetric(
                  label: 'Tracked',
                  value: _formatDuration(data.overall.trackedTime),
                  dense: dense,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReferenceStatisticsSection extends StatelessWidget {
  const _ReferenceStatisticsSection({required this.data});

  final TodayOverview data;

  @override
  Widget build(BuildContext context) => _CompactCard(
    key: const Key('overview-statistics'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Work statistics', style: _overviewSectionTitleStyle),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _CompactMetric(
              label: 'Days',
              value: '${data.overall.daysWorked}',
              referenceWideTypography: true,
            ),
            _CompactMetric(
              label: 'Focused',
              value: _formatDuration(data.overall.focusedTime),
              referenceWideTypography: true,
            ),
            _CompactMetric(
              label: 'Rest',
              value: _formatDuration(data.overall.restTime),
              referenceWideTypography: true,
            ),
            _CompactMetric(
              label: 'Tracked',
              value: _formatDuration(data.overall.trackedTime),
              referenceWideTypography: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.dense = false,
    this.referenceWideTypography = false,
  });

  final String label;
  final String value;
  final bool dense;
  final bool referenceWideTypography;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: label,
      value: value,
      child: ExcludeSemantics(
        child: dense
            ? Row(
                children: [
                  Text(
                    label,
                    style: referenceWideTypography
                        ? _overviewSummaryLabelStyle.copyWith(fontSize: 10)
                        : _overviewSummaryLabelStyle,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: referenceWideTypography ? 18 : 14,
                        height: referenceWideTypography ? 24 / 18 : 20 / 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: referenceWideTypography
                        ? _overviewSummaryLabelStyle.copyWith(fontSize: 10)
                        : _overviewSummaryLabelStyle,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: referenceWideTypography ? 18 : 14,
                      height: referenceWideTypography ? 24 / 18 : 20 / 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _CompactSummaryCard extends StatelessWidget {
  const _CompactSummaryCard({
    required this.title,
    required this.rows,
    required this.semanticHint,
    required this.onTap,
    this.dense = false,
    this.accessibilityLayout = false,
    this.referenceWideTypography = false,
    this.referenceDesktopSpacing = false,
    super.key,
  });

  final String title;
  final List<_SummaryRowData> rows;
  final String semanticHint;
  final VoidCallback onTap;
  final bool dense;
  final bool accessibilityLayout;
  final bool referenceWideTypography;
  final bool referenceDesktopSpacing;

  @override
  Widget build(BuildContext context) => _CompactCard(
    dense: dense,
    child: Semantics(
      button: true,
      hint: semanticHint,
      child: InkWell(
        borderRadius: AppRadius.control,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    style: _overviewSectionTitleStyle,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (var index = 0; index < rows.length; index++)
              if (accessibilityLayout)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[index].label,
                        style: referenceWideTypography
                            ? _overviewSummaryLabelStyle.copyWith(fontSize: 10)
                            : _overviewSummaryLabelStyle,
                      ),
                      Text(
                        rows[index].value,
                        style: _overviewSummaryValueStyle,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(
                    bottom: referenceDesktopSpacing && index < rows.length - 1
                        ? 12
                        : 0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[index].label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: referenceWideTypography
                              ? _overviewSummaryLabelStyle.copyWith(
                                  fontSize: 10,
                                )
                              : _overviewSummaryLabelStyle,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          rows[index].value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: _overviewSummaryValueStyle,
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

class _SummaryRowData {
  const _SummaryRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.child,
    this.color,
    this.dense = false,
    this.padding,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final Color? color;
  final bool dense;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? AppColors.white,
      border: Border.all(color: borderColor ?? AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Padding(
      padding:
          padding ??
          (dense
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                )
              : const EdgeInsets.all(AppSpacing.md)),
      child: child,
    ),
  );
}

class _StreakDetails extends StatelessWidget {
  const _StreakDetails({required this.data, this.horizontal = false});

  final TodayOverview data;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final daily = PonosMetricTile(
      label: 'Daily streak',
      value:
          '${data.streak.currentDailyStreak} '
          '${data.streak.currentDailyStreak == 1 ? 'day' : 'days'}',
    );
    final weekly = PonosMetricTile(
      label: 'Weekly streak',
      value:
          '${data.streak.currentWeeklyStreak} '
          '${data.streak.currentWeeklyStreak == 1 ? 'week' : 'weeks'}',
    );
    final recent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Recent 7 days', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _RecentDayIndicators(days: data.streak.recentDays),
      ],
    );
    if (horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: daily),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: 2, child: weekly),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: KeyedSubtree(
                key: const Key('desktop-recent-days-group'),
                child: recent,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: daily),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: weekly),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        recent,
      ],
    );
  }
}

class _RecentDayIndicators extends StatelessWidget {
  const _RecentDayIndicators({
    required this.days,
    this.compact = false,
    this.showLabels = false,
    this.desktopReferenceSpacing = false,
  });

  final List<DailyCompletion> days;
  final bool compact;
  final bool showLabels;
  final bool desktopReferenceSpacing;

  @override
  Widget build(BuildContext context) {
    final visibleDays = days.length <= 7 ? days : days.sublist(days.length - 7);
    return Wrap(
      alignment: WrapAlignment.start,
      children: [
        for (final day in visibleDays)
          Padding(
            padding: desktopReferenceSpacing
                ? const EdgeInsets.only(left: 1, right: 7)
                : EdgeInsets.symmetric(horizontal: compact ? 5 : 2),
            child: _RecentDayIndicator(
              day: day,
              compact: compact,
              showLabel: showLabels,
            ),
          ),
      ],
    );
  }
}

class _RecentDayIndicator extends StatelessWidget {
  const _RecentDayIndicator({
    required this.day,
    required this.compact,
    this.showLabel = false,
  });

  final DailyCompletion day;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (day.state) {
      DailyCompletionState.completed => (
        Icons.check_rounded,
        _overviewSuccess,
        'completed',
      ),
      DailyCompletionState.failed => (
        Icons.close_rounded,
        _overviewDanger,
        'failed',
      ),
      DailyCompletionState.neutral => (
        Icons.remove_rounded,
        AppColors.textSecondary,
        'neutral',
      ),
      DailyCompletionState.inProgress => (
        Icons.more_horiz_rounded,
        AppColors.accent,
        'in progress',
      ),
    };
    final size = compact ? 18.0 : 32.0;
    return Semantics(
      label: '${_weekdayLabel(day.date.weekday)}: $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color),
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: compact ? 12 : 18, color: color),
            ),
            if (!compact || showLabel) ...[
              SizedBox(height: compact ? 2 : AppSpacing.xxs),
              Text(
                _weekdayLabel(day.date.weekday),
                style: compact
                    ? _overviewSummaryLabelStyle.copyWith(fontSize: 8)
                    : Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showOverviewSheet(
  BuildContext context, {
  required Key key,
  required String title,
  required Widget child,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SingleChildScrollView(
    key: key,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  ),
);

// Retained for the detailed loading/state presentation used by later Overview work.
// ignore: unused_element
class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.data,
    required this.layout,
    required this.onStartFocus,
    required this.onLogWork,
  });

  final TodayOverview data;
  final AppLayoutSize layout;
  final VoidCallback onStartFocus;
  final VoidCallback onLogWork;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      PonosMetricTile(
        label: 'Focused today',
        value: _formatDuration(data.actualFocusedTime),
        icon: const Icon(Icons.timer_outlined),
      ),
      PonosMetricTile(
        label: 'Expected today',
        value: _formatDuration(data.expectedFocusTime),
        icon: const Icon(Icons.flag_outlined),
      ),
      PonosMetricTile(
        label: 'Rest today',
        value: _formatDuration(data.actualRestTime),
        icon: const Icon(Icons.self_improvement_outlined),
      ),
      PonosMetricTile(
        label: 'Tracked today',
        value: _formatDuration(data.actualTrackedTime),
        icon: const Icon(Icons.schedule_outlined),
      ),
      PonosMetricTile(
        label: 'Areas completed',
        value: '${data.completedFocusAreas} / ${data.targetedFocusAreas}',
        supportingText: 'Daily targets',
        icon: const Icon(Icons.track_changes_outlined),
      ),
    ];
    return PonosCard(
      key: const Key('overview-today'),
      color: AppColors.surfaceTinted,
      child: ClipRRect(
        borderRadius: AppRadius.control,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.12,
                  child: SvgPicture.asset(
                    layout == AppLayoutSize.compact
                        ? AppAssets.architecturalHeroMobile
                        : AppAssets.architecturalHeroDesktop,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PonosSectionHeader(
                  title: 'Today',
                  description: 'Your focused work at a glance',
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: layout == AppLayoutSize.compact ? 136 : 168,
                        child: metric,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    PonosButton.primary(
                      label: 'Start Focus',
                      onPressed: onStartFocus,
                    ),
                    PonosButton.secondary(
                      label: 'Log Work',
                      onPressed: onLogWork,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakGoals extends StatelessWidget {
  const _StreakGoals({
    required this.date,
    required this.workGoals,
    required this.onEditGoals,
    this.compact = false,
    this.accessibilityLayout = false,
    this.referenceTypography = false,
    this.referenceDesktopGeometry = false,
  });

  final DateTime date;
  final WorkGoals? workGoals;
  final VoidCallback onEditGoals;
  final bool compact;
  final bool accessibilityLayout;
  final bool referenceTypography;
  final bool referenceDesktopGeometry;

  @override
  Widget build(BuildContext context) {
    final dailyMinutes = workGoals?.dailyGoals
        .where((goal) => goal.weekday == date.weekday)
        .firstOrNull
        ?.targetMinutes;
    final weeklyMinutes = workGoals?.weeklyGoalMinutes;
    final values = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _GoalValue(
            label: 'Today',
            value: dailyMinutes == null
                ? '—'
                : _formatDuration(Duration(minutes: dailyMinutes)),
            compact: compact,
            referenceTypography: referenceTypography,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: _GoalValue(
            label: 'This week',
            value: weeklyMinutes == null
                ? '—'
                : _formatDuration(Duration(minutes: weeklyMinutes)),
            compact: compact,
            referenceTypography: referenceTypography,
          ),
        ),
      ],
    );
    final editAction = compact
        ? SizedBox.square(
            key: const Key('compact-edit-goals-action'),
            dimension: AppSpacing.minimumTouchTarget,
            child: PonosIconButton(
              semanticLabel: 'Edit goals',
              tooltip: 'Edit goals',
              icon: const Icon(Icons.tune),
              onPressed: onEditGoals,
            ),
          )
        : _OverviewSmallActionTypography(
            child: PonosButton.ghost(
              label: 'Edit goals',
              onPressed: onEditGoals,
            ),
          );
    if (compact && !accessibilityLayout) {
      return Row(
        key: const Key('streak-goals'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: values),
          const SizedBox(width: AppSpacing.xxs),
          editAction,
        ],
      );
    }
    if (referenceDesktopGeometry) {
      return SizedBox(
        key: const Key('streak-goals'),
        height: 120,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 3,
              child: Text(
                'Goals',
                style: _overviewSummaryValueStyle.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(left: 0, top: 25, child: values),
            Positioned(right: 0, top: 86, child: editAction),
          ],
        ),
      );
    }
    return Column(
      key: const Key('streak-goals'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Goals',
          style: referenceTypography
              ? _overviewSummaryValueStyle.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                )
              : Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xxs),
        values,
        Align(alignment: Alignment.centerRight, child: editAction),
      ],
    );
  }
}

class _GoalValue extends StatelessWidget {
  const _GoalValue({
    required this.label,
    required this.value,
    this.compact = false,
    this.referenceTypography = false,
  });

  final String label;
  final String value;
  final bool compact;
  final bool referenceTypography;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        style: compact || referenceTypography
            ? _overviewSummaryLabelStyle
            : Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
      Text(
        value,
        maxLines: 1,
        style:
            (compact || referenceTypography
                    ? const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        height: 17 / 12,
                        fontWeight: FontWeight.w600,
                      )
                    : Theme.of(context).textTheme.titleMedium)
                ?.copyWith(
                  color: AppColors.primaryDark,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
      ),
    ],
  );
}

class _OverviewSmallActionTypography extends StatelessWidget {
  const _OverviewSmallActionTypography({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          labelLarge: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 10,
            height: 14 / 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: child,
    );
  }
}

// Retained for the detailed Work Areas presentation used by the modal flow.
// ignore: unused_element
class _WorkAreasSection extends StatelessWidget {
  const _WorkAreasSection({
    required this.data,
    required this.onManageWorkAreas,
  });

  final TodayOverview data;
  final VoidCallback onManageWorkAreas;

  @override
  Widget build(BuildContext context) {
    final details = FocusAreas(
      targetDate: data.date,
      specialActivities: data.specialActivities,
      areas: data.areas.map((item) => item.focusArea).toList(),
      workedTodayByAreaId: {
        for (final item in data.areas) item.focusArea.id: item.focusedTime,
      },
      dailyTargetByAreaId: {
        for (final item in data.areas) item.focusArea.id: item.targetTime,
      },
      completedByAreaId: {
        for (final item in data.areas) item.focusArea.id: item.completed,
      },
    );
    return Column(
      key: const Key('overview-work-areas'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PonosSectionHeader(
          title: 'Work Areas',
          description: 'Today’s progress by area and special activity.',
          trailing: PonosButton.ghost(
            label: 'Manage',
            onPressed: onManageWorkAreas,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        details,
      ],
    );
  }
}

class _ReferenceExpandedStreakSection extends StatelessWidget {
  const _ReferenceExpandedStreakSection({
    required this.data,
    required this.workGoals,
    required this.onEditGoals,
  });

  final TodayOverview data;
  final WorkGoals? workGoals;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const requiredHorizontalWidth = 1028.0;
      if (constraints.maxWidth < requiredHorizontalWidth) {
        return _CompactStreakSection(
          data: data,
          workGoals: workGoals,
          onEditGoals: onEditGoals,
        );
      }
      return _CompactCard(
        key: const Key('overview-streak'),
        color: _streakSurface,
        borderColor: _streakBorder,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 3,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Streak consistency',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Daily and weekly momentum at a glance.',
                          style: _overviewSummaryValueStyle.copyWith(
                            fontSize: 11,
                            height: 15 / 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _ReferenceStreakValue(
                label: 'Daily streak',
                value:
                    '${data.streak.currentDailyStreak} '
                    '${data.streak.currentDailyStreak == 1 ? 'day' : 'days'}',
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _ReferenceStreakValue(
                label: 'Weekly streak',
                value:
                    '${data.streak.currentWeeklyStreak} '
                    '${data.streak.currentWeeklyStreak == 1 ? 'week' : 'weeks'}',
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent 7 days',
                      style: _overviewSummaryLabelStyle.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 21),
                    KeyedSubtree(
                      key: const Key('desktop-recent-days-group'),
                      child: _RecentDayIndicators(
                        days: data.streak.recentDays,
                        compact: true,
                        showLabels: true,
                        desktopReferenceSpacing: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 194,
              child: _StreakGoals(
                date: data.date,
                workGoals: workGoals,
                onEditGoals: onEditGoals,
                referenceTypography: true,
                referenceDesktopGeometry: true,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReferenceStreakValue extends StatelessWidget {
  const _ReferenceStreakValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 123,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _overviewSummaryLabelStyle.copyWith(fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 24,
            height: 30 / 24,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

// Retained for the detailed Streak presentation used by the detail sheet.
// ignore: unused_element
class _StreakSection extends StatelessWidget {
  const _StreakSection({
    required this.data,
    required this.layout,
    required this.workGoals,
    required this.onEditGoals,
  });

  final TodayOverview data;
  final AppLayoutSize layout;
  final WorkGoals? workGoals;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSpacing.xxs,
          height: AppSpacing.xxl,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.pill,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: PonosSectionHeader(
            title: 'Streak consistency',
            description: 'Daily and weekly momentum at a glance.',
          ),
        ),
      ],
    );
    return PonosCard(
      key: const Key('overview-streak'),
      color: _streakSurface,
      child: layout == AppLayoutSize.expanded
          ? Row(
              children: [
                Expanded(flex: 3, child: heading),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 9,
                  child: _StreakDetails(data: data, horizontal: true),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 3,
                  child: _StreakGoals(
                    date: data.date,
                    workGoals: workGoals,
                    onEditGoals: onEditGoals,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.md),
                _StreakDetails(data: data),
                const SizedBox(height: AppSpacing.sm),
                _StreakGoals(
                  date: data.date,
                  workGoals: workGoals,
                  onEditGoals: onEditGoals,
                ),
              ],
            ),
    );
  }
}

// Retained for the detailed statistics presentation used by later Overview work.
// ignore: unused_element
class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({required this.data});

  final TodayOverview data;

  @override
  Widget build(BuildContext context) => PonosCard(
    key: const Key('overview-statistics'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PonosSectionHeader(
          title: 'Work statistics',
          description: 'All-time tracked work.',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 136,
              child: PonosMetricTile(
                label: 'Days worked',
                value: '${data.overall.daysWorked}',
              ),
            ),
            SizedBox(
              width: 136,
              child: PonosMetricTile(
                label: 'Focused time',
                value: _formatDuration(data.overall.focusedTime),
              ),
            ),
            SizedBox(
              width: 136,
              child: PonosMetricTile(
                label: 'Rest time',
                value: _formatDuration(data.overall.restTime),
              ),
            ),
            SizedBox(
              width: 136,
              child: PonosMetricTile(
                label: 'Tracked time',
                value: _formatDuration(data.overall.trackedTime),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This week · ${_formatDuration(data.week.focusedTime)} focused · '
          '${_formatDuration(data.week.restTime)} rest',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ],
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

String _weekdayLabel(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
