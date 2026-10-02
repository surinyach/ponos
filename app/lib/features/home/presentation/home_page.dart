import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/navigation/ponos_destination.dart';
import '../../../app/theme/app_spacing.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/focus_area_form_page.dart';
import '../../focus_areas/presentation/work_areas_page.dart';
import '../../focus_timer/presentation/focus_timer_page.dart';
import '../../work_entries/presentation/log_work_page.dart';
import '../../work_entries/presentation/create_special_activity_page.dart';
import 'state/today_overview_provider.dart';
import 'widgets/today_summary.dart';
import 'widgets/focus_areas.dart';
import 'widgets/work_statistics.dart';
import 'widgets/streak_consistency.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PonosDestination _selectedDestination = PonosDestination.overview;

  @override
  Widget build(BuildContext context) {
    return PonosAdaptiveShell(
      selectedDestination: _selectedDestination,
      onDestinationSelected: _selectDestination,
      destinationBuilder: _buildDestination,
      appBar: AppBar(title: const Text('Ponos')),
    );
  }

  Widget _buildDestination(PonosDestination destination) {
    return switch (destination) {
      PonosDestination.overview => _OverviewContent(
        onManageFocusAreas: () =>
            _selectDestination(PonosDestination.workAreas),
      ),
      PonosDestination.workAreas => WorkAreasPage(
        onCreateFocusArea: () => _openFocusAreaForm(),
        onCreateSpecialActivity: _openSpecialActivityForm,
        onFocusAreaSelected: (area) => _openFocusAreaForm(area),
      ),
      PonosDestination.focus => const FocusTimerPage(),
      PonosDestination.logWork => const LogWorkPage(),
    };
  }

  void _selectDestination(PonosDestination destination) {
    if (destination == _selectedDestination) return;
    setState(() => _selectedDestination = destination);
  }

  Future<void> _openFocusAreaForm([FocusArea? area]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FocusAreaFormPage(area: area)),
    );
  }

  Future<void> _openSpecialActivityForm() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CreateSpecialActivityPage()),
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent({required this.onManageFocusAreas});

  final VoidCallback onManageFocusAreas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(todayOverviewProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: overview.when(
            loading: () => const _OverviewLoading(),
            error: (error, _) => _OverviewError(
              onRetry: () => ref.invalidate(todayOverviewProvider),
            ),
            data: (data) {
              final summary = TodaySummary(
                workedDuration: data.actualFocusedTime,
                expectedDuration: data.expectedFocusTime,
                restDuration: data.actualRestTime,
                trackedDuration: data.actualTrackedTime,
                weekFocusedDuration: data.week.focusedTime,
                weekRestDuration: data.week.restTime,
                completedFocusAreas: data.completedFocusAreas,
                totalFocusAreas: data.targetedFocusAreas,
              );
              final statistics = WorkStatistics(
                totalDaysWorked: data.overall.daysWorked,
                totalFocusedTime: data.overall.focusedTime,
                totalRestTime: data.overall.restTime,
                totalTrackedTime: data.overall.trackedTime,
              );
              if (data.areas.isEmpty && data.specialActivities.isEmpty) {
                return Column(
                  children: [
                    _OverviewEmpty(onManageFocusAreas: onManageFocusAreas),
                    const SizedBox(height: AppSpacing.md),
                    summary,
                    const SizedBox(height: AppSpacing.md),
                    statistics,
                  ],
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final focusAreas = FocusAreas(
                    targetDate: data.date,
                    specialActivities: data.specialActivities,
                    areas: data.areas.map((item) => item.focusArea).toList(),
                    workedTodayByAreaId: {
                      for (final item in data.areas)
                        item.focusArea.id: item.focusedTime,
                    },
                    dailyTargetByAreaId: {
                      for (final item in data.areas)
                        item.focusArea.id: item.targetTime,
                    },
                    completedByAreaId: {
                      for (final item in data.areas)
                        item.focusArea.id: item.completed,
                    },
                  );
                  const streak = StreakConsistency(
                    dailyStreak: 6,
                    weeklyStreak: 3,
                    week: [
                      ConsistencyDay(label: 'M', isCompleted: true),
                      ConsistencyDay(label: 'T', isCompleted: true),
                      ConsistencyDay(label: 'W', isCompleted: true),
                      ConsistencyDay(label: 'T', isCompleted: true),
                      ConsistencyDay(
                        label: 'F',
                        isCompleted: false,
                        isToday: true,
                      ),
                      ConsistencyDay(label: 'S', isCompleted: false),
                      ConsistencyDay(label: 'S', isCompleted: false),
                    ],
                  );

                  if (constraints.maxWidth >= 840) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        streak,
                        SizedBox(height: AppSpacing.lg),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: summary),
                                    SizedBox(height: AppSpacing.md),
                                    Expanded(child: statistics),
                                  ],
                                ),
                              ),
                              SizedBox(width: AppSpacing.lg),
                              Expanded(flex: 6, child: focusAreas),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      streak,
                      SizedBox(height: AppSpacing.md),
                      summary,
                      SizedBox(height: AppSpacing.md),
                      statistics,
                      SizedBox(height: AppSpacing.md),
                      focusAreas,
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OverviewLoading extends StatelessWidget {
  const _OverviewLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: CircularProgressIndicator(),
    ),
  );
}

class _OverviewEmpty extends StatelessWidget {
  const _OverviewEmpty({required this.onManageFocusAreas});

  final VoidCallback onManageFocusAreas;

  @override
  Widget build(BuildContext context) => _OverviewMessage(
    icon: Icons.track_changes_outlined,
    title: 'No active focus areas',
    message: 'Create a focus area to start tracking today’s progress.',
    action: FilledButton.icon(
      onPressed: onManageFocusAreas,
      icon: const Icon(Icons.add),
      label: const Text('Create focus area'),
    ),
  );
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _OverviewMessage(
    icon: Icons.cloud_off_outlined,
    title: 'Unable to load today’s overview',
    message: 'Check the backend connection and try again.',
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  );
}

class _OverviewMessage extends StatelessWidget {
  const _OverviewMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          action,
        ],
      ),
    ),
  );
}
