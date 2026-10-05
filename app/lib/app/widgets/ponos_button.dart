import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum PonosButtonVariant { primary, secondary, ghost, danger }

class PonosButton extends StatelessWidget {
  const PonosButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PonosButtonVariant.primary,
    this.icon,
    this.autofocus = false,
    this.visualHeight,
    this.borderColor,
  });
  const PonosButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.visualHeight,
    this.borderColor,
  }) : variant = PonosButtonVariant.primary;
  const PonosButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.visualHeight,
    this.borderColor,
  }) : variant = PonosButtonVariant.secondary;
  const PonosButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.visualHeight,
    this.borderColor,
  }) : variant = PonosButtonVariant.ghost;
  const PonosButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.visualHeight,
    this.borderColor,
  }) : variant = PonosButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final PonosButtonVariant variant;
  final Widget? icon;
  final bool autofocus;
  final double? visualHeight;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon!,
              const SizedBox(width: AppSpacing.xs),
              Text(label),
            ],
          );
    final style = _style(
      context,
      variant,
      visualHeight: visualHeight,
      borderColor: borderColor,
    );
    return switch (variant) {
      PonosButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      _ => TextButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
    };
  }

  static ButtonStyle _style(
    BuildContext context,
    PonosButtonVariant variant, {
    double? visualHeight,
    Color? borderColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    final secondary = variant == PonosButtonVariant.secondary;
    final foreground = variant == PonosButtonVariant.danger
        ? colors.error
        : variant == PonosButtonVariant.primary
        ? colors.onPrimary
        : colors.primary;
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          AppSpacing.minimumTouchTarget,
          visualHeight ?? AppSpacing.controlVisualHeight,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: WidgetStatePropertyAll(
        Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.textSecondary.withValues(alpha: 0.55)
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == PonosButtonVariant.primary
              ? AppColors.border
              : Colors.transparent;
        }
        if (variant == PonosButtonVariant.primary) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryDark;
          }
          if (states.contains(WidgetState.hovered)) {
            return Color.alphaBlend(
              AppColors.white.withValues(alpha: 0.08),
              AppColors.primary,
            );
          }
          return AppColors.primary;
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.surfaceTinted;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return AppColors.surfaceTinted.withValues(alpha: 0.75);
        }
        return secondary ? AppColors.white : Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.accent, width: 2);
        }
        return secondary
            ? BorderSide(color: borderColor ?? AppColors.border)
            : BorderSide.none;
      }),
    );
  }
}

class PonosIconButton extends StatelessWidget {
  const PonosIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.autofocus = false,
  });
  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      autofocus: autofocus,
      tooltip: tooltip ?? semanticLabel,
      icon: Semantics(label: semanticLabel, child: icon),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(AppSpacing.controlVisualHeight),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.textSecondary.withValues(alpha: 0.55)
              : AppColors.primary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.surfaceTinted;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return AppColors.surfaceTinted.withValues(alpha: 0.75);
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: AppColors.accent, width: 2)
              : BorderSide.none,
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
    );
  }
}
