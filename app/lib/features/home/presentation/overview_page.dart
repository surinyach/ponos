import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/providers/work_goals_providers.dart';
import '../../../app/widgets/ponos_widgets.dart';
import '../../work_goals/presentation/work_goals_page.dart';
import 'overview_responsive_layout.dart';
import 'state/today_overview_provider.dart';

class OverviewPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(todayOverviewProvider);
    final workGoals = ref.watch(workGoalsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.layoutFor(constraints.maxWidth);
        final platform = Theme.of(context).platform;
        final desktop =
            kIsWeb ||
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.linux;
        final availableContentHeight =
            constraints.maxHeight - (AppSpacing.lg * 2);
        final compactDesktop =
            (desktop && layout == AppLayoutSize.compact) ||
            (layout != AppLayoutSize.compact &&
                availableContentHeight <
                    OverviewResponsiveLayout.minimumNormalHeight(layout));
        final content = overview.when(
          loading: () =>
              const PonosStatePanel.loading(title: 'Loading Overview'),
          error: (error, _) => PonosStatePanel.error(
            title: 'Unable to load today’s overview',
            description: 'Check the backend connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(todayOverviewProvider),
          ),
          data: (data) => OverviewResponsiveLayout(
            data: data,
            workGoals: workGoals.value,
            layout: layout,
            onStartFocus: onStartFocus,
            onManageWorkAreas: onManageWorkAreas,
            onLogWork: onLogWork,
            compactDesktop: compactDesktop,
            onWorkGoals: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WorkGoalsPage()),
            ),
          ),
        );
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
