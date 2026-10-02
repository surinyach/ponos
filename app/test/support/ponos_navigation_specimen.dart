import 'package:flutter/material.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/navigation/ponos_destination.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_card.dart';

class PonosNavigationSpecimenApp extends StatefulWidget {
  const PonosNavigationSpecimenApp({super.key});

  @override
  State<PonosNavigationSpecimenApp> createState() =>
      _PonosNavigationSpecimenAppState();
}

class _PonosNavigationSpecimenAppState
    extends State<PonosNavigationSpecimenApp> {
  PonosDestination _selected = PonosDestination.overview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: PonosAdaptiveShell(
        selectedDestination: _selected,
        onDestinationSelected: (destination) {
          setState(() => _selected = destination);
        },
        destinationBuilder: (destination) =>
            _SpecimenPage(destination: destination),
        appBar: AppBar(title: const Text('Ponos')),
      ),
    );
  }
}

class _SpecimenPage extends StatelessWidget {
  const _SpecimenPage({required this.destination});

  final PonosDestination destination;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                destination.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              PonosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(destination.selectedIcon, size: 32),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${destination.label} content',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Feature content remains independent from the adaptive navigation shell.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
