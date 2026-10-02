import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PonosPickerChip extends StatelessWidget {
  const PonosPickerChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.selected = false,
    this.leading,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(
                AppSpacing.minimumTouchTarget,
                AppSpacing.controlVisualHeight,
              ),
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? AppColors.textSecondary.withValues(alpha: 0.55)
                  : selected
                  ? AppColors.primaryDark
                  : AppColors.primary,
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (selected) {
                return AppColors.surfaceTinted;
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return AppColors.surfaceTinted.withValues(alpha: 0.65);
              }
              return AppColors.white;
            }),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? AppColors.accent
                    : selected
                    ? AppColors.primary
                    : AppColors.border,
                width: states.contains(WidgetState.focused) ? 2 : 1,
              ),
            ),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: AppTypography.selectorLabelSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                selected ? Icons.check : Icons.keyboard_arrow_down,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
