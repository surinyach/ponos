import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/providers/work_goals_providers.dart';
import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../work_goals/presentation/work_goals_page.dart';
import 'overview_responsive_layout.dart';
import 'state/today_overview_provider.dart';

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({
    required this.onStartFocus,
    required this.onManageWorkAreas,
    required this.onLogWork,
    super.key,
  });

  final VoidCallback onStartFocus;
  final VoidCallback onManageWorkAreas;
  final VoidCallback onLogWork;

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  late DateTime _observedLocalDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedLocalDate = _localDate(_now());
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshAfterDateChange();
    _scheduleMidnightRefresh();
  }

  DateTime _now() => ref.read(overviewClockProvider)().toLocal();

  void _refreshAfterDateChange() {
    final date = _localDate(_now());
    if (date == _observedLocalDate) return;
    _observedLocalDate = date;
    ref.invalidate(currentDateTimeProvider);
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = _now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      _refreshAfterDateChange();
      _scheduleMidnightRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(todayOverviewProvider);
    final workGoals = ref.watch(workGoalsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The adaptive shell exposes the complete application viewport even
        // though navigation consumes part of the horizontal content area.
        final layout = AppBreakpoints.layoutFor(
          PonosViewportScope.sizeOf(context).width,
        );
        final platform = Theme.of(context).platform;
        final desktop =
            kIsWeb ||
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.linux;
        final normalPadding = _overviewPadding(layout, false);
        final availableContentWidth =
            constraints.maxWidth - normalPadding.horizontal;
        final availableContentHeight =
            constraints.maxHeight - normalPadding.vertical;
        final expandedAccessibilityFallback =
            layout == AppLayoutSize.expanded &&
            MediaQuery.textScalerOf(
                  context,
                ).scale(OverviewResponsiveLayout.minimumNormalHeight(layout)) >
                availableContentHeight;
        final compactDesktop =
            desktop &&
            (layout == AppLayoutSize.compact ||
                availableContentWidth <
                    OverviewResponsiveLayout.minimumNormalWidth(layout) ||
                availableContentHeight <
                    OverviewResponsiveLayout.minimumNormalHeight(layout) ||
                expandedAccessibilityFallback);
        Widget dashboard() => OverviewResponsiveLayout(
          data: overview.value!,
          workGoals: workGoals.hasError ? null : workGoals.value,
          workGoalsUnavailable: workGoals.hasError,
          onRetryWorkGoals: () => ref.invalidate(workGoalsProvider),
          layout: layout,
          onStartFocus: widget.onStartFocus,
          onManageWorkAreas: widget.onManageWorkAreas,
          onLogWork: widget.onLogWork,
          compactDesktop: compactDesktop,
          onWorkGoals: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WorkGoalsPage()),
          ),
        );

        final Widget content;
        if (overview.hasValue) {
          content = Stack(
            clipBehavior: Clip.none,
            children: [
              dashboard(),
              if (overview.isRefreshing)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _OverviewRefreshIndicator(),
                ),
              if (overview.hasError)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _OverviewRefreshErrorNotice(
                    onRetry: () => ref.invalidate(todayOverviewProvider),
                  ),
                ),
            ],
          );
        } else if (overview.isLoading) {
          content = const SingleChildScrollView(
            key: Key('overview-initial-loading'),
            primary: false,
            child: PonosStatePanel.loading(title: 'Loading Overview'),
          );
        } else {
          content = SingleChildScrollView(
            key: const Key('overview-initial-error'),
            primary: false,
            child: PonosStatePanel.error(
              title: 'Unable to load today’s overview',
              description: 'Check the connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(todayOverviewProvider),
            ),
          );
        }
        return PonosPageScaffold(
          background: SvgPicture.asset(
            layout == AppLayoutSize.compact
                ? AppAssets.appCanvasMobile
                : AppAssets.appCanvasDesktop,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          maxContentWidth: double.infinity,
          contentPadding: _overviewPadding(layout, compactDesktop),
          child: content,
        );
      },
    );
  }
}

DateTime _localDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _OverviewRefreshIndicator extends StatelessWidget {
  const _OverviewRefreshIndicator();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Refreshing Overview',
    child: const SizedBox.square(
      key: Key('overview-refresh-indicator'),
      dimension: 24,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxs),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _OverviewRefreshErrorNotice extends StatelessWidget {
  const _OverviewRefreshErrorNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Unable to refresh Overview',
    child: Material(
      key: const Key('overview-refresh-error'),
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.control,
        side: BorderSide(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Unable to refresh',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            PonosButton.ghost(
              key: const Key('retry-overview-refresh'),
              label: 'Retry',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    ),
  );
}

EdgeInsets _overviewPadding(AppLayoutSize layout, bool compactDesktop) {
  if (compactDesktop) {
    return const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 18);
  }
  return switch (layout) {
    AppLayoutSize.compact => const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: AppSpacing.sm,
    ),
    AppLayoutSize.medium => const EdgeInsets.all(AppSpacing.lg),
    AppLayoutSize.expanded => const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: AppSpacing.lg,
    ),
  };
}
