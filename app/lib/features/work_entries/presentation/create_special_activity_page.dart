import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/special_activity.dart';
import 'state/special_activities_controller.dart';
import 'state/special_activities_state.dart';

class CreateSpecialActivityPage extends ConsumerStatefulWidget {
  const CreateSpecialActivityPage({super.key});

  @override
  ConsumerState<CreateSpecialActivityPage> createState() =>
      _CreateSpecialActivityPageState();
}

class _CreateSpecialActivityPageState
    extends ConsumerState<CreateSpecialActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(specialActivitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New Special Activity')),
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
                    'Special Activity',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const Key('special-activity-name'),
                    controller: _name,
                    enabled: !_submitting,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('special-activity-description'),
                    controller: _description,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  if (_error != null ||
                      state.status == SpecialActivitiesStatus.error) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error is AppException
                          ? (_error as AppException).message
                          : 'Unable to create Special Activity.',
                      key: const Key('special-activity-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_submitting)
                    const LinearProgressIndicator(
                      key: Key('special-activity-saving'),
                    ),
                  FilledButton(
                    key: const Key('save-special-activity'),
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Create Special Activity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final created = await ref
        .read(specialActivitiesProvider.notifier)
        .createAndReturn(
          SpecialActivityCreateInput(
            name: _name.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
          ),
        );
    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(specialActivitiesProvider).error;
      });
    }
  }
}
