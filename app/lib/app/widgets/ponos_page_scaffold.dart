import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class PonosPageScaffold extends StatelessWidget {
  const PonosPageScaffold({
    super.key,
    required this.child,
    this.background,
    this.backgroundColor,
    this.maxContentWidth = AppBreakpoints.expandedSidebar,
    this.appBar,
    this.safeArea = true,
    this.resizeToAvoidBottomInset = true,
    this.contentPadding,
  });

  final Widget child;
  final Widget? background;
  final Color? backgroundColor;
  final double maxContentWidth;
  final PreferredSizeWidget? appBar;
  final bool safeArea;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontalPadding = AppSpacing.screenMarginFor(width);
          final content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding:
                    contentPadding ??
                    EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: AppSpacing.lg,
                    ),
                child: child,
              ),
            ),
          );

          final layered = background == null
              ? content
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(child: background!),
                    content,
                  ],
                );
          return safeArea ? SafeArea(child: layered) : layered;
        },
      ),
    );
  }
}
