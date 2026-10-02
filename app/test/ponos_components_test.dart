import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_radius.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/widgets/ponos_widgets.dart';

import 'support/ponos_components_specimen.dart';

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
      child: child,
    ),
  );

  testWidgets('page scaffold applies semantic margins and content maximum', (
    tester,
  ) async {
    for (final (width, margin) in [
      (390.0, 16.0),
      (768.0, 24.0),
      (1440.0, 32.0),
    ]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      await tester.pumpWidget(
        app(
          const PonosPageScaffold(
            child: SizedBox(key: Key('content'), width: double.infinity),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const Key('content')));
      expect(rect.left, width <= 1200 ? margin : (width - 1200) / 2 + margin);
      expect(rect.width, lessThanOrEqualTo(1200 - margin * 2));
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('section header stacks only at the compact breakpoint', (
    tester,
  ) async {
    for (final (width, type) in [
      (390.0, Column),
      (768.0, Row),
      (1440.0, Row),
    ]) {
      await tester.binding.setSurfaceSize(Size(width, 400));
      await tester.pumpWidget(
        app(
          const PonosSectionHeader(
            title: 'Title',
            description: 'Description',
            trailing: PonosButton.ghost(label: 'Action', onPressed: _noop),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PonosSectionHeader),
          matching: find.byType(type),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('card uses approved radius, border and padding variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PonosCard(child: Text('Standard')),
            PonosCard(
              padding: PonosCardPadding.compact,
              child: Text('Compact'),
            ),
          ],
        ),
      ),
    );
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final cardDecorations = boxes
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.borderRadius == AppRadius.card);
    expect(cardDecorations, hasLength(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.all(AppSpacing.cardPaddingExpanded),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.all(AppSpacing.cardPaddingCompact),
      ),
      findsOneWidget,
    );
  });

  testWidgets('state panels render loading, illustration and retry action', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        Column(
          children: [
            const PonosStatePanel.loading(),
            const PonosStatePanel.empty(
              title: 'Empty',
              illustrationAsset: AppAssets.emptyWorkLog,
            ),
            PonosStatePanel.error(
              title: 'Error',
              actionLabel: 'Retry',
              onAction: () => retried = true,
            ),
          ],
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('metrics and badges expose complete non-color semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            PonosMetricTile(
              label: 'Focused time',
              value: '2h',
              supportingText: 'Today',
            ),
            WorkAreaBadge(type: WorkAreaType.focusArea),
            WorkAreaBadge(type: WorkAreaType.specialActivity),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Focused time'), findsOneWidget);
    expect(find.bySemanticsLabel('Work area type: Focus Area'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Work area type: Special Activity'),
      findsOneWidget,
    );
    expect(find.text('Focus Area'), findsOneWidget);
    expect(find.text('Special Activity'), findsOneWidget);
    semantics.dispose();
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('specimen renders at ${width.toInt()} px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1900));
      await tester.pumpWidget(const PonosComponentsSpecimenApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(PonosComponentsSpecimen),
        matchesGoldenFile('goldens/ponos_components_${width.toInt()}.png'),
      );
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('specimen supports 200 percent text scaling', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    await tester.pumpWidget(app(const PonosComponentsSpecimen(), textScale: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PonosComponentsSpecimen),
      matchesGoldenFile('goldens/ponos_components_390_200.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
