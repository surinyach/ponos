import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/navigation/ponos_adaptive_shell.dart';
import 'package:ponos_app/app/navigation/ponos_destination.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';

import 'support/ponos_navigation_specimen.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load(AppAssets.interVariable));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await inter.load();
    await materialIcons.load();
  });

  testWidgets('uses bottom navigation at 599 px', (tester) async {
    await _pumpAtWidth(tester, 599);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses collapsed rail at 600 px', (tester) async {
    await _pumpAtWidth(tester, 600);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(find.byType(NavigationBar), findsNothing);
    expect(rail.extended, isFalse);
  });

  testWidgets('uses collapsed rail at 1199 px', (tester) async {
    await _pumpAtWidth(tester, 1199);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('uses extended rail at 1200 px', (tester) async {
    await _pumpAtWidth(tester, 1200);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('desktop keeps lateral navigation below 600 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ShellHost(platform: TargetPlatform.windows));

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('uses the correct mode at every validation width', (
    tester,
  ) async {
    for (final width in <double>[
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
    ]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(const _ShellHost());
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'Overflow at $width px');
      if (width < 600) {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(find.byType(NavigationBar), findsNothing);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, width >= 1200, reason: 'Failed at $width px');
      }

      final contentRect = tester.getRect(
        find.byKey(const Key('page-overview')),
      );
      expect(contentRect.right, width);
      expect(contentRect.width, greaterThan(0));
      expect(contentRect.height, greaterThan(0));
    }
  });

  testWidgets('content sizing only jumps at intended navigation transitions', (
    tester,
  ) async {
    Future<Rect> contentAt(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(const _ShellHost());
      await tester.pumpAndSettle();
      return tester.getRect(find.byKey(const Key('page-overview')));
    }

    final compact = await contentAt(599);
    final collapsedStart = await contentAt(600);
    final collapsedEnd = await contentAt(1199);
    final expanded = await contentAt(1200);

    expect(compact.left, 0);
    expect(collapsedStart.left, collapsedEnd.left);
    expect(collapsedStart.left, greaterThan(compact.left));
    expect(expanded.left, greaterThan(collapsedEnd.left));
  });

  testWidgets('shows restrained branding only in the expanded sidebar', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 1199);
    expect(find.byKey(const Key('ponos-expanded-rail-brand')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ponos-expanded-rail-brand')), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('selected destination has icon and weight cues beyond color', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 390);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final overview = navigation.destinations.first as NavigationDestination;
    final icon = (overview.icon as dynamic).icon as IconData;
    final selectedIcon = (overview.selectedIcon! as dynamic).icon as IconData;
    expect(icon, PonosDestination.overview.icon);
    expect(selectedIcon, PonosDestination.overview.selectedIcon);

    final theme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(
      theme.labelTextStyle?.resolve({WidgetState.selected})?.fontWeight,
      FontWeight.w600,
    );
    expect(
      theme.labelTextStyle?.resolve(<WidgetState>{})?.fontWeight,
      FontWeight.w400,
    );
  });

  testWidgets('navigation supports 200 percent text scaling at all modes', (
    tester,
  ) async {
    for (final width in <double>[390, 768, 1440]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _ShellHost(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Failed at $width px');
    }
  });

  testWidgets('navigation exposes a visible keyboard focus treatment', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 768);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    final hasFocusBorder = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .any((widget) => (widget.decoration as BoxDecoration?)?.border != null);
    expect(hasFocusBorder, isTrue);
  });

  testWidgets('navigation icon states share centered interaction geometry', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 768);
    for (final selected in PonosDestination.values) {
      await tester.tap(find.text(selected.label));
      await tester.pump();

      for (final destination in PonosDestination.values) {
        final state = destination == selected ? 'selected' : 'default';
        expect(
          tester.getSize(
            find.byKey(Key('navigation-${destination.name}-$state')),
          ),
          const Size.square(AppSpacing.minimumTouchTarget),
        );
      }
    }
  });

  testWidgets('rail hover focus and press keep destination bounds stable', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 768);
    final overview = find.byKey(const Key('navigation-overview-selected'));
    final initialRect = tester.getRect(overview);
    final mouse = TestPointer(1, ui.PointerDeviceKind.mouse);

    await tester.sendEventToBinding(mouse.hover(initialRect.center));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(overview), initialRect);
    final hoveredSurface = tester.widget<AnimatedContainer>(
      find.descendant(of: overview, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (hoveredSurface.decoration! as BoxDecoration).color,
      Color.alphaBlend(
        AppColors.accent.withValues(alpha: 0.12),
        AppColors.surfaceTinted,
      ),
    );

    await tester.sendEventToBinding(mouse.down(initialRect.center));
    await tester.pump();
    expect(tester.getRect(overview), initialRect);
    await tester.sendEventToBinding(mouse.up());
    await tester.sendEventToBinding(mouse.hover(const Offset(500, 500)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(overview), initialRect);
    final exitedSurface = tester.widget<AnimatedContainer>(
      find.descendant(of: overview, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (exitedSurface.decoration! as BoxDecoration).color,
      AppColors.surfaceTinted,
    );

    await tester.sendEventToBinding(mouse.hover(initialRect.center));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(overview), initialRect);
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.sendEventToBinding(mouse.hover(const Offset(500, 500)));
    await tester.pump();
  });

  testWidgets('keyboard traversal activates a destination', (tester) async {
    await _pumpAtWidth(tester, 768);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Work Areas page'), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      PonosDestination.workAreas.index,
    );
  });

  testWidgets('navigation meets touch target and selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final width in <double>[390, 768, 1440]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(const _ShellHost());
        await tester.pumpAndSettle();

        final overviewSemantics = tester.getSemantics(find.text('Overview'));
        expect(
          overviewSemantics.flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        expect(
          overviewSemantics.rect.width,
          greaterThanOrEqualTo(48),
          reason: 'Failed at $width px',
        );
        expect(
          overviewSemantics.rect.height,
          greaterThanOrEqualTo(48),
          reason: 'Failed at $width px',
        );
        for (final destination in PonosDestination.values) {
          expect(find.text(destination.label), findsOneWidget);
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('expanded branding is excluded from semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpAtWidth(tester, 1200);
      expect(
        find.bySemanticsLabel(RegExp('ponos', caseSensitive: false)),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('expanded destinations start directly below branding', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 1440);
    final brand = tester.getRect(
      find.byKey(const Key('ponos-expanded-rail-brand')),
    );
    final overview = tester.getRect(find.text('Overview'));
    expect(overview.top, greaterThanOrEqualTo(brand.bottom));
    expect(overview.top - brand.bottom, lessThanOrEqualTo(AppSpacing.xl));
  });

  testWidgets('selects typed destinations and excludes Progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ShellHost());

    expect(PonosDestination.values, hasLength(4));
    expect(find.text('Progress'), findsNothing);
    await tester.tap(find.text('Focus'));
    await tester.pump();
    expect(find.text('Focus page'), findsOneWidget);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, PonosDestination.focus.index);
  });

  for (final (width, navigationType) in <(double, Type)>[
    (390, NavigationBar),
    (768, NavigationRail),
    (1440, NavigationRail),
  ]) {
    testWidgets('switches through every destination at ${width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const _ShellHost());

      for (final destination in PonosDestination.values) {
        await tester.tap(find.text(destination.label));
        await tester.pump();
        expect(find.text('${destination.label} page'), findsOneWidget);
        final selectedIndex = navigationType == NavigationBar
            ? tester
                  .widget<NavigationBar>(find.byType(NavigationBar))
                  .selectedIndex
            : tester
                  .widget<NavigationRail>(find.byType(NavigationRail))
                  .selectedIndex;
        expect(selectedIndex, destination.index);
      }
    });
  }

  testWidgets('mounts destinations lazily', (tester) async {
    final builds = <PonosDestination, int>{};
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_ShellHost(builds: builds));

    expect(builds, {PonosDestination.overview: 1});
    await tester.tap(find.text('Work Areas'));
    await tester.pump();
    expect(builds[PonosDestination.overview], 1);
    expect(builds[PonosDestination.workAreas], 1);
    expect(builds.containsKey(PonosDestination.focus), isFalse);
    expect(builds.containsKey(PonosDestination.logWork), isFalse);
  });

  testWidgets('preserves visited state and disables hidden tickers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ShellHost());

    await tester.tap(find.byKey(const Key('increment-overview')));
    await tester.pump();
    expect(find.text('Overview count: 1'), findsOneWidget);

    await tester.tap(find.text('Work Areas'));
    await tester.pump();
    final overviewContext = tester.element(
      find.byKey(const Key('page-overview'), skipOffstage: false),
    );
    expect(TickerMode.valuesOf(overviewContext).enabled, isFalse);

    await tester.tap(find.text('Overview'));
    await tester.pump();
    expect(find.text('Overview count: 1'), findsOneWidget);
    expect(
      TickerMode.valuesOf(
        tester.element(find.byKey(const Key('page-overview'))),
      ).enabled,
      isTrue,
    );
  });

  testWidgets('hidden destinations cannot retain or receive focus', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 768);
    await tester.tap(find.text('Work Areas'));
    await tester.pump();
    final focusGuard = tester.widget<ExcludeFocus>(
      find
          .ancestor(
            of: find.byKey(const Key('page-overview'), skipOffstage: false),
            matching: find.byType(ExcludeFocus, skipOffstage: false),
          )
          .first,
    );
    expect(focusGuard.excluding, isTrue);
  });

  testWidgets('preserves local state for Work Areas, Focus, and Log Work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ShellHost());

    for (final destination in <PonosDestination>[
      PonosDestination.workAreas,
      PonosDestination.focus,
      PonosDestination.logWork,
    ]) {
      await tester.tap(find.text(destination.label));
      await tester.pump();
      await tester.tap(find.byKey(Key('increment-${destination.name}')));
      await tester.pump();
    }

    await tester.tap(find.text('Overview'));
    await tester.pump();

    for (final destination in <PonosDestination>[
      PonosDestination.workAreas,
      PonosDestination.focus,
      PonosDestination.logWork,
    ]) {
      await tester.tap(find.text(destination.label));
      await tester.pump();
      expect(find.text('${destination.label} count: 1'), findsOneWidget);
    }
  });

  testWidgets('nested push and pop preserve the selected root destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ShellHost());

    await tester.tap(find.text('Work Areas'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-nested-workAreas')));
    await tester.pumpAndSettle();
    expect(find.text('Nested form'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-nested')));
    await tester.pumpAndSettle();
    expect(find.text('Work Areas page'), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      PonosDestination.workAreas.index,
    );
  });

  for (final (width, height) in <(double, double)>[
    (390, 844),
    (768, 900),
    (1440, 900),
  ]) {
    testWidgets('navigation specimen matches ${width.toInt()} px golden', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const PonosNavigationSpecimenApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(PonosAdaptiveShell),
        matchesGoldenFile('goldens/ponos_navigation_${width.toInt()}.png'),
      );
    });
  }
}

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const _ShellHost());
}

class _ShellHost extends StatefulWidget {
  const _ShellHost({this.builds, this.platform = TargetPlatform.android});

  final Map<PonosDestination, int>? builds;
  final TargetPlatform platform;

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  PonosDestination selected = PonosDestination.overview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light.copyWith(platform: widget.platform),
      home: PonosAdaptiveShell(
        selectedDestination: selected,
        onDestinationSelected: (destination) {
          setState(() => selected = destination);
        },
        destinationBuilder: (destination) {
          widget.builds?.update(
            destination,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          return _StatefulPage(destination: destination);
        },
      ),
    );
  }
}

class _StatefulPage extends StatefulWidget {
  const _StatefulPage({required this.destination});

  final PonosDestination destination;

  @override
  State<_StatefulPage> createState() => _StatefulPageState();
}

class _StatefulPageState extends State<_StatefulPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    final name = widget.destination.name;
    return Center(
      key: Key('page-$name'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.destination.label} page'),
          Text('${widget.destination.label} count: $count'),
          FilledButton(
            key: Key('increment-$name'),
            onPressed: () => setState(() => count++),
            child: const Text('Increment'),
          ),
          FilledButton(
            key: Key('open-nested-$name'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _NestedPage()),
            ),
            child: const Text('Open nested'),
          ),
        ],
      ),
    );
  }
}

class _NestedPage extends StatelessWidget {
  const _NestedPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('close-nested'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Nested form'),
      ),
    ),
  );
}
