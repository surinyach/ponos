import 'package:flutter/foundation.dart';
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
import 'timer_laurel.dart';

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
  String? _focusError;
  String? _restError;

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
    final platform = Theme.of(context).platform;
    final mobile =
        !kIsWeb &&
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS) &&
        layout == AppLayoutSize.compact;
    if (mobile) return _buildMobile(timer, areasState, activitiesState);
    final horizontalPadding = switch (layout) {
      AppLayoutSize.compact => AppSpacing.md,
      AppLayoutSize.medium => AppSpacing.lg,
      AppLayoutSize.expanded => AppSpacing.xl + AppSpacing.xs,
    };
    return SingleChildScrollView(
      primary: false,
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

  Widget _buildMobile(
    FocusTimerState timer,
    FocusAreasState areas,
    SpecialActivitiesState activities,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialSize = (constraints.maxHeight * .38).clamp(144.0, 280.0);
        // Reserve room for the heading, page insets, and the natural setup
        // controls. Larger text or errors can grow beyond this minimum and
        // the surrounding scroll view remains available.
        final setupReserve =
            AppSpacing.minimumTouchTarget * 4 +
            AppSpacing.xl * 2 +
            AppSpacing.md +
            AppSpacing.xxs;
        final activeReserve = AppSpacing.xxxl + AppSpacing.md;
        final timerMinHeight =
            (constraints.maxHeight -
                    (timer.activeTimer == null ? setupReserve : activeReserve))
                .clamp(0.0, double.infinity);
        Widget content;
        if (timer.status == FocusTimerStatus.restoring) {
          content = const _LoadingState();
        } else if (timer.status == FocusTimerStatus.error &&
            timer.activeTimer == null) {
          content = _MessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Unable to restore the timer',
            message: _errorMessage(timer.error),
            action: OutlinedButton.icon(
              onPressed: ref.read(focusTimerProvider.notifier).restore,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        } else if (timer.activeTimer != null) {
          final active = timer.activeTimer!;
          final name = active.specialActivityId != null
              ? _specialName(activities.active, active.specialActivityId!)
              : _areaName(areas.areas, active.focusAreaId);
          content = _ActiveTimerPanel(
            state: timer,
            areaName: name,
            onPause: ref.read(focusTimerProvider.notifier).pause,
            onResume: ref.read(focusTimerProvider.notifier).resume,
            onReset: _showResetOptions,
            compact: true,
            dialSize: dialSize,
            minHeight: timerMinHeight,
          );
        } else if (areas.status == FocusAreasStatus.loading ||
            activities.status == SpecialActivitiesStatus.loading ||
            (areas.areas.isEmpty && activities.active.isEmpty)) {
          content = _buildSetup(areas, activities);
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadyTimer(
                focusMinutes: _focusMinutes,
                restMinutes: _restMinutes,
                onStart: _start,
                compact: true,
                dialSize: dialSize,
                minHeight: timerMinHeight,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ConfigurationCard(
                areas: areas.areas,
                activities: activities.active,
                selectedSubject: _validSelection(
                  areas.areas,
                  activities.active,
                ),
                focusMinutes: _focusMinutes,
                restMinutes: _restMinutes,
                error: _configurationError,
                focusError: _focusError,
                restError: _restError,
                onFocusChanged: (_) => setState(() => _focusError = null),
                onRestChanged: (_) => setState(() => _restError = null),
                onSubjectChanged: (value) =>
                    setState(() => _selectedSubject = value),
                compact: true,
              ),
            ],
          );
        }
        return SingleChildScrollView(
          key: const Key('mobile-timer-scroll'),
          primary: false,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Focus timer',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              content,
            ],
          ),
        );
      },
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
          focusError: _focusError,
          restError: _restError,
          onFocusChanged: (_) => setState(() => _focusError = null),
          onRestChanged: (_) => setState(() => _restError = null),
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
    final focusError = focus == null || focus <= 0
        ? 'Focus must be at least 1 minute.'
        : null;
    final restError = rest == null || rest <= 0
        ? 'Rest must be at least 1 minute.'
        : null;
    if ((areas.isEmpty && activities.isEmpty) ||
        focusError != null ||
        restError != null) {
      setState(() {
        _focusError = focusError;
        _restError = restError;
        _configurationError = areas.isEmpty && activities.isEmpty
            ? 'Select a Work Area.'
            : null;
      });
      return;
    }
    setState(() {
      _configurationError = null;
      _focusError = null;
      _restError = null;
    });
    final subject = _validSelection(areas, activities).split(':');
    final started = await ref
        .read(focusTimerProvider.notifier)
        .start(
          focusAreaId: subject[0] == 'focus' ? int.parse(subject[1]) : null,
          specialActivityId: subject[0] == 'special'
              ? int.parse(subject[1])
              : null,
          focusDuration: Duration(minutes: focus!),
          restDuration: Duration(minutes: rest!),
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
    required this.onFocusChanged,
    required this.onRestChanged,
    this.error,
    this.focusError,
    this.restError,
    this.compact = false,
  });

  final List<FocusArea> areas;
  final List<SpecialActivity> activities;
  final String selectedSubject;
  final TextEditingController focusMinutes;
  final TextEditingController restMinutes;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String> onFocusChanged, onRestChanged;
  final String? error;
  final String? focusError, restError;
  final bool compact;

  @override
  Widget build(BuildContext context) => PonosCard(
    key: const Key('timer-configuration-card'),
    padding: compact ? PonosCardPadding.compact : PonosCardPadding.standard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Session setup', style: Theme.of(context).textTheme.titleLarge),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose where your work is recorded and the length of each phase.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.lg),
        DropdownButtonFormField<String>(
          key: const Key('timer-focus-area'),
          isExpanded: true,
          initialValue: selectedSubject,
          decoration: const InputDecoration(labelText: 'Activity'),
          selectedItemBuilder: (context) => [
            if (areas.isNotEmpty) const SizedBox.shrink(),
            for (final area in areas)
              _SelectedWorkArea(name: area.name, isSpecial: false),
            if (activities.isNotEmpty) const SizedBox.shrink(),
            for (final activity in activities)
              _SelectedWorkArea(name: activity.name, isSpecial: true),
          ],
          items: [
            if (areas.isNotEmpty)
              const DropdownMenuItem<String>(
                enabled: false,
                child: _WorkAreaGroupHeading(label: 'Focus Areas'),
              ),
            for (final area in areas)
              DropdownMenuItem(
                key: ValueKey('timer-option-focus-${area.id}'),
                value: 'focus:${area.id}',
                child: _SelectedWorkArea(name: area.name, isSpecial: false),
              ),
            if (activities.isNotEmpty)
              DropdownMenuItem<String>(
                enabled: false,
                child: _WorkAreaGroupHeading(
                  label: 'Special Activities',
                  separated: areas.isNotEmpty,
                ),
              ),
            for (final activity in activities)
              DropdownMenuItem(
                key: ValueKey('timer-option-special-${activity.id}'),
                value: 'special:${activity.id}',
                child: _SelectedWorkArea(name: activity.name, isSpecial: true),
              ),
          ],
          onChanged: onSubjectChanged,
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                MediaQuery.textScalerOf(context).scale(120) * 2 +
                    AppSpacing.md >
                constraints.maxWidth;
            final width = stacked
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md) / 2;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                SizedBox(
                  width: width,
                  child: _MinutesField(
                    key: const Key('timer-focus-minutes'),
                    controller: focusMinutes,
                    label: 'Focus minutes',
                    error: focusError,
                    onChanged: onFocusChanged,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MinutesField(
                    key: const Key('timer-rest-minutes'),
                    controller: restMinutes,
                    label: 'Rest minutes',
                    error: restError,
                    onChanged: onRestChanged,
                  ),
                ),
              ],
            );
          },
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

class _WorkAreaGroupHeading extends StatelessWidget {
  const _WorkAreaGroupHeading({required this.label, this.separated = false});
  final String label;
  final bool separated;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      header: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: AppSpacing.minimumTouchTarget,
          child: separated
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      key: Key('timer-activity-group-divider'),
                      color: AppColors.border,
                      height: 1,
                      thickness: 1,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: heading,
                      ),
                    ),
                  ],
                )
              : Align(alignment: Alignment.centerLeft, child: heading),
        ),
      ),
    );
  }
}

class _SelectedWorkArea extends StatelessWidget {
  const _SelectedWorkArea({required this.name, required this.isSpecial});
  final String name;
  final bool isSpecial;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${isSpecial ? 'Special Activity' : 'Focus Area'}: $name',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Icon(
            isSpecial
                ? Icons.local_activity_outlined
                : Icons.track_changes_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

class _ReadyTimer extends StatelessWidget {
  const _ReadyTimer({
    required this.focusMinutes,
    required this.restMinutes,
    required this.onStart,
    this.compact = false,
    this.dialSize = 320,
    this.minHeight = 0,
  });
  final TextEditingController focusMinutes;
  final TextEditingController restMinutes;
  final VoidCallback onStart;
  final bool compact;
  final double dialSize;
  final double minHeight;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: PonosCard(
      key: const Key('ready-timer-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: compact
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CURRENT CYCLE', style: Theme.of(context).textTheme.labelMedium),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.xl),
          ListenableBuilder(
            listenable: focusMinutes,
            builder: (context, _) => _TimerDial(
              label: 'READY',
              value: _formatDuration(
                Duration(minutes: int.tryParse(focusMinutes.text) ?? 0),
              ),
              subtitle: '',
              maxSize: dialSize,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.xl),
          if (!compact) ...[
            _PhaseStrip(focus: focusMinutes, rest: restMinutes),
            const SizedBox(height: AppSpacing.md),
          ],
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

class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.label,
    required this.value,
    required this.subtitle,
    this.progress = 0,
    this.isRest = false,
    this.maxSize = 320,
  });
  final String label, value, subtitle;
  final double progress;
  final bool isRest;
  final double maxSize;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = constraints.maxWidth < maxSize
          ? constraints.maxWidth
          : maxSize;
      final textTheme = Theme.of(context).textTheme;
      final textScaler = MediaQuery.textScalerOf(context);
      double measuredHeight(
        String text,
        TextStyle? style, {
        bool singleLine = false,
      }) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: singleLine ? double.infinity : diameter * .62);
        final height =
            singleLine &&
                textScaler.scale(1) <= 1 &&
                painter.width > diameter * .62
            ? painter.height * (diameter * .62 / painter.width)
            : painter.height;
        painter.dispose();
        return height;
      }

      final needsSeparateText =
          measuredHeight(label, textTheme.labelLarge) +
              measuredHeight(value, textTheme.displayLarge, singleLine: true) +
              measuredHeight(subtitle, textTheme.bodySmall) >
          diameter * .7;
      final time = Text(
        value,
        key: label == 'READY' ? null : const Key('timer-remaining'),
        textAlign: TextAlign.center,
        style: textTheme.displayLarge?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      final text = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: isRest ? AppColors.accent : AppColors.primary,
            ),
          ),
          if (needsSeparateText)
            time
          else
            FittedBox(fit: BoxFit.scaleDown, child: time),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      );
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TimerLaurel(progress: progress, isRest: isRest),
                    if (!needsSeparateText)
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: .62,
                          child: text,
                        ),
                      ),
                  ],
                ),
              ),
              if (needsSeparateText) text,
            ],
          ),
        ),
      );
    },
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
    required this.onChanged,
    this.error,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      suffixText: 'min',
      errorText: error,
      errorMaxLines: 3,
      filled: true,
      fillColor: AppColors.background,
    ),
  );
}

class _ActiveTimerPanel extends StatelessWidget {
  const _ActiveTimerPanel({
    required this.state,
    required this.areaName,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    this.compact = false,
    this.dialSize = 320,
    this.minHeight = 0,
  });

  final FocusTimerState state;
  final String areaName;
  final Future<bool> Function() onPause;
  final Future<bool> Function() onResume;
  final VoidCallback onReset;
  final bool compact;
  final double dialSize;
  final double minHeight;

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

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: PonosCard(
        key: const Key('active-timer'),
        padding: compact ? PonosCardPadding.compact : PonosCardPadding.standard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: compact
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.start,
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
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.lg),
            _TimerDial(
              label: timer.phase == FocusTimerPhase.focus ? 'FOCUS' : 'REST',
              value: _formatDuration(state.phaseRemaining),
              subtitle: paused ? 'Paused' : 'Time remaining',
              progress: progress,
              isRest: timer.phase == FocusTimerPhase.rest,
              maxSize: dialSize,
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.lg),
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
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.xl),
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
            if (compact) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Focus · ${timer.focusDuration.inMinutes} min   •   Rest · ${timer.restDuration.inMinutes} min',
                key: const Key('timer-config-summary'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
