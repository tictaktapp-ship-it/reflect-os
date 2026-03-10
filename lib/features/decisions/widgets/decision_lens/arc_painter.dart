import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/trigger_utils.dart';

typedef TriggerHitArea = ({
  Offset center,
  double radius,
  ConfidenceTrigger trigger
});

/// Draws a semicircular (arch) confidence gauge, optionally overlaid with
/// causal trigger markers and influence bands.
///
/// Arc geometry: starts at the left (angle = π), sweeps clockwise to the
/// right (angle = 2π), peaking at the top centre (angle = 1.5π).
/// arc_position 0.0 = left end, 1.0 = right end.
class ArcPainter extends CustomPainter {
  ArcPainter({
    required this.value,
    required this.animationValue,
    this.triggers = const [],
    this.showTriggerMarkers = false,
    this.showInfluenceBands = false,
    this.showLabel = true,
    this.onHitAreasUpdated,
  });

  /// Normalised confidence 0.0–1.0
  final double value;

  /// Animation progress 0.0–1.0
  final double animationValue;

  final List<ConfidenceTrigger> triggers;
  final bool showTriggerMarkers;
  final bool showInfluenceBands;

  /// Show the numeric confidence label inside the arc. Set false for the
  /// full-width trajectory canvas where the label is shown separately.
  final bool showLabel;

  final void Function(List<TriggerHitArea>)? onHitAreasUpdated;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  /// Returns (cx, cy, radius) for the arc given the canvas size.
  /// Radius is clamped so the arc peak always has ≥20px clearance from the
  /// top of the canvas.
  (double cx, double cy, double radius) _arcGeometry(Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = math.min(size.width * 0.42, cy - 20);
    return (cx, cy, radius);
  }

  /// Maps arc_position (0.0–1.0) to the exact (x, y) on the arc surface.
  Offset _arcPointForPosition(double p, Size size) {
    final (cx, cy, radius) = _arcGeometry(size);
    final angle = math.pi + p * math.pi;
    return Offset(
      cx + radius * math.cos(angle),
      cy + radius * math.sin(angle),
    );
  }

  double _arcXForPosition(double p, Size size) =>
      _arcPointForPosition(p, size).dx;

  double _arcYForPosition(double p, Size size) =>
      _arcPointForPosition(p, size).dy;

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final (cx, cy, radius) = _arcGeometry(size);
    const strokeWidth = 12.0;
    const topPadding = 4.0;
    final plotHeight = cy - topPadding;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // 1. Influence bands — draw BEFORE the arc line
    if (showInfluenceBands && triggers.isNotEmpty) {
      for (final trigger in triggers) {
        final bandX = _arcXForPosition(trigger.arcPosition, size);
        final color = triggerColor(trigger.triggerType);
        final bandWidth = 28.0 + trigger.influenceStrength * 4.0;

        final gradient = ui.Gradient.linear(
          Offset(bandX - bandWidth / 2, 0),
          Offset(bandX + bandWidth / 2, 0),
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0),
          ],
          [0.0, 0.5, 1.0],
        );

        canvas.drawRect(
          Rect.fromLTWH(bandX - bandWidth / 2, topPadding, bandWidth, plotHeight),
          Paint()..shader = gradient,
        );
      }
    }

    // 2. Track arc
    final trackPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // 3. Fill arc (animated)
    final fillPaint = Paint()
      ..color = AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = math.pi * value * animationValue;
    canvas.drawArc(rect, math.pi, sweep, false, fillPaint);

    // 4. Centre label
    if (showLabel) {
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
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 4));

      final labelSpan = TextSpan(
        text: 'confidence',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      );
      final lp = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(cx - lp.width / 2, cy + tp.height / 2 - 2));
    }

    // 5. Trigger markers — draw AFTER arc line
    final hitAreas = <TriggerHitArea>[];

    if (showTriggerMarkers && triggers.isNotEmpty) {
      for (final trigger in triggers) {
        final arcX = _arcXForPosition(trigger.arcPosition, size);
        final arcY = _arcYForPosition(trigger.arcPosition, size);
        final color = triggerColor(trigger.triggerType);
        final markerRadius = 8.0 + trigger.influenceStrength * 1.2;

        // Float above the arc surface, clamped so marker stays on canvas
        final rawMarkerCY = arcY - markerRadius - 8.0;
        final markerCY = rawMarkerCY.clamp(markerRadius + 4, arcY - markerRadius - 2);

        hitAreas.add((center: Offset(arcX, markerCY), radius: markerRadius, trigger: trigger));

        // Stem from arc surface to marker bottom
        canvas.drawLine(
          Offset(arcX, arcY - 4),
          Offset(arcX, markerCY + markerRadius),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = 1.0,
        );

        // Marker background
        canvas.drawCircle(
          Offset(arcX, markerCY),
          markerRadius,
          Paint()..color = AppColors.backgroundSurface,
        );

        // Marker ring
        canvas.drawCircle(
          Offset(arcX, markerCY),
          markerRadius,
          Paint()
            ..color = color
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke,
        );

        // Icon
        final icon = triggerIcon(trigger.triggerType);
        final iconPainter = TextPainter(
          text: TextSpan(
            text: icon,
            style: TextStyle(
              fontSize: markerRadius * 0.85,
              color: color,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        iconPainter.paint(
          canvas,
          Offset(arcX - iconPainter.width / 2, markerCY - iconPainter.height / 2),
        );

        // Confidence delta label above marker
        final delta = trigger.confidenceDelta;
        if (delta != null && delta != 0) {
          final deltaLabel = delta > 0
              ? '+${delta.toStringAsFixed(0)}'
              : delta.toStringAsFixed(0);
          final deltaColor = delta > 0
              ? const Color(0xFF1A8C5E)
              : const Color(0xFFC13333);
          final deltaPainter = TextPainter(
            text: TextSpan(
              text: deltaLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: deltaColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          deltaPainter.paint(
            canvas,
            Offset(
              arcX - deltaPainter.width / 2,
              markerCY - markerRadius - deltaPainter.height - 2,
            ),
          );
        }
      }
    }

    // Report hit areas for tap detection
    onHitAreasUpdated?.call(hitAreas);
  }

  @override
  bool shouldRepaint(ArcPainter old) =>
      old.value != value ||
      old.animationValue != animationValue ||
      old.triggers != triggers ||
      old.showTriggerMarkers != showTriggerMarkers ||
      old.showInfluenceBands != showInfluenceBands ||
      old.showLabel != showLabel;
}
