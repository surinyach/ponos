import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final light = _buildLight();

  static ThemeData _buildLight() {
    final colors =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.surfaceTinted,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.accent,
          onSecondary: AppColors.primaryDark,
          secondaryContainer: AppColors.surfaceTinted,
          onSecondaryContainer: AppColors.primaryDark,
          tertiary: AppColors.accent,
          onTertiary: AppColors.primaryDark,
          error: AppColors.error,
          onError: AppColors.white,
          surface: AppColors.background,
          onSurface: AppColors.primaryDark,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.textSecondary,
          outlineVariant: AppColors.border,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.primaryDark,
          onInverseSurface: AppColors.white,
          inversePrimary: AppColors.surfaceTinted,
          surfaceContainerLowest: AppColors.white,
          surfaceContainerLow: AppColors.white,
          surfaceContainer: AppColors.surfaceTinted,
          surfaceContainerHigh: AppColors.surfaceTinted,
          surfaceContainerHighest: AppColors.border,
        );
    final textTheme = AppTypography.textTheme(colors.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        elevation: 0,
        indicatorColor: AppColors.surfaceTinted,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.surfaceTinted,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.minimumTouchTarget),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.minimumTouchTarget),
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          side: const BorderSide(color: AppColors.border),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceTinted,
        circularTrackColor: AppColors.surfaceTinted,
      ),
    );
  }
}
