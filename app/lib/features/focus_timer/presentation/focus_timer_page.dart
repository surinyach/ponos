import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/widgets/ponos_card.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/state/focus_areas_controller.dart';
import '../../focus_areas/presentation/state/focus_areas_state.dart';
import '../../work_entries/domain/models/special_activity.dart';
import '../../work_entries/presentation/state/special_activities_controller.dart';
import '../../work_entries/presentation/state/special_activities_state.dart';
import '../domain/models/active_focus_timer.dart';
import 'state/focus_timer_controller.dart';
import 'state/focus_timer_state.dart';

class FocusTimerPage extends ConsumerStatefulWidget {
  const FocusTimerPage({super.key});

  @override
  ConsumerState<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends ConsumerState<FocusTimerPage> {
  final _focusMinutes = TextEditingController(text: '25');
  final _restMinutes = TextEditingController(text: '5');
  String? _selectedSubject;
  String? _configurationError;

  @override
  void dispose() {
    _focusMinutes.dispose();
    _restMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(focusTimerProvider);
    final areasState = ref.watch(focusAreasProvider);
    final activitiesState = ref.watch(specialActivitiesProvider);

    final layout = AppBreakpoints.layoutFor(
      PonosViewportScope.sizeOf(context).width,
    );
    final horizontalPadding = switch (layout) {
      AppLayoutSize.compact => AppSpacing.md,
      AppLayoutSize.medium => AppSpacing.lg,
      AppLayoutSize.expanded => AppSpacing.xl + AppSpacing.xs,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: layout == AppLayoutSize.compact
            ? AppSpacing.md
            : AppSpacing.lg,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Focus timer',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'One focused effort, followed by deliberate rest.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              switch (timer.status) {
                FocusTimerStatus.restoring => const _LoadingState(),
                FocusTimerStatus.inactive => _buildSetup(
                  areasState,
                  activitiesState,
                ),
                FocusTimerStatus.error when timer.activeTimer == null =>
                  _MessageCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to restore the timer',
                    message: _errorMessage(timer.error),
                    action: OutlinedButton.icon(
                      onPressed: ref.read(focusTimerProvider.notifier).restore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                _ => _activeLayout(timer, areasState, activitiesState),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeLayout(
    FocusTimerState timer,
    FocusAreasState areasState,
    SpecialActivitiesState activitiesState,
  ) {
    final active = timer.activeTimer!;
    final name = active.specialActivityId != null
        ? _specialName(activitiesState.active, active.specialActivityId!)
        : _areaName(areasState.areas, active.focusAreaId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final panel = _ActiveTimerPanel(
          state: timer,
          areaName: name,
          onPause: ref.read(focusTimerProvider.notifier).pause,
          onResume: ref.read(focusTimerProvider.notifier).resume,
          onReset: _showResetOptions,
        );
        final details = _SessionDetails(
          name: name,
          focus: active.focusDuration,
          rest: active.restDuration,
        );
        if (constraints.maxWidth >= AppBreakpoints.expanded) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: panel),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 4, child: details),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            panel,
            const SizedBox(height: AppSpacing.md),
            details,
          ],
        );
      },
    );
  }

  Widget _buildSetup(
    FocusAreasState areasState,
    SpecialActivitiesState activitiesState,
  ) {
    if (areasState.status == FocusAreasStatus.loading ||
        activitiesState.status == SpecialActivitiesStatus.loading) {
      return const _LoadingState();
    }
    if (areasState.areas.isEmpty &&
        activitiesState.active.isEmpty &&
        (areasState.status == FocusAreasStatus.error ||
            activitiesState.status == SpecialActivitiesStatus.error)) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load activities',
        message: _errorMessage(areasState.error ?? activitiesState.error),
        action: OutlinedButton.icon(
          onPressed: () {
            ref.read(focusAreasProvider.notifier).refresh();
            ref.read(specialActivitiesProvider.notifier).refresh();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }
    if (areasState.areas.isEmpty && activitiesState.active.isEmpty) {
      return const _MessageCard(
        icon: Icons.track_changes_outlined,
        title: 'No active activities',
        message:
            'Create a Focus Area or Special Activity before starting an execution.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.expanded;
        final configuration = _ConfigurationCard(
          areas: areasState.areas,
          activities: activitiesState.active,
          selectedSubject: _validSelection(
            areasState.areas,
            activitiesState.active,
          ),
          focusMinutes: _focusMinutes,
          restMinutes: _restMinutes,
          error: _configurationError,
          onSubjectChanged: (value) => setState(() => _selectedSubject = value),
        );
        final guide = _ReadyTimer(
          focusMinutes: _focusMinutes,
          restMinutes: _restMinutes,
          onStart: _start,
        );
        if (wide) {
          return Row(
            key: const Key('focus-timer-wide'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: guide),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 4, child: configuration),
            ],
          );
        }
        return Column(
          key: const Key('focus-timer-compact'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            guide,
            const SizedBox(height: AppSpacing.md),
            configuration,
          ],
        );
      },
    );
  }

  String _validSelection(
    List<FocusArea> areas,
    List<SpecialActivity> activities,
  ) {
    final choices = [
      for (final area in areas) 'focus:${area.id}',
      for (final activity in activities) 'special:${activity.id}',
    ];
    if (choices.contains(_selectedSubject)) {
      return _selectedSubject!;
    }
    return choices.first;
  }

  Future<void> _start() async {
    final focus = int.tryParse(_focusMinutes.text.trim());
    final rest = int.tryParse(_restMinutes.text.trim());
    final areas = ref.read(focusAreasProvider).areas;
    final activities = ref.read(specialActivitiesProvider).active;
    if ((areas.isEmpty && activities.isEmpty) ||
        focus == null ||
        rest == null ||
        focus <= 0 ||
        rest <= 0) {
      setState(() {
        _configurationError =
            'Enter focus and rest durations greater than zero.';
      });
      return;
    }
    setState(() => _configurationError = null);
    final subject = _validSelection(areas, activities).split(':');
    final started = await ref
        .read(focusTimerProvider.notifier)
        .start(
          focusAreaId: subject[0] == 'focus' ? int.parse(subject[1]) : null,
          specialActivityId: subject[0] == 'special'
              ? int.parse(subject[1])
              : null,
          focusDuration: Duration(minutes: focus),
          restDuration: Duration(minutes: rest),
        );
    if (!started && mounted) {
      setState(() => _configurationError = 'The timer could not be started.');
    }
  }

  Future<void> _showResetOptions() async {
    final choice = await showDialog<_ResetChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset execution?'),
        content: const Text(
          'Save the elapsed time as a partial execution, or discard it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ResetChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ResetChoice.savePartial),
            child: const Text('Save partial'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final controller = ref.read(focusTimerProvider.notifier);
    if (choice == _ResetChoice.savePartial) {
      await controller.resetAndSavePartial();
    } else {
      await controller.resetAndDiscard();
    }
  }

  String _areaName(List<FocusArea> areas, int? id) =>
      areas
          .where((area) => area.id == id)
          .map((area) => area.name)
          .firstOrNull ??
      'Focus Area #$id';

  String _specialName(List<SpecialActivity> active, int id) =>
      active
          .where((activity) => activity.id == id)
          .map((activity) => activity.name)
          .firstOrNull ??
      'Special Activity #$id';
}

enum _ResetChoice { savePartial, discard }

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard({
    required this.areas,
    required this.activities,
    required this.selectedSubject,
    required this.focusMinutes,
    required this.restMinutes,
    required this.onSubjectChanged,
    this.error,
  });

  final List<FocusArea> areas;
  final List<SpecialActivity> activities;
  final String selectedSubject;
  final TextEditingController focusMinutes;
  final TextEditingController restMinutes;
  final ValueChanged<String?> onSubjectChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => PonosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Session setup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose where your work is recorded and the length of each phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          key: const Key('timer-focus-area'),
          initialValue: selectedSubject,
          decoration: const InputDecoration(labelText: 'Activity'),
          items: [
            for (final area in areas)
              DropdownMenuItem(
                value: 'focus:${area.id}',
                child: Text(area.name),
              ),
            for (final activity in activities)
              DropdownMenuItem(
                value: 'special:${activity.id}',
                child: Text(activity.name),
              ),
          ],
          onChanged: onSubjectChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MinutesField(
                key: const Key('timer-focus-minutes'),
                controller: focusMinutes,
                label: 'Focus minutes',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MinutesField(
                key: const Key('timer-rest-minutes'),
                controller: restMinutes,
                label: 'Rest minutes',
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}

class _ReadyTimer extends StatelessWidget {
  const _ReadyTimer({
    required this.focusMinutes,
    required this.restMinutes,
    required this.onStart,
  });
  final TextEditingController focusMinutes;
  final TextEditingController restMinutes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => PonosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('CURRENT CYCLE', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xl),
        ListenableBuilder(
          listenable: focusMinutes,
          builder: (context, _) => _TimerDial(
            label: 'READY',
            value: _formatDuration(
              Duration(minutes: int.tryParse(focusMinutes.text) ?? 0),
            ),
            subtitle: 'Ready for a focused cycle',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PhaseStrip(focus: focusMinutes, rest: restMinutes),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('timer-start'),
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start focus'),
        ),
      ],
    ),
  );
}

class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.label,
    required this.value,
    required this.subtitle,
  });
  final String label, value, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: label == 'READY' ? null : const Key('timer-remaining'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.focus, required this.rest});
  final TextEditingController focus, rest;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([focus, rest]),
    builder: (context, _) => Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Chip(label: Text('01 · Focus  ${focus.text} min')),
        Chip(label: Text('02 · Rest  ${rest.text} min')),
      ],
    ),
  );
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({
    required this.name,
    required this.focus,
    required this.rest,
  });
  final String name;
  final Duration focus, rest;
  @override
  Widget build(BuildContext context) => PonosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text('Work Area', style: Theme.of(context).textTheme.labelMedium),
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            Text('Focus · ${focus.inMinutes} min'),
            Text('Rest · ${rest.inMinutes} min'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('One execution · Focus followed by Rest'),
      ],
    ),
  );
}

class _MinutesField extends StatelessWidget {
  const _MinutesField({
    required this.controller,
    required this.label,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, suffixText: 'min'),
  );
}

class _ActiveTimerPanel extends StatelessWidget {
  const _ActiveTimerPanel({
    required this.state,
    required this.areaName,
    required this.onPause,
    required this.onResume,
    required this.onReset,
  });

  final FocusTimerState state;
  final String areaName;
  final Future<bool> Function() onPause;
  final Future<bool> Function() onResume;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final timer = state.activeTimer!;
    final paused = timer.isPaused;
    final saving = state.status == FocusTimerStatus.persisting;
    final progress = state.phaseDuration == Duration.zero
        ? 0.0
        : (state.phaseElapsed.inMilliseconds /
                  state.phaseDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return PonosCard(
      key: const Key('active-timer'),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CURRENT CYCLE',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Text(areaName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Chip(
            avatar: Icon(
              timer.phase == FocusTimerPhase.focus
                  ? Icons.bolt_rounded
                  : Icons.self_improvement_rounded,
              size: 18,
            ),
            label: Text(
              timer.phase == FocusTimerPhase.focus
                  ? 'Focus phase'
                  : 'Rest phase',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TimerDial(
            label: timer.phase == FocusTimerPhase.focus ? 'FOCUS' : 'REST',
            value: _formatDuration(state.phaseRemaining),
            subtitle: paused ? 'Paused' : 'Time remaining',
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          if (state.status == FocusTimerStatus.error) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage(state.error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (saving)
            const CircularProgressIndicator()
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: Key(paused ? 'timer-resume' : 'timer-pause'),
                  onPressed: paused ? onResume : onPause,
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(paused ? 'Resume' : 'Pause'),
                ),
                if (paused)
                  OutlinedButton.icon(
                    key: const Key('timer-reset'),
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: CircularProgressIndicator(),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}

String _errorMessage(Object? error) => switch (error) {
  AppException exception => exception.message,
  _ => 'Something went wrong. Please try again.',
};
