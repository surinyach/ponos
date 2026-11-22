import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';

/// The decorative Ponos emblem; the application name remains separate text.
class PonosLogo extends StatelessWidget {
  const PonosLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.ponosLogo,
    width: size,
    height: size,
    fit: BoxFit.contain,
    color: AppColors.brandBronze,
    colorBlendMode: BlendMode.srcIn,
    excludeFromSemantics: true,
  );
}
