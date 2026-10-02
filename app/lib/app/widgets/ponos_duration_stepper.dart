import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PonosDurationStepper extends StatelessWidget {
  const PonosDurationStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = const Duration(minutes: 5),
    this.minimum = Duration.zero,
    this.maximum,
    this.semanticLabel = 'Duration',
  });

  final Duration value;
  final ValueChanged<Duration>? onChanged;
  final Duration step;
  final Duration minimum;
  final Duration? maximum;
  final String semanticLabel;

  bool get _canDecrease => onChanged != null && value - step >= minimum;
  bool get _canIncrease =>
      onChanged != null && (maximum == null || value + step <= maximum!);

  @override
  Widget build(BuildContext context) {
    final formatted = formatDuration(value);
    return Semantics(
      label: semanticLabel,
      value: formatted,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove,
              semanticLabel:
                  'Decrease $semanticLabel by ${formatDuration(step)}',
              onPressed: _canDecrease ? () => onChanged!(value - step) : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  formatted,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              semanticLabel:
                  'Increase $semanticLabel by ${formatDuration(step)}',
              onPressed: _canIncrease ? () => onChanged!(value + step) : null,
            ),
          ],
        ),
      ),
    );
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: semanticLabel,
    icon: Icon(icon, size: 18),
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.square(AppSpacing.controlVisualHeight),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.textSecondary.withValues(alpha: 0.4)
            : AppColors.primary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)
            ? AppColors.surfaceTinted
            : Colors.transparent,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? const BorderSide(color: AppColors.accent, width: 2)
            : BorderSide.none,
      ),
      shape: const WidgetStatePropertyAll(CircleBorder()),
    ),
  );
}
