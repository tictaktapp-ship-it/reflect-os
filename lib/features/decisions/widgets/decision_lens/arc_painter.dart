import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';

/// Draws a semicircular confidence arc.
/// [value] is 0.0–1.0 (maps to full arc sweep).
class ArcPainter extends CustomPainter {
  ArcPainter({required this.value, required this.animationValue});

  /// Normalised 0.0–1.0
  final double value;

  /// Animation progress 0.0–1.0
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = size.width * 0.42;
    const strokeWidth = 12.0;

    final trackPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track: 180° semicircle from 180° to 360° (left to right)
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // Fill: animated
    final sweep = math.pi * value * animationValue;
    canvas.drawArc(rect, math.pi, sweep, false, fillPaint);

    // Label
    final displayValue = (value * 10).toStringAsFixed(1);
    final textSpan = TextSpan(
      text: displayValue,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, cy - tp.height / 2 - 4),
    );

    final labelSpan = TextSpan(
      text: 'confidence',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
      ),
    );
    final lp = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(
      canvas,
      Offset(cx - lp.width / 2, cy + tp.height / 2 - 2),
    );
  }

  @override
  bool shouldRepaint(ArcPainter old) =>
      old.value != value || old.animationValue != animationValue;
}
