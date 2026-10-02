enum AppLayoutSize { compact, medium, expanded }

/// Semantic responsive thresholds for Ponos layouts.
abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double expandedSidebar = 1200;

  static AppLayoutSize layoutFor(double width) {
    if (width >= expanded) return AppLayoutSize.expanded;
    if (width >= medium) return AppLayoutSize.medium;
    return AppLayoutSize.compact;
  }

  static bool usesExpandedSidebar(double width) => width >= expandedSidebar;
}
