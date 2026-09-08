import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/focus_area_form_page.dart';
import '../../focus_areas/presentation/focus_areas_page.dart';
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
  static const _destinations = <_Destination>[
    _Destination('Overview', Icons.home_outlined, Icons.home),
    _Destination(
      'Focus areas',
      Icons.track_changes_outlined,
      Icons.track_changes,
    ),
    _Destination('Focus', Icons.timer_outlined, Icons.timer),
    _Destination(
      'Progress',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail = constraints.maxWidth >= 700;
        final content = switch (_selectedIndex) {
          0 => _OverviewContent(
            onManageFocusAreas: () => _selectDestination(1),
          ),
          1 => FocusAreasPage(
            onCreate: () => _openFocusAreaForm(),
            onAreaSelected: (area) => _openFocusAreaForm(area),
          ),
          _ => _FeaturePlaceholder(destination: _destinations[_selectedIndex]),
        };

        return Scaffold(
          appBar: AppBar(title: const Text('Ponos')),
          body: useNavigationRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: _destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useNavigationRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: _destinations
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _openFocusAreaForm([FocusArea? area]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FocusAreaFormPage(area: area)),
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
              if (data.areas.isEmpty) {
                return _OverviewEmpty(onManageFocusAreas: onManageFocusAreas);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final summary = TodaySummary(
                    workedDuration: data.actualFocusedTime,
                    expectedDuration: data.expectedFocusTime,
                    completedFocusAreas: data.completedFocusAreas,
                    totalFocusAreas: data.targetedFocusAreas,
                  );
                  const statistics = WorkStatistics(
                    totalDaysWorked: 128,
                    totalFocusedTime: Duration(hours: 342, minutes: 30),
                    totalRestTime: Duration(hours: 86, minutes: 15),
                    totalTrackedTime: Duration(hours: 428, minutes: 45),
                  );
                  final focusAreas = FocusAreas(
                    targetDate: data.date,
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

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({required this.destination});

  final _Destination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.selectedIcon, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This feature will be shaped in the next step.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
