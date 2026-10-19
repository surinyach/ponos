import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_priority_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/ponos_button.dart';
import '../../../app/widgets/ponos_page_scaffold.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/focus_area.dart';
import 'focus_area_form_data.dart';
import 'state/focus_areas_controller.dart';
import 'state/focus_areas_state.dart';

class FocusAreaFormPage extends ConsumerStatefulWidget {
  const FocusAreaFormPage({this.area, this.today, super.key});

  final FocusArea? area;
  final DateTime? today;

  @override
  ConsumerState<FocusAreaFormPage> createState() => _FocusAreaFormPageState();
}

class _FocusAreaFormPageState extends ConsumerState<FocusAreaFormPage> {
  late final FocusAreaFormData _initial;
  late final DateTime _today;
  late FocusAreaFormData _current;
  bool _saved = false;
  bool _attemptedMutation = false;

  bool get _editing => widget.area != null;
  bool get _dirty => !_saved && _current != _initial;

  @override
  void initState() {
    super.initState();
    _today = dateOnly(widget.today ?? DateTime.now());
    _initial = _editing
        ? FocusAreaFormData.fromArea(widget.area!, _today)
        : FocusAreaFormData.empty();
    _current = _initial;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusAreasProvider);
    final saving = state.status == FocusAreasStatus.saving;
    final viewport = PonosViewportScope.sizeOf(context);
    final layout = AppBreakpoints.layoutFor(viewport.width);
    final platform = Theme.of(context).platform;
    final desktopPlatform =
        kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final mobile = !desktopPlatform && viewport.width < AppBreakpoints.medium;

    return PopScope(
      canPop: !_dirty || saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || saving) return;
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
            final horizontalInset = mobile
                ? AppSpacing.md
                : switch (layout) {
                    AppLayoutSize.compact => 18.0,
                    AppLayoutSize.medium => AppSpacing.lg,
                    AppLayoutSize.expanded => AppSpacing.xl,
                  };
            return SingleChildScrollView(
              key: const Key('focus-area-form-scroll-view'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                mobile
                    ? AppSpacing.xs
                    : layout == AppLayoutSize.expanded
                    ? AppSpacing.xl + AppSpacing.sm
                    : AppSpacing.lg,
                horizontalInset,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormHeading(editing: _editing, onBack: _attemptPop),
                  SizedBox(
                    height: mobile
                        ? AppSpacing.xs
                        : layout == AppLayoutSize.expanded
                        ? AppSpacing.xl + AppSpacing.sm
                        : AppSpacing.lg,
                  ),
                  if (_expiration != null) ...[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 910),
                        child: _ExpirationNotice(expiration: _expiration!),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (state.status == FocusAreasStatus.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    FocusAreaForm(
                      initialData: _initial,
                      today: _today,
                      submitLabel: _editing
                          ? 'Save Changes'
                          : 'Create Focus Area',
                      secondaryLabel: _editing
                          ? 'Archive Focus Area'
                          : 'Cancel',
                      secondaryDanger: _editing,
                      isSaving: saving,
                      error:
                          _attemptedMutation &&
                              state.status == FocusAreasStatus.error
                          ? _errorMessage(state.error)
                          : null,
                      onChanged: (value) => setState(() => _current = value),
                      onSubmit: _submit,
                      onSecondary: _editing ? _confirmArchive : _attemptPop,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _ExpirationInfo? get _expiration {
    final endDate = _current.targetEndDate;
    if (endDate == null) return null;
    final days = _today.difference(dateOnly(endDate)).inDays;
    if (days < 1) return null;
    return _ExpirationInfo(days: days, severe: days >= 15);
  }

  Future<void> _submit(FocusAreaFormData data) async {
    if (_editing && data == _initial) {
      _saved = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() => _attemptedMutation = true);
    final controller = ref.read(focusAreasProvider.notifier);
    final success = _editing
        ? await controller.update(
            widget.area!.id,
            data.toUpdateInput(widget.area!, _initial, _today),
          )
        : await controller.create(data.toCreateInput(_today));
    if (!mounted || !success) return;
    _saved = true;
    Navigator.of(context).pop();
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

  Future<void> _confirmArchive() async {
    if (ref.read(focusAreasProvider).status == FocusAreasStatus.saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${widget.area!.name}?'),
        content: const Text(
          'This area will move to Archived. Historical targets and recorded work will be preserved. You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-archive-focus-area'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _attemptedMutation = true);
    final success = await ref
        .read(focusAreasProvider.notifier)
        .archive(widget.area!.id);
    if (!mounted || !success) return;
    _saved = true;
    Navigator.of(context).pop();
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}

class FocusAreaForm extends StatefulWidget {
  const FocusAreaForm({
    required this.initialData,
    required this.submitLabel,
    required this.onChanged,
    required this.onSubmit,
    this.today,
    this.secondaryLabel = 'Cancel',
    this.secondaryDanger = false,
    this.onSecondary,
    this.isSaving = false,
    this.error,
    super.key,
  });

  final FocusAreaFormData initialData;
  final DateTime? today;
  final String submitLabel;
  final String secondaryLabel;
  final bool secondaryDanger;
  final bool isSaving;
  final String? error;
  final ValueChanged<FocusAreaFormData> onChanged;
  final ValueChanged<FocusAreaFormData> onSubmit;
  final VoidCallback? onSecondary;

  @override
  State<FocusAreaForm> createState() => _FocusAreaFormState();
}

class _FocusAreaFormState extends State<FocusAreaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final List<TextEditingController> _minutes;
  late List<bool> _enabled;
  late int _priority;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final value = widget.initialData;
    _name = TextEditingController(text: value.name);
    _description = TextEditingController(text: value.description ?? '');
    _priority = value.priority;
    _minutes = value.targets
        .map((target) => TextEditingController(text: '${target.minutes}'))
        .toList();
    _enabled = value.targets.map((target) => target.enabled).toList();
    _endDate = value.targetEndDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final controller in _minutes) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= AppBreakpoints.expanded;
      final contentWidth = constraints.maxWidth.clamp(0.0, 910.0).toDouble();
      final sections = twoColumns
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _details(minHeight: 460)),
                const SizedBox(width: 20),
                Expanded(child: _targets(minHeight: 460)),
              ],
            )
          : Column(
              children: [
                _details(compact: true),
                const SizedBox(height: AppSpacing.md),
                _targets(compact: true),
              ],
            );

      return Form(
        key: _formKey,
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.error != null) ...[
                  _ErrorNotice(message: widget.error!),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (widget.isSaving) ...[
                  const LinearProgressIndicator(
                    key: Key('focus-area-form-saving'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AbsorbPointer(absorbing: widget.isSaving, child: sections),
                const SizedBox(height: AppSpacing.lg),
                _FormActions(
                  saving: widget.isSaving,
                  submitLabel: widget.submitLabel,
                  secondaryLabel: widget.secondaryLabel,
                  secondaryDanger: widget.secondaryDanger,
                  onSubmit: _submit,
                  onSecondary: widget.onSecondary,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _details({bool compact = false, double? minHeight}) => _FormCard(
    title: 'Details',
    subtitle: 'Name, description, priority and finish date.',
    compact: compact,
    showSubtitle: !compact,
    minHeight: minHeight,
    verticalPadding: compact ? AppSpacing.xxs : AppSpacing.md,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel(text: 'Name *'),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: const Key('focus-area-name'),
          controller: _name,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'e.g. Personal project',
            counterText: '',
            isDense: true,
            constraints: BoxConstraints(minHeight: 48),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a name' : null,
          onChanged: (_) => _notify(),
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        const _FieldLabel(text: 'Description (optional)'),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: compact ? 68 : 84,
          child: TextFormField(
            key: const Key('focus-area-description'),
            controller: _description,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Add any relevant details...',
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.all(AppSpacing.sm),
            ),
            onChanged: (_) => _notify(),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        const _FieldLabel(text: 'Priority *'),
        const SizedBox(height: AppSpacing.xs),
        _PriorityPicker(
          value: _priority,
          onChanged: (value) {
            setState(() => _priority = value);
            _notify();
          },
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        const _FieldLabel(text: 'Finish date (optional)'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('focus-area-end-date'),
                borderRadius: AppRadius.control,
                onTap: _pickEndDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                    isDense: true,
                    constraints: BoxConstraints(minHeight: 48),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: Text(
                    _endDate == null ? 'No end date' : _formatDate(_endDate!),
                  ),
                ),
              ),
            ),
            if (_endDate != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              IconButton(
                key: const Key('focus-area-clear-end-date'),
                tooltip: 'Clear finish date',
                onPressed: () {
                  setState(() => _endDate = null);
                  _notify();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _targets({bool compact = false, double? minHeight}) => _FormCard(
    title: 'Weekly targets',
    subtitle: 'Enable days and set focused minutes.',
    compact: compact,
    minHeight: minHeight,
    child: FormField<bool>(
      validator: (_) =>
          _enabled.any((value) => value) ? null : 'Enable at least one weekday',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _weekdays.length; index++) ...[
            _TargetRow(
              weekday: _weekdays[index],
              index: index,
              enabled: _enabled[index],
              controller: _minutes[index],
              onEnabled: (value) {
                setState(() => _enabled[index] = value);
                field.didChange(value);
                _notify();
              },
              onChanged: _notify,
            ),
            if (index != _weekdays.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
          if (field.hasError) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              field.errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _pickEndDate() async {
    final today = dateOnly(widget.today ?? DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: _endDate ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 100, 12, 31),
    );
    if (value == null) return;
    setState(() => _endDate = dateOnly(value));
    _notify();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) widget.onSubmit(_data());
  }

  void _notify([String? _]) => widget.onChanged(_data());

  FocusAreaFormData _data() => FocusAreaFormData(
    name: _name.text,
    description: _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    priority: _priority,
    targetEndDate: _endDate,
    targets: List.generate(
      7,
      (index) => WeekdayTargetFormData(
        enabled: _enabled[index],
        minutes: int.tryParse(_minutes[index].text) ?? -1,
      ),
    ),
  );
}

class _FormHeading extends StatelessWidget {
  const _FormHeading({required this.editing, required this.onBack});

  final bool editing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox.square(
        dimension: AppSpacing.minimumTouchTarget,
        child: IconButton(
          key: const Key('focus-area-back'),
          tooltip: 'Back',
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: const Key('focus-area-form-title'),
                editing ? 'Edit Focus Area' : 'Create Focus Area',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                editing
                    ? 'Update details and weekday targets for this area.'
                    : 'Define your Focus Area and its weekday targets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.compact = false,
    this.showSubtitle = true,
    this.minHeight,
    this.verticalPadding = AppSpacing.md,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool compact;
  final bool showSubtitle;
  final double? minHeight;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight ?? 0),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: AppRadius.card,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primaryDark),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.xxs),
            child,
          ],
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final priorities = value > 5 ? [value, 1, 2, 3, 4, 5] : [1, 2, 3, 4, 5];
      final showDescriptions = constraints.maxWidth >= 390;
      return Wrap(
        key: const Key('focus-area-priority'),
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final priority in priorities)
            SizedBox(
              width: value > 5
                  ? null
                  : (constraints.maxWidth - AppSpacing.xxs * 4) / 5,
              child: _PriorityChoice(
                priority: priority,
                selected: value == priority,
                showDescription: showDescriptions,
                legacy: priority > 5,
                onTap: () => onChanged(priority),
              ),
            ),
        ],
      );
    },
  );
}

class _PriorityChoice extends StatelessWidget {
  const _PriorityChoice({
    required this.priority,
    required this.selected,
    required this.showDescription,
    required this.legacy,
    required this.onTap,
  });
  final int priority;
  final bool selected;
  final bool showDescription;
  final bool legacy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPriorityColors.forPriority(priority);
    final description = switch (priority) {
      1 => 'Highest',
      2 => 'High',
      3 => 'Elevated',
      4 => 'Moderate',
      _ => legacy ? 'Existing' : 'Low',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Priority $priority, $description',
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? colors.foreground : colors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: AppRadius.control,
        ),
        child: InkWell(
          key: Key('focus-area-priority-$priority'),
          onTap: onTap,
          borderRadius: AppRadius.control,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minimumTouchTarget,
              minHeight: AppSpacing.minimumTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'P$priority',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showDescription)
                    Text(
                      description,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foreground,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.weekday,
    required this.index,
    required this.enabled,
    required this.controller,
    required this.onEnabled,
    required this.onChanged,
  });
  final String weekday;
  final int index;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: Key('target-row-${index + 1}'),
    constraints: const BoxConstraints(minHeight: AppSpacing.minimumTouchTarget),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Switch(
          key: Key('target-enabled-${index + 1}'),
          value: enabled,
          onChanged: onEnabled,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(weekday)),
        SizedBox(
          width: 90,
          child: enabled
              ? TextFormField(
                  key: Key('target-minutes-${index + 1}'),
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null) return 'Whole number';
                    return parsed < 1 ? 'Must be at least 1 minute' : null;
                  },
                  onChanged: onChanged,
                )
              : InputDecorator(
                  key: Key('target-minutes-${index + 1}'),
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    enabled: false,
                    isDense: true,
                  ),
                  child: const Text('—'),
                ),
        ),
      ],
    ),
  );
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.saving,
    required this.submitLabel,
    required this.secondaryLabel,
    required this.secondaryDanger,
    required this.onSubmit,
    required this.onSecondary,
  });
  final bool saving;
  final String submitLabel;
  final String secondaryLabel;
  final bool secondaryDanger;
  final VoidCallback onSubmit;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 430;
      final primary = SizedBox(
        width: stacked ? double.infinity : 180,
        child: PonosButton.primary(
          key: const Key('focus-area-submit'),
          label: saving ? 'Saving...' : submitLabel,
          onPressed: saving ? null : onSubmit,
          visualHeight: AppSpacing.minimumTouchTarget,
        ),
      );
      final secondary = SizedBox(
        width: stacked ? double.infinity : 180,
        child: secondaryDanger
            ? PonosButton.danger(
                key: const Key('focus-area-secondary'),
                label: secondaryLabel,
                onPressed: saving ? null : onSecondary,
                visualHeight: AppSpacing.minimumTouchTarget,
                borderColor: AppColors.danger,
              )
            : PonosButton.secondary(
                key: const Key('focus-area-secondary'),
                label: secondaryLabel,
                onPressed: saving ? null : onSecondary,
                visualHeight: AppSpacing.minimumTouchTarget,
                borderColor: AppColors.primary,
              ),
      );
      if (stacked) {
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
        children: [
          primary,
          const SizedBox(width: AppSpacing.sm),
          secondary,
        ],
      );
    },
  );
}

class _ExpirationInfo {
  const _ExpirationInfo({required this.days, required this.severe});
  final int days;
  final bool severe;
}

class _ExpirationNotice extends StatelessWidget {
  const _ExpirationNotice({required this.expiration});
  final _ExpirationInfo expiration;

  @override
  Widget build(BuildContext context) {
    final colors = expiration.severe
        ? AppPriorityColors.p1
        : AppPriorityColors.p4;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('focus-area-expiration-warning'),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.background.withValues(alpha: 0.55),
          border: Border.all(color: colors.border),
          borderRadius: AppRadius.control,
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.foreground),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expired ${expiration.days} ${expiration.days == 1 ? 'day' : 'days'} ago',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'This Focus Area stays active until you archive it.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('focus-area-form-error'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'The Focus Area could not be saved.',
};
