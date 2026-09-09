import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/state/focus_areas_controller.dart';
import '../../focus_areas/presentation/state/focus_areas_state.dart';
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
  int? _selectedAreaId;
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

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
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
                FocusTimerStatus.inactive => _buildSetup(areasState),
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
                _ => _ActiveTimerPanel(
                  state: timer,
                  areaName: _areaName(
                    areasState.areas,
                    timer.activeTimer?.focusAreaId,
                  ),
                  onPause: ref.read(focusTimerProvider.notifier).pause,
                  onResume: ref.read(focusTimerProvider.notifier).resume,
                  onReset: _showResetOptions,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetup(FocusAreasState areasState) {
    if (areasState.status == FocusAreasStatus.loading) {
      return const _LoadingState();
    }
    if (areasState.areas.isEmpty &&
        areasState.status == FocusAreasStatus.error) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load Focus Areas',
        message: _errorMessage(areasState.error),
        action: OutlinedButton.icon(
          onPressed: () => ref.read(focusAreasProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }
    if (areasState.areas.isEmpty) {
      return const _MessageCard(
        icon: Icons.track_changes_outlined,
        title: 'No active Focus Areas',
        message: 'Create a Focus Area before starting an execution.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final configuration = _ConfigurationCard(
          areas: areasState.areas,
          selectedAreaId: _validSelection(areasState.areas),
          focusMinutes: _focusMinutes,
          restMinutes: _restMinutes,
          error: _configurationError,
          onAreaChanged: (value) => setState(() => _selectedAreaId = value),
          onStart: _start,
        );
        final guide = const _MessageCard(
          icon: Icons.hourglass_top_rounded,
          title: 'Prepare your cycle',
          message:
              'Choose one priority and set the focus and rest durations. '
              'Neither phase can be skipped once the execution starts.',
        );
        if (wide) {
          return Row(
            key: const Key('focus-timer-wide'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: configuration),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: guide),
            ],
          );
        }
        return Column(
          key: const Key('focus-timer-compact'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            configuration,
            const SizedBox(height: AppSpacing.md),
            guide,
          ],
        );
      },
    );
  }

  int _validSelection(List<FocusArea> areas) {
    if (areas.any((area) => area.id == _selectedAreaId)) {
      return _selectedAreaId!;
    }
    return areas.first.id;
  }

  Future<void> _start() async {
    final focus = int.tryParse(_focusMinutes.text.trim());
    final rest = int.tryParse(_restMinutes.text.trim());
    final areas = ref.read(focusAreasProvider).areas;
    if (areas.isEmpty ||
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
    final started = await ref
        .read(focusTimerProvider.notifier)
        .start(
          focusAreaId: _validSelection(areas),
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
}

enum _ResetChoice { savePartial, discard }

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard({
    required this.areas,
    required this.selectedAreaId,
    required this.focusMinutes,
    required this.restMinutes,
    required this.onAreaChanged,
    required this.onStart,
    this.error,
  });

  final List<FocusArea> areas;
  final int selectedAreaId;
  final TextEditingController focusMinutes;
  final TextEditingController restMinutes;
  final ValueChanged<int?> onAreaChanged;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New execution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            key: const Key('timer-focus-area'),
            initialValue: selectedAreaId,
            decoration: const InputDecoration(labelText: 'Focus Area'),
            items: areas
                .map(
                  (area) =>
                      DropdownMenuItem(value: area.id, child: Text(area.name)),
                )
                .toList(growable: false),
            onChanged: onAreaChanged,
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
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('timer-start'),
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start focus'),
          ),
        ],
      ),
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

    return Card(
      key: const Key('active-timer'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
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
            Text(
              _formatDuration(state.phaseRemaining),
              key: const Key('timer-remaining'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
