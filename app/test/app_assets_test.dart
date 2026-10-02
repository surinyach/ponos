import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/theme/app_assets.dart';

import 'support/ponos_asset_specimen.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load(AppAssets.interVariable));
    await inter.load();
  });

  testWidgets('every production SVG resolves and renders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final path in AppAssets.all) {
      final source = await rootBundle.loadString(path);
      expect(source, contains('<svg'), reason: path);
    }

    await tester.pumpWidget(const PonosAssetSpecimen());
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(AppAssets.all.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background SVGs cover representative layout widths', (
    tester,
  ) async {
    for (final width in <double>[390, 768, 1440]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      final asset = width < 840
          ? AppAssets.appCanvasMobile
          : AppAssets.appCanvasDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: SvgPicture.asset(
              asset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(SvgPicture)), Size(width, 900));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('asset specimen matches the inspection baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PonosAssetSpecimen());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ponos-asset-specimen')),
      matchesGoldenFile('goldens/ponos_asset_specimen.png'),
    );
  });
}
