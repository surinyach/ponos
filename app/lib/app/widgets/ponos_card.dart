import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum PonosCardPadding { standard, compact }

class PonosCard extends StatelessWidget {
  const PonosCard({
    super.key,
    required this.child,
    this.padding = PonosCardPadding.standard,
    this.color,
  });

  final Widget child;
  final PonosCardPadding padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final inset = switch (padding) {
      PonosCardPadding.standard => AppSpacing.cardPaddingExpanded,
      PonosCardPadding.compact => AppSpacing.cardPaddingCompact,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.card,
      ),
      child: Padding(padding: EdgeInsets.all(inset), child: child),
    );
  }
}
