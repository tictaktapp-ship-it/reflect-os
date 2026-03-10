import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';

/// Draws a circular health gauge dial.
/// [value] is 0–100.
class DialPainter extends CustomPainter {
  DialPainter({required this.value, required this.animationValue});

  final int value;
  final double animationValue;

  Color get _fillColor {
    if (value >= 75) return AppColors.success;
    if (value >= 40) return AppColors.warning;
    return AppColors.destructive;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.shortestSide * 0.42;
    const strokeWidth = 10.0;
    const gapDegrees = 60.0;

    final trackPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = _fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Arc spans 360° minus gap, starting from bottom-left gap
    final startAngle =
        math.pi / 2 + (gapDegrees / 2) * (math.pi / 180);
    final totalSweep =
        (2 * math.pi) - (gapDegrees * (math.pi / 180));

    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    final sweep = totalSweep * (value / 100) * animationValue;
    canvas.drawArc(rect, startAngle, sweep, false, fillPaint);

    // Center text
    final numSpan = TextSpan(
      text: '$value',
      style: TextStyle(
        color: _fillColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
    final np = TextPainter(
      text: numSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    np.paint(canvas, Offset(cx - np.width / 2, cy - np.height / 2 - 6));

    final labelSpan = TextSpan(
      text: 'health',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
      ),
    );
    final lp = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(cx - lp.width / 2, cy + np.height / 2 - 4));
  }

  @override
  bool shouldRepaint(DialPainter old) =>
      old.value != value || old.animationValue != animationValue;
}
