import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/work_goals_providers.dart';
import '../../../app/theme/app_spacing.dart';
import '../../home/presentation/state/today_overview_provider.dart';
import '../domain/models/work_goals.dart';

class WorkGoalsPage extends ConsumerStatefulWidget {
  const WorkGoalsPage({super.key});

  @override
  ConsumerState<WorkGoalsPage> createState() => _WorkGoalsPageState();
}

class _WorkGoalsPageState extends ConsumerState<WorkGoalsPage> {
  final _formKey = GlobalKey<FormState>();
  final _dailyControllers = List.generate(7, (_) => TextEditingController());
  final _weeklyController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    for (final controller in _dailyControllers) {
      controller.dispose();
    }
    _weeklyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(workGoalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Work Goals')),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load work goals'),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => ref.invalidate(workGoalsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (value) {
          _initialize(value);
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Daily focused-time goals',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var index = 0; index < 7; index++) ...[
                        TextFormField(
                          controller: _dailyControllers[index],
                          decoration: InputDecoration(
                            labelText: '${_weekdayNames[index]} minutes',
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateMinutes,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Weekly focused-time goal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _weeklyController,
                        decoration: const InputDecoration(
                          labelText: 'Weekly minutes',
                          helperText: 'Changes take effect next calendar week.',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validateMinutes,
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(value),
                        child: Text(_saving ? 'Saving…' : 'Save goals'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _initialize(WorkGoals goals) {
    if (_initialized) return;
    final byWeekday = {for (final goal in goals.dailyGoals) goal.weekday: goal};
    for (var index = 0; index < 7; index++) {
      _dailyControllers[index].text = (byWeekday[index + 1]?.targetMinutes ?? 0)
          .toString();
    }
    _weeklyController.text = goals.weeklyGoalMinutes.toString();
    _initialized = true;
  }

  String? _validateMinutes(String? value) {
    final minutes = int.tryParse(value ?? '');
    if (minutes == null || minutes < 0) return 'Enter 0 or more minutes';
    return null;
  }

  Future<void> _save(WorkGoals current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final updated = WorkGoals(
      date: current.date,
      dailyGoals: [
        for (var index = 0; index < 7; index++)
          DailyWorkGoal(
            weekday: index + 1,
            targetMinutes: int.parse(_dailyControllers[index].text),
          ),
      ],
      weeklyGoalMinutes: int.parse(_weeklyController.text),
      weeklyGoalEffectiveFrom: current.weeklyGoalEffectiveFrom,
    );
    try {
      await ref.read(workGoalsRepositoryProvider).save(current.date, updated);
      ref.invalidate(workGoalsProvider);
      ref.invalidate(todayOverviewProvider);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Work goals saved')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = error.toString();
        });
      }
    }
  }
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
