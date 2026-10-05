import 'package:flutter/foundation.dart';
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
        final compact =
            _usesMobileNavigation(context) &&
            constraints.maxWidth < AppBreakpoints.medium;
        final expanded = AppBreakpoints.usesExpandedSidebar(
          constraints.maxWidth,
        );
        final content = _DestinationStack(
          selectedDestination: widget.selectedDestination,
          mountedDestinations: _mountedDestinations,
        );

        return Scaffold(
          appBar: compact ? widget.appBar : null,
          body: compact
              ? content
              : Row(
                  children: [
                    SizedBox(
                      width: expanded ? 200 : 72,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: _NavigationInteractionTheme(
                          child: _RailInteractionTheme(
                            child: NavigationRailTheme(
                              data: _railTheme(context),
                              child: NavigationRail(
                                extended: expanded,
                                selectedIndex: widget.selectedDestination.index,
                                onDestinationSelected: _selectIndex,
                                minWidth: expanded ? 56 : 72,
                                minExtendedWidth: 200,
                                labelType: NavigationRailLabelType.none,
                                leading: expanded
                                    ? const _ExpandedRailBrand()
                                    : const _CompactRailBrand(),
                                destinations: [
                                  for (final destination
                                      in PonosDestination.values)
                                    NavigationRailDestination(
                                      icon: _NavigationIcon(
                                        key: ValueKey(
                                          'navigation-${destination.name}-default',
                                        ),
                                        icon: destination.icon,
                                        selected: false,
                                      ),
                                      selectedIcon: _NavigationIcon(
                                        key: ValueKey(
                                          'navigation-${destination.name}-selected',
                                        ),
                                        icon: destination.selectedIcon,
                                        selected: true,
                                      ),
                                      label: Padding(
                                        padding: EdgeInsets.only(
                                          left: expanded ? 16 : 0,
                                        ),
                                        child: Text(destination.label),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                        height: 72,
                        selectedIndex: widget.selectedDestination.index,
                        onDestinationSelected: _selectIndex,
                        destinations: [
                          for (final destination in PonosDestination.values)
                            NavigationDestination(
                              icon: _NavigationIcon(
                                key: ValueKey(
                                  'navigation-${destination.name}-default',
                                ),
                                icon: destination.icon,
                                selected: false,
                                iconSize:
                                    destination == PonosDestination.workAreas
                                    ? 18
                                    : null,
                              ),
                              selectedIcon: _NavigationIcon(
                                key: ValueKey(
                                  'navigation-${destination.name}-selected',
                                ),
                                icon: destination.selectedIcon,
                                selected: true,
                                iconSize:
                                    destination == PonosDestination.workAreas
                                    ? 18
                                    : null,
                              ),
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

  bool _usesMobileNavigation(BuildContext context) =>
      !kIsWeb &&
      (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS);

  NavigationBarThemeData _barTheme(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return NavigationBarThemeData(
      backgroundColor: AppColors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.control,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          fontSize: 10,
          height: 14 / 10,
          letterSpacing: 0,
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      labelPadding: EdgeInsets.zero,
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
      backgroundColor: const Color(0xFFFBFCFE),
      elevation: 0,
      groupAlignment: -1.0,
      useIndicator: false,
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
        fontSize: 13,
        height: 18 / 13,
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        fontSize: 13,
        height: 18 / 13,
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

class _RailInteractionTheme extends StatelessWidget {
  const _RailInteractionTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: Colors.transparent),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

class _NavigationIcon extends StatefulWidget {
  const _NavigationIcon({
    required this.icon,
    required this.selected,
    this.iconSize,
    super.key,
  });

  final IconData icon;
  final bool selected;
  final double? iconSize;

  @override
  State<_NavigationIcon> createState() => _NavigationIconState();
}

class _NavigationIconState extends State<_NavigationIcon> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus;
    final background = _pressed
        ? AppColors.primary.withValues(alpha: 0.12)
        : focused
        ? AppColors.accent.withValues(alpha: 0.20)
        : _hovered
        ? Color.alphaBlend(
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.surfaceTinted,
          )
        : widget.selected
        ? AppColors.surfaceTinted
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: SizedBox.square(
          dimension: AppSpacing.minimumTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: AppSpacing.minimumTouchTarget,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadius.control,
                border: focused
                    ? Border.all(color: AppColors.accent, width: 2)
                    : null,
              ),
              child: Icon(widget.icon, size: widget.iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedRailBrand extends StatelessWidget {
  const _ExpandedRailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('ponos-expanded-rail-brand'),
      padding: const EdgeInsets.only(top: 10, bottom: AppSpacing.xs),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 164,
          height: 40,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: SvgPicture.asset(
                  AppAssets.ponosEmblemFull,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Ponos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  height: 24 / 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRailBrand extends StatelessWidget {
  const _CompactRailBrand();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('ponos-compact-rail-brand'),
    padding: const EdgeInsets.only(top: 10, bottom: AppSpacing.xs),
    child: SizedBox.square(
      dimension: 42,
      child: SvgPicture.asset(
        AppAssets.ponosEmblemCompact,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
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
