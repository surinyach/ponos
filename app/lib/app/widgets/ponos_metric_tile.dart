import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class PonosMetricTile extends StatelessWidget {
  const PonosMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.supportingText,
    this.icon,
  });

  final String label;
  final String value;
  final String? supportingText;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      value: value,
      hint: supportingText,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: const IconThemeData(
                      color: AppColors.primary,
                      size: 18,
                    ),
                    child: icon!,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.primaryDark,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (supportingText != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                supportingText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
