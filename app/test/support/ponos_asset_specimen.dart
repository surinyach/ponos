import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ponos_app/app/theme/app_assets.dart';
import 'package:ponos_app/app/theme/app_theme.dart';

/// Development/test-only gallery for inspecting every production SVG.
class PonosAssetSpecimen extends StatelessWidget {
  const PonosAssetSpecimen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _SpecimenBody(),
    );
  }
}

class _SpecimenBody extends StatelessWidget {
  const _SpecimenBody();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RepaintBoundary(
      key: const Key('ponos-asset-specimen'),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ponos production assets',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${AppAssets.all.length} scalable SVG assets',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    for (final asset in AppAssets.all) _AssetTile(asset: asset),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SvgPicture.asset(
                asset,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              asset.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
