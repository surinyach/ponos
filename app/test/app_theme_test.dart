import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponos_app/app/theme/app_breakpoints.dart';
import 'package:ponos_app/app/theme/app_colors.dart';
import 'package:ponos_app/app/theme/app_radius.dart';
import 'package:ponos_app/app/theme/app_spacing.dart';
import 'package:ponos_app/app/theme/app_theme.dart';
import 'package:ponos_app/app/theme/app_typography.dart';

void main() {
  test('light theme exposes the approved Aegean palette', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onSurface, AppColors.primaryDark);
    expect(theme.colorScheme.surface, AppColors.background);
    expect(theme.colorScheme.surfaceContainerLow, AppColors.white);
    expect(theme.colorScheme.outlineVariant, AppColors.border);
  });

  test('theme uses the approved Inter type scale', () {
    final text = AppTheme.light.textTheme;

    expect(text.displayLarge?.fontFamily, AppTypography.fontFamily);
    expect(text.displayLarge?.fontSize, 32);
    expect(text.displayLarge?.fontWeight, FontWeight.w700);
    expect(text.headlineMedium?.fontSize, 26);
    expect(text.headlineSmall?.fontSize, 20);
    expect(text.titleMedium?.fontSize, 16);
    expect(text.bodyLarge?.fontSize, 16);
    expect(text.labelLarge?.fontSize, 14);
    expect(text.bodySmall?.fontSize, 12);
    expect(AppTypography.selectorLabelSize, 13);
  });

  test('spacing and breakpoints match the approved references', () {
    expect(AppSpacing.xxxl, 64);
    expect(AppSpacing.minimumTouchTarget, 48);
    expect(AppBreakpoints.layoutFor(599), AppLayoutSize.compact);
    expect(AppBreakpoints.layoutFor(600), AppLayoutSize.medium);
    expect(AppBreakpoints.layoutFor(839), AppLayoutSize.medium);
    expect(AppBreakpoints.layoutFor(840), AppLayoutSize.expanded);
    expect(AppBreakpoints.usesExpandedSidebar(1199), isFalse);
    expect(AppBreakpoints.usesExpandedSidebar(1200), isTrue);
    expect(AppSpacing.screenMarginFor(599), 16);
    expect(AppSpacing.screenMarginFor(600), 24);
    expect(AppSpacing.screenMarginFor(840), 32);
  });

  test('control and card radii use the approved shapes', () {
    expect(AppRadius.control.topLeft.x, 10);
    expect(AppRadius.card.topLeft.x, 16);
    expect(AppRadius.pill.topLeft.x, 999);

    final buttonShape = AppTheme.light.filledButtonTheme.style?.shape?.resolve(
      const <WidgetState>{},
    );
    expect(buttonShape, isA<RoundedRectangleBorder>());
    expect(
      (buttonShape! as RoundedRectangleBorder).borderRadius,
      AppRadius.control,
    );
  });
}
