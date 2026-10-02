import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PonosDateTrigger extends StatelessWidget {
  const PonosDateTrigger({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.icon = Icons.calendar_today_outlined,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Choose date, $label',
      enabled: onPressed != null,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.minimumTouchTarget, AppSpacing.controlVisualHeight),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textSecondary.withValues(alpha: 0.55)
                : AppColors.primary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)
                ? AppColors.surfaceTinted.withValues(alpha: 0.75)
                : Colors.transparent,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: AppColors.accent, width: 2)
                : BorderSide.none,
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.control),
          ),
          textStyle: WidgetStatePropertyAll(
            Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
