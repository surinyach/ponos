import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/domain/models/focus_area_target.dart';
import '../../focus_areas/presentation/focus_area_form_page.dart';
import '../../focus_areas/presentation/focus_areas_page.dart';
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
          0 => const _OverviewContent(),
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

class _OverviewContent extends StatelessWidget {
  const _OverviewContent();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const summary = TodaySummary(
                workedDuration: Duration(hours: 6, minutes: 30),
                expectedDuration: Duration(hours: 11),
                completedFocusAreas: 1,
                totalFocusAreas: 3,
              );
              const statistics = WorkStatistics(
                totalDaysWorked: 128,
                totalFocusedTime: Duration(hours: 342, minutes: 30),
                totalRestTime: Duration(hours: 86, minutes: 15),
                totalTrackedTime: Duration(hours: 428, minutes: 45),
              );
              final focusAreas = FocusAreas(
                targetDate: DateTime(2026, 9, 7),
                workedTodayByAreaId: const {
                  1: Duration(hours: 5),
                  2: Duration(minutes: 30),
                  3: Duration(hours: 1),
                },
                areas: [
                  _mockFocusArea(1, 'Work Placement', 1, 480),
                  _mockFocusArea(2, 'Personal Project', 2, 120),
                  _mockFocusArea(3, 'LeetCode', 3, 60),
                ],
              );
              const streak = StreakConsistency(
                dailyStreak: 6,
                weeklyStreak: 3,
                week: [
                  ConsistencyDay(label: 'M', isCompleted: true),
                  ConsistencyDay(label: 'T', isCompleted: true),
                  ConsistencyDay(label: 'W', isCompleted: true),
                  ConsistencyDay(label: 'T', isCompleted: true),
                  ConsistencyDay(label: 'F', isCompleted: false, isToday: true),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
        ),
      ),
    );
  }
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

FocusArea _mockFocusArea(int id, String name, int priority, int targetMinutes) {
  final timestamp = DateTime.utc(2026, 9, 1);
  return FocusArea(
    id: id,
    name: name,
    priority: priority,
    createdAt: timestamp,
    updatedAt: timestamp,
    targets: [
      FocusAreaTarget(
        id: id,
        focusAreaId: id,
        weekday: DateTime.monday,
        targetMinutes: targetMinutes,
        validFrom: DateTime(2026, 9, 7),
      ),
    ],
  );
}
