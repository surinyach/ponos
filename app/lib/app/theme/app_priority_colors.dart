import 'package:flutter/material.dart';

@immutable
class PriorityColors {
  const PriorityColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

/// Approved visual priority palette.
///
/// Priority remains a numeric business value. Every value from P5 onward
/// shares the same muted-sage visual tier while retaining its real label.
abstract final class AppPriorityColors {
  static const p1 = PriorityColors(
    background: Color(0xFFFFB4B8),
    foreground: Color(0xFF971B2B),
    border: Color(0xFFDE4050),
  );
  static const p2 = PriorityColors(
    background: Color(0xFFFFCEB0),
    foreground: Color(0xFF91421C),
    border: Color(0xFFEA8854),
  );
  static const p3 = PriorityColors(
    background: Color(0xFFFCE0AF),
    foreground: Color(0xFF825214),
    border: Color(0xFFDDA34D),
  );
  static const p4 = PriorityColors(
    background: Color(0xFFF4E6AF),
    foreground: Color(0xFF685522),
    border: Color(0xFFD1B95D),
  );
  static const p5AndHigher = PriorityColors(
    background: Color(0xFFDDE7DD),
    foreground: Color(0xFF3E5642),
    border: Color(0xFFA2B5A4),
  );

  static PriorityColors forPriority(int priority) => switch (priority) {
    <= 1 => p1,
    2 => p2,
    3 => p3,
    4 => p4,
    _ => p5AndHigher,
  };
}
