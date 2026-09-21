import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../domain/models/focus_area.dart';
import '../../work_entries/presentation/special_activities_page.dart';
import 'focus_areas_page.dart';

class WorkAreasPage extends StatefulWidget {
  const WorkAreasPage({
    required this.onCreateFocusArea,
    required this.onCreateSpecialActivity,
    required this.onFocusAreaSelected,
    super.key,
  });

  final VoidCallback onCreateFocusArea;
  final VoidCallback onCreateSpecialActivity;
  final ValueChanged<FocusArea> onFocusAreaSelected;

  @override
  State<WorkAreasPage> createState() => _WorkAreasPageState();
}

class _WorkAreasPageState extends State<WorkAreasPage> {
  int _selectedType = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        child: SegmentedButton<int>(
          key: const Key('work-area-type'),
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.track_changes_outlined),
              label: Text('Focus Areas'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.star_outline),
              label: Text('Special Activities'),
            ),
          ],
          selected: {_selectedType},
          onSelectionChanged: (values) =>
              setState(() => _selectedType = values.single),
        ),
      ),
      Expanded(
        child: _selectedType == 0
            ? FocusAreasPage(
                onCreate: widget.onCreateFocusArea,
                onAreaSelected: widget.onFocusAreaSelected,
              )
            : SpecialActivitiesPage(onCreate: widget.onCreateSpecialActivity),
      ),
    ],
  );
}
