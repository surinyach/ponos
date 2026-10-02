import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_breakpoints.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_widgets.dart';

import 'support/ponos_components_specimen.dart';

const boundaryWidths = <double>[
  360,
  390,
  599,
  600,
  768,
  839,
  840,
  1024,
  1199,
  1200,
  1440,
];

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load(AppAssets.interVariable));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await inter.load();
    await materialIcons.load();
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  test('semantic breakpoint boundaries are exact', () {
    final expected = <AppLayoutSize>[
      AppLayoutSize.compact,
      AppLayoutSize.compact,
      AppLayoutSize.compact,
      AppLayoutSize.medium,
      AppLayoutSize.medium,
      AppLayoutSize.medium,
      AppLayoutSize.expanded,
      AppLayoutSize.expanded,
      AppLayoutSize.expanded,
      AppLayoutSize.expanded,
      AppLayoutSize.expanded,
    ];
    for (var index = 0; index < boundaryWidths.length; index++) {
      expect(
        AppBreakpoints.layoutFor(boundaryWidths[index]),
        expected[index],
        reason: '${boundaryWidths[index]} px',
      );
    }
    expect(AppBreakpoints.usesExpandedSidebar(1199), isFalse);
    expect(AppBreakpoints.usesExpandedSidebar(1200), isTrue);
  });

  testWidgets('shared specimen has no overflow at every boundary width', (
    tester,
  ) async {
    for (final width in boundaryWidths) {
      await tester.binding.setSurfaceSize(Size(width, 2400));
      await tester.pumpWidget(const PonosComponentsSpecimenApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: '$width px');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('all primitive controls preserve 48 px interaction targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    await tester.pumpWidget(
      app(
        const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PonosButton.primary(label: 'Primary', onPressed: _noop),
              PonosButton.secondary(label: 'Secondary', onPressed: _noop),
              PonosButton.ghost(label: 'Ghost', onPressed: _noop),
              PonosButton.danger(label: 'Danger', onPressed: _noop),
              PonosIconButton(
                icon: Icon(Icons.more_horiz),
                semanticLabel: 'More',
                onPressed: _noop,
              ),
              PonosInlineTabs(
                tabs: ['Active', 'Archived'],
                selectedIndex: 0,
                onSelected: _select,
              ),
              PonosPickerChip(label: 'Test', selected: true, onPressed: _noop),
              PonosDateTrigger(label: '2 October 2026', onPressed: _noop),
              PonosDurationStepper(
                value: Duration(minutes: 25),
                onChanged: _duration,
              ),
            ],
          ),
        ),
      ),
    );
    for (final element in find.byType(ButtonStyleButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minimumTouchTarget));
    }
    for (final element in find.byType(IconButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minimumTouchTarget));
      expect(size.width, greaterThanOrEqualTo(AppSpacing.minimumTouchTarget));
    }
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('keyboard traversal activates controls in visual order', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PonosButton.primary(
              label: 'Button',
              onPressed: () => activations++,
            ),
            PonosPickerChip(label: 'Picker', onPressed: () => activations++),
            PonosDateTrigger(label: 'Date', onPressed: () => activations++),
          ],
        ),
      ),
    );
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }
    expect(activations, 3);
  });

  testWidgets('focus states and non-color selection cues are explicit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PonosButton.primary(label: 'Action', onPressed: _noop),
            PonosInlineTabs(
              tabs: ['Selected', 'Other'],
              selectedIndex: 0,
              onSelected: _select,
            ),
            PonosPickerChip(label: 'Chosen', selected: true, onPressed: _noop),
          ],
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style!.side!.resolve({WidgetState.focused}),
      const BorderSide(color: AppColors.accent, width: 2),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    final selectedTab = tester.getSemantics(find.text('Selected'));
    final selectedChip = tester.getSemantics(find.text('Chosen'));
    expect(selectedTab.flagsCollection.isSelected.name, 'isTrue');
    expect(selectedChip.flagsCollection.isSelected.name, 'isTrue');
    semantics.dispose();
  });

  testWidgets('page backgrounds are excluded from semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        PonosPageScaffold(
          background: Semantics(
            label: 'Decorative background',
            child: const ColoredBox(color: AppColors.surfaceTinted),
          ),
          child: const Text('Content'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Decorative background'), findsNothing);
    expect(find.text('Content'), findsOneWidget);
    semantics.dispose();
  });
}

void _noop() {}
void _select(int _) {}
void _duration(Duration _) {}
