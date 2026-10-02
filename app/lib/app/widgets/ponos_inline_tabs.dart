import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class PonosInlineTabs extends StatelessWidget {
  const PonosInlineTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
  });
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty);
    assert(selectedIndex >= 0 && selectedIndex < tabs.length);
    return Semantics(
      label: semanticLabel,
      explicitChildNodes: true,
      child: SizedBox(
        height: AppSpacing.minimumTouchTarget,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.lg),
                _InlineTab(
                  label: tabs[index],
                  selected: index == selectedIndex,
                  onPressed: onSelected == null
                      ? null
                      : () => onSelected!(index),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTab extends StatelessWidget {
  const _InlineTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton(
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
              EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textSecondary.withValues(alpha: 0.55);
              }
              return selected ? AppColors.primary : AppColors.textSecondary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? AppColors.surfaceTinted.withValues(alpha: 0.65)
                  : Colors.transparent,
            ),
            overlayColor: WidgetStatePropertyAll(
              AppColors.surfaceTinted.withValues(alpha: 0.9),
            ),
            shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? const BorderSide(color: AppColors.accent, width: 2)
                  : BorderSide.none,
            ),
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              const SizedBox(height: AppSpacing.xxs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2.4,
                width: selected ? 28 : 0,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
