import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_areas/presentation/state/focus_areas_controller.dart';
import '../../focus_areas/presentation/state/focus_areas_state.dart';
import '../domain/models/manual_work_entry.dart';
import 'state/manual_work_entries_controller.dart';
import 'state/manual_work_entries_state.dart';
import 'state/special_activities_controller.dart';
import 'state/special_activities_state.dart';

class LogWorkFormPage extends ConsumerStatefulWidget {
  const LogWorkFormPage({this.entry, super.key});
  final ManualWorkEntry? entry;

  @override
  ConsumerState<LogWorkFormPage> createState() => _LogWorkFormPageState();
}

class _LogWorkFormPageState extends ConsumerState<LogWorkFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _focusMinutes;
  late final TextEditingController _focusSeconds;
  late final TextEditingController _restMinutes;
  late final TextEditingController _restSeconds;
  late DateTime _date;
  String? _subject;
  String? _validationError;
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = entry?.workDate ?? DateTime.now();
    _subject = entry?.focusAreaId != null
        ? 'focus:${entry!.focusAreaId}'
        : entry?.specialActivityId != null
        ? 'special:${entry!.specialActivityId}'
        : null;
    _focusMinutes = TextEditingController(
      text: (entry?.focusedTime.inMinutes ?? 0).toString(),
    );
    _focusSeconds = TextEditingController(
      text: (entry?.focusedTime.inSeconds.remainder(60) ?? 0).toString(),
    );
    _restMinutes = TextEditingController(
      text: (entry?.restTime.inMinutes ?? 0).toString(),
    );
    _restSeconds = TextEditingController(
      text: (entry?.restTime.inSeconds.remainder(60) ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _focusMinutes.dispose();
    _focusSeconds.dispose();
    _restMinutes.dispose();
    _restSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(manualWorkEntriesProvider);
    final areas = ref.watch(focusAreasProvider);
    final activities = ref.watch(specialActivitiesProvider);
    final saving = entries.status == ManualWorkEntriesStatus.saving;
    final subjects = <String, String>{
      for (final area in areas.areas) 'focus:${area.id}': area.name,
      for (final activity in activities.active)
        'special:${activity.id}': activity.name,
    };
    if (_subject != null && !subjects.containsKey(_subject)) {
      final archived = activities.archived.where(
        (activity) => 'special:${activity.id}' == _subject,
      );
      subjects[_subject!] = archived.isNotEmpty
          ? '${archived.first.name} (archived)'
          : 'Archived Focus Area #${widget.entry?.focusAreaId ?? '?'}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Log work' : 'Edit work'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Work entry',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    key: const Key('work-subject'),
                    initialValue: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Focus Area or Special Activity',
                    ),
                    items: subjects.entries
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(
                              item.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            _subject = value;
                            _validationError = null;
                          }),
                    validator: (value) =>
                        value == null ? 'Select an activity' : null,
                  ),
                  if (areas.status == FocusAreasStatus.loading ||
                      activities.status == SpecialActivitiesStatus.loading) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                  if (areas.status == FocusAreasStatus.error ||
                      activities.status == SpecialActivitiesStatus.error) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Some activities could not be loaded.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(focusAreasProvider.notifier).refresh();
                        ref.read(specialActivitiesProvider.notifier).refresh();
                      },
                      child: const Text('Retry loading activities'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    key: const Key('work-date'),
                    onPressed: saving ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Work date: ${_dateLabel(_date)}'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 560;
                      final focus = _TimeFields(
                        label: 'Focused time',
                        prefix: 'focus',
                        minutes: _focusMinutes,
                        seconds: _focusSeconds,
                        enabled: !saving,
                      );
                      final rest = _TimeFields(
                        label: 'Rest time',
                        prefix: 'rest',
                        minutes: _restMinutes,
                        seconds: _restSeconds,
                        enabled: !saving,
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: focus),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(child: rest),
                              ],
                            )
                          : Column(
                              children: [
                                focus,
                                const SizedBox(height: AppSpacing.md),
                                rest,
                              ],
                            );
                    },
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_attemptedSave &&
                      entries.status == ManualWorkEntriesStatus.error) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorMessage(entries.error),
                      key: const Key('work-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (saving)
                    const LinearProgressIndicator(key: Key('work-form-saving')),
                  FilledButton(
                    key: const Key('save-work-entry'),
                    onPressed: saving ? null : _submit,
                    child: Text(
                      widget.entry == null ? 'Save entry' : 'Save changes',
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

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final focus = Duration(
      minutes: int.parse(_focusMinutes.text),
      seconds: int.parse(_focusSeconds.text),
    );
    final rest = Duration(
      minutes: int.parse(_restMinutes.text),
      seconds: int.parse(_restSeconds.text),
    );
    if (focus == Duration.zero && rest == Duration.zero) {
      setState(() => _validationError = 'Enter focused or rest time.');
      return;
    }
    setState(() {
      _validationError = null;
      _attemptedSave = true;
    });
    final parts = _subject!.split(':');
    final focusAreaId = parts.first == 'focus' ? int.parse(parts.last) : null;
    final specialActivityId = parts.first == 'special'
        ? int.parse(parts.last)
        : null;
    final controller = ref.read(manualWorkEntriesProvider.notifier);
    final success = widget.entry == null
        ? await controller.create(
            ManualWorkEntryCreateInput(
              focusAreaId: focusAreaId,
              specialActivityId: specialActivityId,
              workDate: _date,
              focusedTime: focus,
              restTime: rest,
            ),
          )
        : await controller.update(
            widget.entry!.id,
            ManualWorkEntryUpdateInput(
              changeOwner:
                  focusAreaId != widget.entry!.focusAreaId ||
                  specialActivityId != widget.entry!.specialActivityId,
              focusAreaId: focusAreaId,
              specialActivityId: specialActivityId,
              workDate: _date,
              focusedTime: focus,
              restTime: rest,
            ),
          );
    if (success && mounted) Navigator.of(context).pop();
  }
}

class _TimeFields extends StatelessWidget {
  const _TimeFields({
    required this.label,
    required this.prefix,
    required this.minutes,
    required this.seconds,
    required this.enabled,
  });
  final String label;
  final String prefix;
  final TextEditingController minutes;
  final TextEditingController seconds;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _NumberField(
              key: Key('$prefix-minutes'),
              controller: minutes,
              label: 'Minutes',
              enabled: enabled,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _NumberField(
              key: Key('$prefix-seconds'),
              controller: seconds,
              label: 'Seconds',
              enabled: enabled,
              max: 59,
            ),
          ),
        ],
      ),
    ],
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.max,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int? max;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (value) {
      final number = int.tryParse(value ?? '');
      if (number == null) return 'Enter a number';
      if (max != null && number > max!) return 'Use 0–$max';
      return null;
    },
  );
}

String _dateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _errorMessage(Object? error) =>
    error is AppException ? error.message : 'Unable to save work entry.';
