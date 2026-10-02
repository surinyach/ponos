import 'package:flutter/material.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_controls.dart';

class PonosControlsSpecimenApp extends StatelessWidget {
  const PonosControlsSpecimenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const PonosControlsSpecimen(),
  );
}

class PonosControlsSpecimen extends StatelessWidget {
  const PonosControlsSpecimen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ponos controls',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Section(
                title: 'Buttons',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PonosButton.primary(label: 'Start focus', onPressed: _noop),
                    PonosButton.secondary(label: 'Edit area', onPressed: _noop),
                    PonosButton.ghost(label: 'Cancel', onPressed: _noop),
                    PonosButton.danger(label: 'Delete', onPressed: _noop),
                    PonosIconButton(
                      icon: Icon(Icons.more_horiz),
                      semanticLabel: 'More actions',
                      onPressed: _noop,
                    ),
                    PonosButton.primary(label: 'Disabled', onPressed: null),
                  ],
                ),
              ),
              const _Section(
                title: 'Inline tabs',
                child: PonosInlineTabs(
                  tabs: ['Focus Areas', 'Special Activities'],
                  selectedIndex: 0,
                  onSelected: _select,
                ),
              ),
              const _Section(
                title: 'Picker chips',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    PonosPickerChip(
                      label: 'Test',
                      selected: true,
                      onPressed: _noop,
                    ),
                    PonosPickerChip(label: 'Choose activity', onPressed: _noop),
                  ],
                ),
              ),
              const _Section(
                title: 'Date trigger',
                child: PonosDateTrigger(
                  label: '2 October 2026',
                  onPressed: _noop,
                ),
              ),
              const _Section(
                title: 'Duration stepper',
                child: PonosDurationStepper(
                  value: Duration(minutes: 25),
                  onChanged: _duration,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    ),
  );
}

void _noop() {}
void _select(int _) {}
void _duration(Duration _) {}
