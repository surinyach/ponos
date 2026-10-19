import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/widgets/ponos_button.dart';
import '../../../app/widgets/ponos_page_scaffold.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_timer/presentation/state/focus_timer_controller.dart';
import '../domain/models/special_activity.dart';
import 'state/special_activities_controller.dart';

class CreateSpecialActivityPage extends ConsumerStatefulWidget {
  const CreateSpecialActivityPage({this.activity, super.key});

  final SpecialActivity? activity;

  @override
  ConsumerState<CreateSpecialActivityPage> createState() =>
      _CreateSpecialActivityPageState();
}

class _CreateSpecialActivityPageState
    extends ConsumerState<CreateSpecialActivityPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final String _initialName;
  late final String _initialDescription;
  bool _submitting = false;
  bool _saved = false;
  Object? _error;

  bool get _editing => widget.activity != null;
  bool get _dirty =>
      !_saved &&
      (_name.text != _initialName ||
          _description.text != _initialDescription);

  @override
  void initState() {
    super.initState();
    _initialName = widget.activity?.name ?? '';
    _initialDescription = widget.activity?.description ?? '';
    _name = TextEditingController(text: _initialName);
    _description = TextEditingController(text: _initialDescription);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = PonosViewportScope.sizeOf(context);
    final layout = AppBreakpoints.layoutFor(viewport.width);
    final activeSpecialActivityId = ref.watch(
      focusTimerProvider.select(
        (timer) => timer.activeTimer?.specialActivityId,
      ),
    );
    final activityIsInTimer =
        _editing && activeSpecialActivityId == widget.activity!.id;

    return PopScope(
      canPop: !_dirty && !_submitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        if (await _confirmDiscard() && context.mounted) {
          _saved = true;
          Navigator.of(context).pop();
        }
      },
      child: PonosPageScaffold(
        maxContentWidth: double.infinity,
        contentPadding: EdgeInsets.zero,
        background: SvgPicture.asset(
          layout == AppLayoutSize.compact
              ? AppAssets.appCanvasMobile
              : AppAssets.appCanvasDesktop,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final platform = Theme.of(context).platform;
            final desktopPlatform =
                kIsWeb ||
                platform == TargetPlatform.windows ||
                platform == TargetPlatform.macOS ||
                platform == TargetPlatform.linux;
            final mobile =
                !desktopPlatform && constraints.maxWidth < AppBreakpoints.medium;
            final horizontalInset = mobile
                ? AppSpacing.md
                : switch (layout) {
                    AppLayoutSize.compact => 14.0,
                    AppLayoutSize.medium => 20.0,
                    AppLayoutSize.expanded => 40.0,
                  };
            final topInset = mobile
                ? AppSpacing.lg
                : layout == AppLayoutSize.compact
                ? AppSpacing.xxs
                : AppSpacing.lg;
            final formFields = <Widget>[
              const _FieldLabel(text: 'Name *'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                key: const Key('special-activity-name'),
                controller: _name,
                enabled: !_submitting,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Conference, Workshop, Talk',
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 13,
                  ),
                  constraints: BoxConstraints(minHeight: 48),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _FieldLabel(text: 'Description (optional)'),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 110,
                child: TextFormField(
                  key: const Key('special-activity-description'),
                  controller: _description,
                  enabled: !_submitting,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Add any relevant details...',
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.all(AppSpacing.sm),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _FormError(message: _errorMessage(_error)),
              ],
              if (_submitting) ...[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(
                  key: Key('special-activity-saving'),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _FormActions(
                editing: _editing,
                submitting: _submitting,
                stacked: mobile,
                onSubmit: _submit,
                onCancel: _attemptPop,
                onDelete: activityIsInTimer
                    ? _showActiveTimerMessage
                    : _confirmDelete,
              ),
            ];

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                topInset,
                horizontalInset,
                AppSpacing.xl,
              ),
              child: mobile
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FormHeading(
                                editing: _editing,
                                mobile: true,
                                onBack: _attemptPop,
                              ),
                              const SizedBox(height: 36),
                              ...formFields,
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormHeading(
                          editing: _editing,
                          mobile: false,
                          onBack: _attemptPop,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _FormSubtitle(editing: _editing),
                                  const SizedBox(height: 14),
                                  ...formFields,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _attemptPop() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    if (await _confirmDiscard() && mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('confirm-discard-special-activity'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_editing && !_dirty) {
      _saved = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final controller = ref.read(specialActivitiesProvider.notifier);
    final description = _description.text.trim();
    final success = _editing
        ? await controller.update(
            widget.activity!.id,
            SpecialActivityUpdateInput(
              name: _name.text.trim(),
              description: OptionalValue.present(
                description.isEmpty ? null : description,
              ),
            ),
          )
        : await controller.create(
            SpecialActivityCreateInput(
              name: _name.text.trim(),
              description: description.isEmpty ? null : description,
            ),
          );
    if (!mounted) return;
    if (success) {
      _saved = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = ref.read(specialActivitiesProvider).error;
    });
  }

  void _showActiveTimerMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This Special Activity is linked to the active timer. Stop or reset it before deleting.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${widget.activity!.name}?'),
        content: const Text(
          'This is only possible if no work is linked to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-special-activity'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final success = await ref
        .read(specialActivitiesProvider.notifier)
        .delete(widget.activity!.id);
    if (!mounted) return;
    if (success) {
      _saved = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = ref.read(specialActivitiesProvider).error;
    });
  }
}

class _FormHeading extends StatelessWidget {
  const _FormHeading({
    required this.editing,
    required this.mobile,
    required this.onBack,
  });

  final bool editing;
  final bool mobile;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      key: const Key('special-activity-form-title'),
      editing ? 'Edit Special Activity' : 'Create Special Activity',
      maxLines: 1,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.primaryDark,
        fontSize: mobile ? 21 : 24,
        height: 30 / 24,
        fontWeight: FontWeight.w600,
      ),
    );
    final subtitle = _FormSubtitle(editing: editing);

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Positioned(left: -12, child: _BackButton(onPressed: onBack)),
                Padding(padding: const EdgeInsets.only(left: 36), child: title),
              ],
            ),
          ),
          subtitle,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BackButton(onPressed: onBack, alignLeft: true),
        Expanded(child: title),
      ],
    );
  }
}

class _FormSubtitle extends StatelessWidget {
  const _FormSubtitle({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) => Text(
    key: const Key('special-activity-form-subtitle'),
    editing
        ? 'Update the name or description of this activity.'
        : 'Add a punctual, non-recurring activity.',
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    maxLines: MediaQuery.textScalerOf(context).scale(14) <= 14 ? 1 : null,
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, this.alignLeft = false});

  final VoidCallback onPressed;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.minimumTouchTarget,
    child: IconButton(
      key: const Key('special-activity-back'),
      onPressed: onPressed,
      tooltip: 'Back to Special Activities',
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.arrow_back, color: AppColors.primary),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    key: ValueKey('special-activity-label-$text'),
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.editing,
    required this.submitting,
    required this.stacked,
    required this.onSubmit,
    required this.onCancel,
    required this.onDelete,
  });

  final bool editing;
  final bool submitting;
  final bool stacked;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final vertical = stacked || constraints.maxWidth < 412;
      final primary = SizedBox(
        width: vertical ? double.infinity : 200,
        child: PonosButton.primary(
          key: const Key('save-special-activity'),
          label: submitting
              ? 'Saving...'
              : editing
              ? 'Save Changes'
              : 'Create Special Activity',
          onPressed: submitting ? null : onSubmit,
          visualHeight: AppSpacing.minimumTouchTarget,
        ),
      );
      final secondary = SizedBox(
        width: vertical ? double.infinity : 200,
        child: editing
            ? PonosButton.danger(
                key: const Key('delete-special-activity'),
                label: 'Delete Activity',
                onPressed: submitting ? null : onDelete,
                visualHeight: AppSpacing.minimumTouchTarget,
                borderColor: AppColors.danger,
              )
            : PonosButton.secondary(
                key: const Key('cancel-special-activity'),
                label: 'Cancel',
                onPressed: submitting ? null : onCancel,
                visualHeight: AppSpacing.minimumTouchTarget,
                borderColor: AppColors.primary,
              ),
      );
      if (vertical) {
        return Column(
          children: [
            primary,
            const SizedBox(height: AppSpacing.xs),
            secondary,
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [primary, const SizedBox(width: AppSpacing.sm), secondary],
      );
    },
  );
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      key: const Key('special-activity-save-error'),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
    ),
  );
}

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'Unable to save Special Activity.',
};
