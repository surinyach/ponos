import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_controls.dart';

import 'support/ponos_controls_specimen.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load(AppAssets.interVariable));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await inter.load();
    await materialIcons.load();
  });

  Widget app(Widget child, {double textScale = 1}) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('button variants invoke actions and disabled stays inactive', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      app(
        Wrap(
          children: [
            PonosButton.primary(label: 'Primary', onPressed: () => presses++),
            PonosButton.secondary(
              label: 'Secondary',
              onPressed: () => presses++,
            ),
            PonosButton.ghost(label: 'Ghost', onPressed: () => presses++),
            PonosButton.danger(label: 'Danger', onPressed: () => presses++),
            const PonosButton.primary(label: 'Disabled', onPressed: null),
          ],
        ),
      ),
    );
    for (final label in ['Primary', 'Secondary', 'Ghost', 'Danger']) {
      await tester.tap(find.text(label));
    }
    await tester.tap(find.text('Disabled'));
    expect(presses, 4);
    for (final button in find.byType(ButtonStyleButton).evaluate()) {
      expect(
        tester.getSize(find.byWidget(button.widget)).height,
        greaterThanOrEqualTo(AppSpacing.minimumTouchTarget),
      );
    }
  });

  testWidgets('buttons define hover, pressed, focused and disabled styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const PonosButton.primary(label: 'Action', onPressed: _noop)),
    );
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    expect(style.backgroundColor!.resolve({WidgetState.hovered}), isNotNull);
    expect(style.backgroundColor!.resolve({WidgetState.pressed}), isNotNull);
    expect(
      style.side!.resolve({WidgetState.focused}),
      const BorderSide(color: Color(0xFFB78A55), width: 2),
    );
    expect(
      style.backgroundColor!.resolve({WidgetState.disabled}),
      isNot(equals(style.backgroundColor!.resolve({}))),
    );
  });

  testWidgets('inline tabs expose selection and support keyboard activation', (
    tester,
  ) async {
    var selected = -1;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        PonosInlineTabs(
          tabs: const ['Active', 'Archived'],
          selectedIndex: 0,
          onSelected: (value) => selected = value,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Active')),
      matchesSemantics(
        label: 'Active',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 1);
    semantics.dispose();
  });

  testWidgets('picker, date and icon controls expose semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PonosPickerChip(
              label: 'Test',
              semanticLabel: 'Selected activity',
              selected: true,
              onPressed: _noop,
            ),
            PonosDateTrigger(label: '2 October 2026', onPressed: _noop),
            PonosIconButton(
              icon: Icon(Icons.more_horiz),
              semanticLabel: 'More actions',
              onPressed: _noop,
            ),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Selected activity'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Choose date, 2 October 2026'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('More actions'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('duration stepper respects bounds and announces controls', (
    tester,
  ) async {
    var value = const Duration(minutes: 5);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => PonosDurationStepper(
            value: value,
            minimum: Duration.zero,
            maximum: const Duration(minutes: 10),
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Increase Duration by 5m'));
    await tester.pump();
    expect(find.text('10m'), findsOneWidget);
    expect(find.byTooltip('Increase Duration by 5m'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease Duration by 5m'));
    await tester.pump();
    expect(find.text('5m'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('controls remain usable at 200 percent text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(app(const PonosControlsSpecimen(), textScale: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(PonosButton), findsNWidgets(5));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('control specimen matches golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1100));
    await tester.pumpWidget(const PonosControlsSpecimenApp());
    await expectLater(
      find.byType(PonosControlsSpecimen),
      matchesGoldenFile('goldens/ponos_controls_specimen.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
