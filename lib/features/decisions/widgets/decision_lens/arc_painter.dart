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

// ── Internal data point ────────────────────────────────────────────────────────

typedef _DataPoint = ({double t, double score01, String? label});

// ── ArcPainter ─────────────────────────────────────────────────────────────────

/// When [showLabel] is true (default) draws a compact semicircular gauge —
/// used for the small card in the gauges row.
///
/// When [showLabel] is false draws a full Cartesian confidence-trajectory
/// line chart:
///   - X axis = normalised time (0 = decision created, 1 = most recent review)
///   - Y axis = confidence / quality score 0–10
///   - Points = [value] at t=0, then cumulative scores derived from
///     [triggers] confidence_delta values
///   - Curve = smooth cubic Catmull-Rom spline through the data points
///   - Gradient fill below the curve
///   - Trigger markers floating above each data point
///   - Influence bands as vertical gradient washes
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

  /// Initial confidence normalised 0.0–1.0.
  final double value;

  /// Animation progress 0.0–1.0 (used to animate the curve left-to-right).
  final double animationValue;

  final List<ConfidenceTrigger> triggers;
  final bool showTriggerMarkers;
  final bool showInfluenceBands;

  /// True → compact semicircular gauge (small card).
  /// False → full Cartesian line chart (trajectory canvas).
  final bool showLabel;

  final void Function(List<TriggerHitArea>)? onHitAreasUpdated;

  // ── Chart layout constants ─────────────────────────────────────────────────

  static const double _leftPad = 28.0;
  static const double _rightPad = 12.0;
  static const double _topPad = 44.0; // room for trigger markers
  static const double _bottomPad = 30.0; // room for date labels

  // ── Coordinate helpers (chart mode) ───────────────────────────────────────

  double _arcXForPosition(double t, Size size) =>
      _leftPad + t * (size.width - _leftPad - _rightPad);

  double _arcYForPosition(double score01, Size size) =>
      _topPad + (1.0 - score01) * (size.height - _topPad - _bottomPad);

  double _plotBottom(Size size) => size.height - _bottomPad;
  double _plotTop(Size size) => _topPad;

  // ── Build chart data points from value + triggers ─────────────────────────

  List<_DataPoint> _buildPoints() {
    final pts = <_DataPoint>[(t: 0.0, score01: value, label: null)];

    double score = value * 10.0;
    for (final trigger in triggers) {
      if (trigger.confidenceDelta != null) {
        score = (score + trigger.confidenceDelta!).clamp(0.0, 10.0);
      }
      final d = trigger.triggerDate;
      final label = '${d.day}/${d.month}';
      pts.add((t: trigger.arcPosition.clamp(0.0, 1.0), score01: score / 10.0, label: label));
    }

    // Need ≥2 points to draw a line — add a terminal point if only the
    // initial value exists (no triggers yet).
    if (pts.length == 1) {
      pts.add((t: 1.0, score01: value, label: null));
    }

    return pts;
  }

  // ── Catmull-Rom → cubic bezier spline ─────────────────────────────────────

  Path _buildSpline(List<Offset> pts) {
    if (pts.isEmpty) return Path();
    if (pts.length == 1) return Path()..moveTo(pts[0].dx, pts[0].dy);
    if (pts.length == 2) {
      return Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy);
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i > 0 ? i - 1 : i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i < pts.length - 2 ? i + 2 : i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  // ── Paint dispatcher ───────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (showLabel) {
      _paintGauge(canvas, size);
    } else {
      _paintChart(canvas, size);
    }
  }

  // ── Compact semicircular gauge (small card) ────────────────────────────────

  void _paintGauge(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = math.min(size.width * 0.42, cy - 20);
    const strokeWidth = 12.0;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

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

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    canvas.drawArc(rect, math.pi, math.pi * value * animationValue, false, fillPaint);

    final numPainter = TextPainter(
      text: TextSpan(
        text: (value * 10).toStringAsFixed(1),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numPainter.paint(
        canvas, Offset(cx - numPainter.width / 2, cy - numPainter.height / 2 - 4));

    final lblPainter = TextPainter(
      text: const TextSpan(
        text: 'confidence',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lblPainter.paint(
        canvas,
        Offset(cx - lblPainter.width / 2, cy + numPainter.height / 2 - 2));

    onHitAreasUpdated?.call([]);
  }

  // ── Cartesian line chart (trajectory canvas) ───────────────────────────────

  void _paintChart(Canvas canvas, Size size) {
    final plotBottom = _plotBottom(size);
    final plotTop = _plotTop(size);
    final plotH = plotBottom - plotTop;
    final plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;

    // 1. Subtle horizontal grid lines at scores 2, 4, 6, 8, 10
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.7)
      ..strokeWidth = 0.5;

    for (final score in [0, 2, 4, 6, 8, 10]) {
      final y = _arcYForPosition(score / 10.0, size);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      final yLabel = TextPainter(
        text: TextSpan(
          text: '$score',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      yLabel.paint(
          canvas,
          Offset(plotLeft - yLabel.width - 4,
              y - yLabel.height / 2));
    }

    // 2. Build data points and canvas offsets
    final rawPts = _buildPoints();
    final offsets = rawPts
        .map((p) => Offset(_arcXForPosition(p.t, size), _arcYForPosition(p.score01, size)))
        .toList();

    // 3. Initial confidence dotted horizontal reference line
    {
      final initY = offsets.first.dy;
      final dashPaint = Paint()
        ..color = AppColors.textMuted.withValues(alpha: 0.45)
        ..strokeWidth = 1.0;
      double x = plotLeft;
      bool dash = true;
      while (x < plotRight) {
        final nextX = math.min(x + (dash ? 8.0 : 4.0), plotRight);
        if (dash) {
          canvas.drawLine(Offset(x, initY), Offset(nextX, initY), dashPaint);
        }
        x = nextX;
        dash = !dash;
      }
    }

    // 4. Influence bands (drawn before curve)
    if (showInfluenceBands && triggers.isNotEmpty) {
      for (final trigger in triggers) {
        final bx = _arcXForPosition(trigger.arcPosition, size);
        final color = triggerColor(trigger.triggerType);
        final bandW = 28.0 + trigger.influenceStrength * 4.0;

        final gradient = ui.Gradient.linear(
          Offset(bx - bandW / 2, 0),
          Offset(bx + bandW / 2, 0),
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0),
          ],
          [0.0, 0.5, 1.0],
        );

        canvas.drawRect(
          Rect.fromLTWH(bx - bandW / 2, plotTop, bandW, plotH),
          Paint()..shader = gradient,
        );
      }
    }

    // 5. Animated clip: reveal curve left-to-right
    final clipX = plotLeft + (plotRight - plotLeft) * animationValue;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, clipX + 20, size.height));

    final spline = _buildSpline(offsets);

    // 5a. Gradient fill below curve
    final fillPath = Path.from(spline)
      ..lineTo(offsets.last.dx, plotBottom)
      ..lineTo(offsets.first.dx, plotBottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, plotTop),
          Offset(0, plotBottom),
          [
            AppColors.accentPrimary.withValues(alpha: 0.30),
            AppColors.accentPrimary.withValues(alpha: 0.0),
          ],
        ),
    );

    // 5b. Curve line
    canvas.drawPath(
      spline,
      Paint()
        ..color = AppColors.accentPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 5c. Review dots + date labels
    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];
      final raw = rawPts[i];

      canvas.drawCircle(
          pt, 4.0, Paint()..color = AppColors.backgroundSurface);
      canvas.drawCircle(
          pt,
          4.0,
          Paint()
            ..color = AppColors.accentPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      if (raw.label != null) {
        final lp = TextPainter(
          text: TextSpan(
            text: raw.label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        lp.paint(
            canvas,
            Offset(pt.dx - lp.width / 2, plotBottom + 4));
      }
    }

    canvas.restore();

    // 6. Trigger markers (drawn outside animation clip — always visible)
    final hitAreas = <TriggerHitArea>[];

    if (showTriggerMarkers && triggers.isNotEmpty) {
      for (int i = 0; i < triggers.length; i++) {
        final trigger = triggers[i];
        // trigger i maps to rawPts[i + 1] (index 0 is the initial point)
        final ptIndex = (i + 1).clamp(0, offsets.length - 1);
        final pt = offsets[ptIndex];

        final markerX = pt.dx;
        final curveY = pt.dy;
        final color = triggerColor(trigger.triggerType);
        final markerRadius = 8.0 + trigger.influenceStrength * 1.2;

        final rawMarkerCY = curveY - markerRadius - 8.0;
        final markerCY =
            rawMarkerCY.clamp(markerRadius + 4.0, curveY - markerRadius - 2.0);

        hitAreas.add((
          center: Offset(markerX, markerCY),
          radius: markerRadius,
          trigger: trigger,
        ));

        // Stem
        canvas.drawLine(
          Offset(markerX, curveY - 4),
          Offset(markerX, markerCY + markerRadius),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = 1.0,
        );

        // Marker background
        canvas.drawCircle(
          Offset(markerX, markerCY),
          markerRadius,
          Paint()..color = AppColors.backgroundSurface,
        );

        // Marker ring
        canvas.drawCircle(
          Offset(markerX, markerCY),
          markerRadius,
          Paint()
            ..color = color
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke,
        );

        // Icon
        final iconPainter = TextPainter(
          text: TextSpan(
            text: triggerIcon(trigger.triggerType),
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
          Offset(markerX - iconPainter.width / 2,
              markerCY - iconPainter.height / 2),
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
              markerX - deltaPainter.width / 2,
              markerCY - markerRadius - deltaPainter.height - 2,
            ),
          );
        }
      }
    }

    onHitAreasUpdated?.call(hitAreas);
  }

  // ── Repaint guard ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(ArcPainter old) =>
      old.value != value ||
      old.animationValue != animationValue ||
      old.triggers != triggers ||
      old.showTriggerMarkers != showTriggerMarkers ||
      old.showInfluenceBands != showInfluenceBands ||
      old.showLabel != showLabel;
}
