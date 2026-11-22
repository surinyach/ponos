import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Decorative progress drawn directly from the current timer state.
class TimerLaurel extends StatelessWidget {
  const TimerLaurel({super.key, required this.progress, required this.isRest});

  final double progress;
  final bool isRest;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      key: const Key('timer-laurel'),
      painter: TimerLaurelPainter(
        progress: progress.clamp(0.0, 1.0),
        isRest: isRest,
      ),
    ),
  );
}

class TimerLaurelPainter extends CustomPainter {
  const TimerLaurelPainter({required this.progress, required this.isRest});

  final double progress;
  final bool isRest;

  // Left branch from the approved 320×320 master; the right is mirrored.
  static const _leaves = <List<double>>[
    [81.6, 244.1, 67.9, 236.8, 57.5, 244.9, 70.1, 259.4],
    [68.7, 229.9, 56.4, 220.4, 44.8, 226.7, 54.8, 243.0],
    [58.3, 213.7, 47.8, 202.3, 35.4, 206.6, 42.5, 224.4],
    [50.8, 196.1, 42.3, 183.1, 29.3, 185.3, 33.4, 203.9],
    [46.3, 177.4, 40.1, 163.2, 26.9, 163.2, 27.8, 182.3],
    [45.0, 158.3, 41.2, 143.2, 28.3, 141.0, 26.0, 160.0],
    [46.9, 139.2, 45.7, 123.7, 33.3, 119.4, 27.9, 137.7],
    [51.9, 120.7, 53.3, 105.2, 41.8, 98.9, 33.4, 116.0],
    [60.0, 103.2, 63.9, 88.2, 53.6, 80.1, 42.5, 95.6],
    [70.8, 87.4, 77.2, 73.2, 68.4, 63.5, 54.8, 77.0],
    [84.1, 73.6, 92.8, 60.7, 85.7, 49.6, 70.1, 60.6],
    [99.5, 62.2, 110.2, 50.9, 105.1, 38.8, 87.9, 47.1],
    [116.7, 53.5, 129.0, 44.1, 126.0, 31.3, 107.6, 36.6],
    [135.0, 47.8, 148.7, 40.6, 147.9, 27.5, 128.9, 29.6],
    [154.0, 45.2, 168.8, 40.4, 170.1, 27.3, 151.0, 26.3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 320;
    canvas.save();
    canvas.translate(
      (size.width - 320 * scale) / 2,
      (size.height - 320 * scale) / 2,
    );
    canvas.scale(scale);
    final stem = Paint()
      ..color = AppColors.accent.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(320, 0);
        canvas.scale(-1, 1);
      }
      final branch = Path()
        ..moveTo(85, 250)
        ..cubicTo(5, 178, 45, 47, 152, 43);
      canvas.drawPath(branch, stem);
      final litCount = (progress * _leaves.length).round();
      for (var i = 0; i < _leaves.length; i++) {
        final p = _leaves[i];
        final leaf = Path()
          ..moveTo(p[0], p[1])
          ..quadraticBezierTo(p[2], p[3], p[4], p[5])
          ..quadraticBezierTo(p[6], p[7], p[0], p[1])
          ..close();
        canvas.drawPath(
          leaf,
          Paint()
            ..color = i < litCount ? AppColors.accent : const Color(0xFFE1E4E4),
        );
      }
      canvas.restore();
    }
    final track = Paint()
      ..color = AppColors.surfaceTinted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const center = Offset(160, 160);
    canvas.drawCircle(center, 100, track);
    if (progress > 0) {
      final phaseColor = isRest ? AppColors.accent : AppColors.primary;
      final arc = Paint()
        ..color = phaseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 100),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arc,
      );
      final angle = -math.pi / 2 + 2 * math.pi * progress;
      canvas.drawCircle(
        center + Offset(100 * math.cos(angle), 100 * math.sin(angle)),
        3,
        Paint()..color = phaseColor,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TimerLaurelPainter oldDelegate) =>
      progress != oldDelegate.progress || isRest != oldDelegate.isRest;
}
