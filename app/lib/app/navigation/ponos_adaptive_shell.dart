import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_assets.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'ponos_destination.dart';

typedef PonosDestinationBuilder = Widget Function(PonosDestination destination);

class PonosAdaptiveShell extends StatefulWidget {
  const PonosAdaptiveShell({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
    required this.destinationBuilder,
    this.appBar,
  });

  final PonosDestination selectedDestination;
  final ValueChanged<PonosDestination> onDestinationSelected;
  final PonosDestinationBuilder destinationBuilder;
  final PreferredSizeWidget? appBar;

  @override
  State<PonosAdaptiveShell> createState() => _PonosAdaptiveShellState();
}

class _PonosAdaptiveShellState extends State<PonosAdaptiveShell> {
  final Map<PonosDestination, Widget> _mountedDestinations = {};

  @override
  Widget build(BuildContext context) {
    _mountedDestinations.putIfAbsent(
      widget.selectedDestination,
      () => widget.destinationBuilder(widget.selectedDestination),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.medium;
        final expanded = AppBreakpoints.usesExpandedSidebar(
          constraints.maxWidth,
        );
        final content = _DestinationStack(
          selectedDestination: widget.selectedDestination,
          mountedDestinations: _mountedDestinations,
        );

        return Scaffold(
          appBar: widget.appBar,
          body: compact
              ? content
              : Row(
                  children: [
                    _NavigationInteractionTheme(
                      child: NavigationRailTheme(
                        data: _railTheme(context),
                        child: NavigationRail(
                          extended: expanded,
                          selectedIndex: widget.selectedDestination.index,
                          onDestinationSelected: _selectIndex,
                          labelType: expanded
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          leading: expanded ? const _ExpandedRailBrand() : null,
                          destinations: [
                            for (final destination in PonosDestination.values)
                              NavigationRailDestination(
                                icon: _NavigationIcon(icon: destination.icon),
                                selectedIcon: _NavigationIcon(
                                  icon: destination.selectedIcon,
                                ),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                ),
          bottomNavigationBar: compact
              ? DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: _NavigationInteractionTheme(
                    child: NavigationBarTheme(
                      data: _barTheme(context),
                      child: NavigationBar(
                        selectedIndex: widget.selectedDestination.index,
                        onDestinationSelected: _selectIndex,
                        destinations: [
                          for (final destination in PonosDestination.values)
                            NavigationDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: destination.label,
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  void _selectIndex(int index) {
    widget.onDestinationSelected(PonosDestination.values[index]);
  }

  NavigationBarThemeData _barTheme(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return NavigationBarThemeData(
      backgroundColor: AppColors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.surfaceTinted,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.control,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          size: 24,
        );
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return AppColors.accent.withValues(alpha: 0.20);
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.surfaceTinted;
        }
        return Colors.transparent;
      }),
    );
  }

  NavigationRailThemeData _railTheme(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return NavigationRailThemeData(
      backgroundColor: AppColors.white,
      elevation: 0,
      groupAlignment: -0.85,
      useIndicator: true,
      indicatorColor: AppColors.surfaceTinted,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.control,
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 24,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _NavigationInteractionTheme extends StatelessWidget {
  const _NavigationInteractionTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        focusColor: AppColors.accent.withValues(alpha: 0.20),
        hoverColor: AppColors.surfaceTinted,
        splashColor: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: child,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.minimumTouchTarget,
    child: Center(child: Icon(icon)),
  );
}

class _ExpandedRailBrand extends StatelessWidget {
  const _ExpandedRailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('ponos-expanded-rail-brand'),
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: SizedBox.square(
        dimension: AppSpacing.xxxl,
        child: SvgPicture.asset(
          AppAssets.ponosEmblemFull,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _DestinationStack extends StatelessWidget {
  const _DestinationStack({
    required this.selectedDestination,
    required this.mountedDestinations,
  });

  final PonosDestination selectedDestination;
  final Map<PonosDestination, Widget> mountedDestinations;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final entry in mountedDestinations.entries)
          Offstage(
            key: ValueKey(entry.key),
            offstage: entry.key != selectedDestination,
            child: ExcludeFocus(
              excluding: entry.key != selectedDestination,
              child: TickerMode(
                enabled: entry.key == selectedDestination,
                child: entry.value,
              ),
            ),
          ),
      ],
    );
  }
}
