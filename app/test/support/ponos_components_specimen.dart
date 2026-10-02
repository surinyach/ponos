import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_breakpoints.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_widgets.dart';

class PonosComponentsSpecimenApp extends StatelessWidget {
  const PonosComponentsSpecimenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const PonosComponentsSpecimen(),
  );
}

class PonosComponentsSpecimen extends StatelessWidget {
  const PonosComponentsSpecimen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.layoutFor(constraints.maxWidth);
        final backgroundAsset = layout == AppLayoutSize.compact
            ? AppAssets.appCanvasMobile
            : AppAssets.appCanvasDesktop;
        final columns = switch (layout) {
          AppLayoutSize.compact => 1,
          AppLayoutSize.medium => 2,
          AppLayoutSize.expanded => 3,
        };
        return PonosPageScaffold(
          safeArea: false,
          background: SvgPicture.asset(backgroundAsset, fit: BoxFit.cover),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PonosSectionHeader(
                  title: 'Shared components',
                  description: 'Adaptive foundations for Ponos screens.',
                  trailing: PonosButton.primary(
                    label: 'Page action',
                    onPressed: _noop,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const PonosSectionHeader(title: 'Cards and metrics'),
                const SizedBox(height: AppSpacing.sm),
                _ResponsiveGrid(
                  columns: columns,
                  children: const [
                    PonosCard(
                      child: PonosMetricTile(
                        label: 'Focused time',
                        value: '6h 30m',
                        supportingText: 'Across all work areas',
                        icon: Icon(Icons.timer_outlined),
                      ),
                    ),
                    PonosCard(
                      child: PonosMetricTile(
                        label: 'Completed areas',
                        value: '3 / 5',
                        supportingText: 'Daily targets reached',
                        icon: Icon(Icons.check_circle_outline),
                      ),
                    ),
                    PonosCard(
                      padding: PonosCardPadding.compact,
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          WorkAreaBadge(type: WorkAreaType.focusArea),
                          WorkAreaBadge(type: WorkAreaType.specialActivity),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const PonosSectionHeader(title: 'Application states'),
                const SizedBox(height: AppSpacing.sm),
                _ResponsiveGrid(
                  columns: columns,
                  children: const [
                    PonosCard(
                      child: PonosStatePanel.loading(
                        description: 'Preparing your workspace.',
                      ),
                    ),
                    PonosCard(
                      child: PonosStatePanel.empty(
                        title: 'Nothing here yet',
                        description: 'Add an item when you are ready.',
                        illustrationAsset: AppAssets.emptyFocusAreas,
                        actionLabel: 'Add item',
                        onAction: _noop,
                      ),
                    ),
                    PonosCard(
                      child: PonosStatePanel.error(
                        title: 'Unable to load',
                        description: 'Check the connection and try again.',
                        actionLabel: 'Try again',
                        onAction: _noop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

void _noop() {}
