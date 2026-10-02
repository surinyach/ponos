import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'ponos_button.dart';

enum PonosStatePanelType { loading, empty, error }

class PonosStatePanel extends StatelessWidget {
  const PonosStatePanel({
    super.key,
    required this.type,
    required this.title,
    this.description,
    this.illustrationAsset,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together.',
       );

  const PonosStatePanel.loading({
    super.key,
    this.title = 'Loading',
    this.description,
  }) : type = PonosStatePanelType.loading,
       illustrationAsset = null,
       actionLabel = null,
       onAction = null;

  const PonosStatePanel.empty({
    super.key,
    required this.title,
    this.description,
    this.illustrationAsset,
    this.actionLabel,
    this.onAction,
  }) : type = PonosStatePanelType.empty,
       assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together.',
       );

  const PonosStatePanel.error({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) : type = PonosStatePanelType.error,
       illustrationAsset = null,
       assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together.',
       );

  final PonosStatePanelType type;
  final String title;
  final String? description;
  final String? illustrationAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: type != PonosStatePanelType.empty,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _visual(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (onAction != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PonosButton.secondary(
                    label: actionLabel!,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _visual() {
    if (type == PonosStatePanelType.loading) {
      return const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
    if (illustrationAsset != null) {
      return ExcludeSemantics(
        child: SvgPicture.asset(
          illustrationAsset!,
          width: 144,
          height: 112,
          fit: BoxFit.contain,
        ),
      );
    }
    return ExcludeSemantics(
      child: Icon(
        type == PonosStatePanelType.error
            ? Icons.error_outline
            : Icons.inbox_outlined,
        size: 40,
        color: type == PonosStatePanelType.error
            ? AppColors.error
            : AppColors.primary,
      ),
    );
  }
}
