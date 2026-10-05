import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/navigation/ponos_destination.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/focus_area_form_page.dart';
import '../../focus_areas/presentation/work_areas_page.dart';
import '../../focus_timer/presentation/focus_timer_page.dart';
import '../../work_entries/presentation/create_special_activity_page.dart';
import '../../work_entries/presentation/log_work_page.dart';
import 'overview_page.dart';

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
      appBar: AppBar(
        toolbarHeight: AppSpacing.xxxl,
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            SizedBox.square(
              dimension: 34,
              child: SvgPicture.asset(
                AppAssets.ponosEmblemCompact,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text('Ponos'),
          ],
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
    );
  }

  Widget _buildDestination(PonosDestination destination) {
    return switch (destination) {
      PonosDestination.overview => OverviewPage(
        onStartFocus: () => _selectDestination(PonosDestination.focus),
        onManageWorkAreas: () => _selectDestination(PonosDestination.workAreas),
        onLogWork: () => _selectDestination(PonosDestination.logWork),
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
