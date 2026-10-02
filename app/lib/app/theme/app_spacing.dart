import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Approved spacing tokens based on a four-point grid.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const double cardPaddingCompact = md;
  static const double cardPaddingExpanded = lg;
  static const double screenMarginCompact = md;
  static const double screenMarginMedium = lg;
  static const double screenMarginExpanded = xl;
  static const double controlVisualHeight = 38;
  static const double minimumTouchTarget = 48;

  /// Compact fallback retained until feature layouts adopt adaptive margins.
  static const pagePadding = EdgeInsets.all(screenMarginCompact);

  static double screenMarginFor(double width) {
    if (width >= AppBreakpoints.expanded) return screenMarginExpanded;
    if (width >= AppBreakpoints.medium) return screenMarginMedium;
    return screenMarginCompact;
  }

  static EdgeInsets pagePaddingFor(double width) =>
      EdgeInsets.all(screenMarginFor(width));
}
