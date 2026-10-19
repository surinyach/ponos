import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/navigation/ponos_adaptive_shell.dart';
import '../../../app/navigation/ponos_destination.dart';
import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../focus_areas/domain/models/focus_area.dart';
import '../../focus_areas/presentation/archived_focus_area_details_page.dart';
import '../../focus_areas/presentation/focus_area_form_page.dart';
import '../../focus_areas/presentation/work_areas_page.dart';
import '../../focus_timer/presentation/focus_timer_page.dart';
import '../../work_entries/presentation/create_special_activity_page.dart';
import '../../work_entries/presentation/log_work_page.dart';
import '../../work_entries/domain/models/special_activity.dart';
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
        onSpecialActivitySelected: _openSpecialActivityForm,
        onFocusAreaSelected: (area) => _openFocusAreaForm(area),
        onArchivedFocusAreaSelected: _openArchivedFocusAreaDetails,
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
      MaterialPageRoute(
        builder: (_) => _FocusAreaFormShell(
          area: area,
          onDestinationSelected: (destination) {
            Navigator.of(context).pop();
            _selectDestination(destination);
          },
        ),
      ),
    );
  }

  Future<void> _openSpecialActivityForm([SpecialActivity? activity]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SpecialActivityFormShell(
          activity: activity,
          onDestinationSelected: (destination) {
            Navigator.of(context).pop();
            _selectDestination(destination);
          },
        ),
      ),
    );
  }

  Future<void> _openArchivedFocusAreaDetails(FocusArea area) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ArchivedDetailsShell(
          area: area,
          onDestinationSelected: (destination) {
            Navigator.of(context).pop();
            _selectDestination(destination);
          },
        ),
      ),
    );
  }
}

class _FocusAreaFormShell extends StatelessWidget {
  const _FocusAreaFormShell({
    required this.area,
    required this.onDestinationSelected,
  });

  final FocusArea? area;
  final ValueChanged<PonosDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) => PonosAdaptiveShell(
    selectedDestination: PonosDestination.workAreas,
    onDestinationSelected: (destination) {
      if (destination != PonosDestination.workAreas) {
        onDestinationSelected(destination);
      }
    },
    destinationBuilder: (_) => FocusAreaFormPage(area: area),
    appBar: _ponosAppBar(),
  );
}

class _SpecialActivityFormShell extends StatelessWidget {
  const _SpecialActivityFormShell({
    required this.activity,
    required this.onDestinationSelected,
  });

  final SpecialActivity? activity;
  final ValueChanged<PonosDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) => PonosAdaptiveShell(
    selectedDestination: PonosDestination.workAreas,
    onDestinationSelected: (destination) {
      if (destination != PonosDestination.workAreas) {
        onDestinationSelected(destination);
      }
    },
    destinationBuilder: (_) => CreateSpecialActivityPage(activity: activity),
    appBar: _ponosAppBar(),
  );
}

PreferredSizeWidget _ponosAppBar() => AppBar(
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
);

class _ArchivedDetailsShell extends StatelessWidget {
  const _ArchivedDetailsShell({
    required this.area,
    required this.onDestinationSelected,
  });

  final FocusArea area;
  final ValueChanged<PonosDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final desktopPlatform =
        kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final compactMobile =
        !desktopPlatform &&
        MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    if (compactMobile) {
      return Scaffold(
        appBar: _appBar(),
        body: ArchivedFocusAreaDetailsPage(area: area),
      );
    }
    return PonosAdaptiveShell(
      selectedDestination: PonosDestination.workAreas,
      onDestinationSelected: (destination) {
        if (destination != PonosDestination.workAreas) {
          onDestinationSelected(destination);
        }
      },
      destinationBuilder: (_) => ArchivedFocusAreaDetailsPage(area: area),
      appBar: _appBar(),
    );
  }

  PreferredSizeWidget _appBar() => _ponosAppBar();
}
