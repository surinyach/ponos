import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
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
  late FocusAreaFormData _current;
  bool _saved = false;
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(widget.today ?? DateTime.now());
    _initial = widget.area == null
        ? FocusAreaFormData.empty()
        : FocusAreaFormData.fromArea(widget.area!, today);
    _current = _initial;
  }

  bool get _dirty => !_saved && _current != _initial;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusAreasProvider);
    final saving = state.status == FocusAreasStatus.saving;
    return PopScope(
      canPop: !_dirty || saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || saving) return;
        if (await _confirmDiscard() && context.mounted) {
          _saved = true;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.area == null ? 'New Focus Area' : 'Edit Focus Area',
          ),
        ),
        body: state.status == FocusAreasStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : FocusAreaForm(
                initialData: _initial,
                submitLabel: widget.area == null
                    ? 'Create area'
                    : 'Save changes',
                isSaving: saving,
                error: _attemptedSave && state.status == FocusAreasStatus.error
                    ? _errorMessage(state.error)
                    : null,
                onChanged: (value) => setState(() => _current = value),
                onSubmit: _submit,
              ),
      ),
    );
  }

  Future<void> _submit(FocusAreaFormData data) async {
    if (widget.area != null && data == _initial) {
      _saved = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() => _attemptedSave = true);
    final controller = ref.read(focusAreasProvider.notifier);
    final today = dateOnly(widget.today ?? DateTime.now());
    final success = widget.area == null
        ? await controller.create(data.toCreateInput(today))
        : await controller.update(
            widget.area!.id,
            data.toUpdateInput(widget.area!, _initial, today),
          );
    if (!mounted || !success) return;
    _saved = true;
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
    this.isSaving = false,
    this.error,
    super.key,
  });

  final FocusAreaFormData initialData;
  final String submitLabel;
  final bool isSaving;
  final String? error;
  final ValueChanged<FocusAreaFormData> onChanged;
  final ValueChanged<FocusAreaFormData> onSubmit;

  @override
  State<FocusAreaForm> createState() => _FocusAreaFormState();
}

class _FocusAreaFormState extends State<FocusAreaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _priority;
  late final List<TextEditingController> _minutes;
  late List<bool> _enabled;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final value = widget.initialData;
    _name = TextEditingController(text: value.name);
    _description = TextEditingController(text: value.description ?? '');
    _priority = TextEditingController(text: value.priority.toString());
    _minutes = value.targets
        .map((target) => TextEditingController(text: target.minutes.toString()))
        .toList();
    _enabled = value.targets.map((target) => target.enabled).toList();
    _endDate = value.targetEndDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _priority.dispose();
    for (final controller in _minutes) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      final padding = constraints.maxWidth < 600
          ? const EdgeInsets.all(AppSpacing.md)
          : AppSpacing.pagePadding;
      final contentWidth = (constraints.maxWidth - padding.horizontal)
          .clamp(0.0, 1040.0)
          .toDouble();
      final sections = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _details()),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _targets()),
              ],
            )
          : Column(
              children: [
                _details(),
                const SizedBox(height: AppSpacing.md),
                _targets(),
              ],
            );

      return Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: padding,
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.error != null) ...[
                    _ErrorNotice(message: widget.error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (widget.isSaving) ...[
                    const LinearProgressIndicator(
                      key: Key('focus-area-form-saving'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AbsorbPointer(absorbing: widget.isSaving, child: sections),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const Key('focus-area-submit'),
                      onPressed: widget.isSaving ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: Text(
                        widget.isSaving ? 'Saving...' : widget.submitLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _details() => _FormCard(
    title: 'Details',
    subtitle: 'Define the commitment and its priority.',
    child: Column(
      children: [
        TextFormField(
          key: const Key('focus-area-name'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name *'),
          maxLength: 100,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a name' : null,
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const Key('focus-area-description'),
          controller: _description,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const Key('focus-area-priority'),
          controller: _priority,
          decoration: const InputDecoration(labelText: 'Priority *'),
          keyboardType: TextInputType.number,
          validator: (value) {
            final parsed = int.tryParse(value ?? '');
            if (parsed == null) return 'Enter a whole number';
            return parsed < 1 ? 'Priority must be at least 1' : null;
          },
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          key: const Key('focus-area-end-date'),
          borderRadius: AppRadius.control,
          onTap: _pickEndDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Target end date',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _endDate == null ? 'No end date' : _formatDate(_endDate!),
            ),
          ),
        ),
        if (_endDate != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _endDate = null);
                _notify();
              },
              child: const Text('Clear date'),
            ),
          ),
      ],
    ),
  );

  Widget _targets() => _FormCard(
    title: 'Weekly targets',
    subtitle: 'Enable workdays and set expected focused minutes.',
    child: FormField<bool>(
      validator: (_) =>
          _enabled.any((value) => value) ? null : 'Enable at least one weekday',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _weekdays.length; index++) ...[
            Row(
              children: [
                Switch(
                  key: Key('target-enabled-${index + 1}'),
                  value: _enabled[index],
                  onChanged: (value) {
                    setState(() => _enabled[index] = value);
                    field.didChange(value);
                    _notify();
                  },
                ),
                Expanded(child: Text(_weekdays[index])),
                SizedBox(
                  width: 112,
                  child: TextFormField(
                    key: Key('target-minutes-${index + 1}'),
                    controller: _minutes[index],
                    enabled: _enabled[index],
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!_enabled[index]) return null;
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null) return 'Whole number';
                      return parsed < 0 ? 'Min. 0' : null;
                    },
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
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
    final now = dateOnly(DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (value == null) return;
    setState(() => _endDate = dateOnly(value));
    _notify();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_data());
    }
  }

  void _notify() => widget.onChanged(_data());

  FocusAreaFormData _data() => FocusAreaFormData(
    name: _name.text,
    description: _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    priority: int.tryParse(_priority.text) ?? 0,
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

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('focus-area-form-error'),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
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

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'The Focus Area could not be saved.',
};
