import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/dashboard/providers/dashboard_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

final _dateFmt = DateFormat('d MMM');

enum _DateRange { thirtyDays, ninetyDays, allTime }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _DateRange _selectedRange = _DateRange.thirtyDays;
  bool _isRefreshing = false;

  Future<void> _refreshAnalytics() async {
    setState(() => _isRefreshing = true);
    try {
      // Analytics are now computed directly from decisions — just re-fetch.
      ref.invalidate(dashboardAnalyticsProvider);
      ref.invalidate(decisionsProvider);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<Decision> _forRange(List<Decision> all) {
    if (_selectedRange == _DateRange.allTime) return all;
    final cutoff = DateTime.now().subtract(
      _selectedRange == _DateRange.thirtyDays
          ? const Duration(days: 30)
          : const Duration(days: 90),
    );
    return all.where((d) => d.createdAt.isAfter(cutoff)).toList();
  }

  String get _rangeLabel => switch (_selectedRange) {
        _DateRange.thirtyDays => 'Last 30 days',
        _DateRange.ninetyDays => 'Last 90 days',
        _DateRange.allTime => 'All time',
      };

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider);
    final checkpointsAsync = ref.watch(upcomingCheckpointsProvider);
    final analytics = analyticsAsync.valueOrNull;

    // Quality gauge always shows all-time average outcome quality.
    final avgQuality = analytics?.allTimeAvgQuality;

    // Health donut uses checkpoint-based counts (all active decisions).
    final onTrack = analytics?.checkpointOnTrackCount;
    final needsAttn = analytics?.checkpointNeedsAttentionCount;
    final overdue = analytics?.checkpointOverdueCount;

    return Scaffold(
      appBar: AppHeader(
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh analytics',
              onPressed: _refreshAnalytics,
            ),
        ],
      ),
      body: decisionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (decisions) {
          // Fix 2: log quality data for debugging
          debugPrint('[Dashboard] analyticsAsync=${analyticsAsync.runtimeType} '
              'rolling30dAvgQuality=${analytics?.rolling30dAvgQuality} '
              'rolling90dAvgQuality=${analytics?.rolling90dAvgQuality} '
              'allTimeAvgQuality=${analytics?.allTimeAvgQuality}');
          final rangeDecisions = _forRange(decisions);
          final draft =
              rangeDecisions.where((d) => d.state == 'Draft').length;
          final active =
              rangeDecisions.where((d) => d.state == 'Active').length;
          final closed =
              rangeDecisions.where((d) => d.state == 'Closed').length;
          final archived =
              rangeDecisions.where((d) => d.state == 'Archived').length;

          final upcomingIds = checkpointsAsync.valueOrNull
                  ?.map((c) => c.decisionId)
                  .toSet() ??
              {};
          final earliestDue = <String, DateTime>{};
          for (final c in checkpointsAsync.valueOrNull ?? []) {
            final existing = earliestDue[c.decisionId];
            if (existing == null || c.dueAt.isBefore(existing)) {
              earliestDue[c.decisionId] = c.dueAt;
            }
          }

          final needsAttention = decisions.where((d) {
            if (d.state == 'Draft') return true;
            if (d.state == 'Active' && upcomingIds.contains(d.id)) return true;
            return false;
          }).toList();

          final recent = [...decisions]
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final recentFive = recent.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Timeframe switcher + last refreshed ───────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.cs.backgroundElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          for (final (range, label) in [
                            (_DateRange.thirtyDays, '30 Days'),
                            (_DateRange.ninetyDays, '90 Days'),
                            (_DateRange.allTime, 'All Time'),
                          ])
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedRange = range),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedRange == range
                                        ? AppColorScheme.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedRange == range
                                        ? [
                                            BoxShadow(
                                              color: AppColorScheme.accent
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedRange == range
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: _selectedRange == range
                                          ? Colors.white
                                          : context.cs.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (analytics?.computedAt != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Updated ${DateFormat('HH:mm').format(analytics!.computedAt!.toLocal())}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.cs.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── 2×2 Chart Grid ────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 500;
                  if (isWide) {
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _QualityDial(quality: avgQuality)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _HealthDonut(
                                  onTrack: onTrack,
                                  needsAttention: needsAttn,
                                  overdue: overdue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusBarChart(
                          draft: draft,
                          active: active,
                          closed: closed,
                          archived: archived,
                          rangeLabel: _rangeLabel,
                        ),
                        const SizedBox(height: 12),
                        _CalibrationMetricTiles(
                          delta: analytics?.confidenceCalibrationDelta,
                          avgConfidence: analytics?.avgConfidenceGiven,
                          avgOutcomeScore: analytics?.avgOutcomeScore,
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _QualityDial(quality: avgQuality),
                      const SizedBox(height: 12),
                      _HealthDonut(
                        onTrack: onTrack,
                        needsAttention: needsAttn,
                        overdue: overdue,
                      ),
                      const SizedBox(height: 12),
                      _StatusBarChart(
                        draft: draft,
                        active: active,
                        closed: closed,
                        archived: archived,
                        rangeLabel: _rangeLabel,
                      ),
                      const SizedBox(height: 12),
                      _CalibrationMetricTiles(
                        delta: analytics?.confidenceCalibrationDelta,
                        avgConfidence: analytics?.avgConfidenceGiven,
                        avgOutcomeScore: analytics?.avgOutcomeScore,
                      ),
                    ],
                  );
                },
              ),

              // ── Needs Attention panel ─────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: context.cs.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cs.borderDefault),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97D24),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NEEDS ATTENTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97D24),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${needsAttention.length} decisions',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.cs.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (needsAttention.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'All clear — no decisions need attention.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.cs.textTertiary,
                                ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 0),
                          itemCount: needsAttention.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final d = needsAttention[index];
                            return _NeedsAttentionCard(
                              decision: d,
                              dueDate: earliestDue[d.id],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // ── Recent Decisions ──────────────────────────────────────
              if (recentFive.isNotEmpty)
                ExpansionTile(
                  tilePadding: const EdgeInsets.only(left: 4, right: 8),
                  title: Text(
                    'RECENT DECISIONS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  initiallyExpanded: false,
                  children:
                      recentFive.map((d) => _RecentDecisionTile(decision: d)).toList(),
                ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ── Quality Dial ─────────────────────────────────────────────────────────────
// Semicircle gauge drawn with CustomPaint for gradient arc support.

class _QualityDial extends StatelessWidget {
  const _QualityDial({required this.quality});

  final double? quality;

  @override
  Widget build(BuildContext context) {
    // quality is 0–100 (outcome score 1–10 scaled ×10). Display as 0–10.
    final q = quality?.clamp(0.0, 100.0) ?? 0.0;
    final hasData = quality != null && quality! > 0;
    final filledFraction = hasData ? q / 100.0 : 0.0;

    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DECISION QUALITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 120,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      fraction: filledFraction,
                      hasData: hasData,
                      trackColor: cs.borderDefault,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: hasData ? (q / 10).toStringAsFixed(1) : '--',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: hasData
                              ? AppColorScheme.accent
                              : cs.textTertiary,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                      if (hasData)
                        TextSpan(
                          text: ' / 10',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.textTertiary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fraction,
    required this.hasData,
    required this.trackColor,
  });

  final double fraction;
  final bool hasData;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 24.0;
    final radius = math.min(
      size.width / 2 - strokeWidth / 2,
      size.height - strokeWidth / 2,
    );
    final center = Offset(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc (full semicircle, left to right)
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    // Filled gradient arc
    if (hasData && fraction > 0) {
      final filledPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      filledPaint.shader = SweepGradient(
        center: Alignment.center,
        colors: const [Color(0xFF19CBD6), Color(0xFF0EA5BE), Color(0xFF0E9AAF)],
        startAngle: math.pi,
        endAngle: math.pi * 2,
        tileMode: TileMode.clamp,
      ).createShader(rect);
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * fraction,
        false,
        filledPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction ||
      old.hasData != hasData ||
      old.trackColor != trackColor;
}

// ── Gradient Donut Chart ──────────────────────────────────────────────────────

class GradientDonutSegment {
  const GradientDonutSegment({
    required this.value,
    required this.startColor,
    required this.endColor,
    required this.label,
  });

  final double value;
  final Color startColor;
  final Color endColor;
  final String label;
}

class GradientDonutChart extends StatelessWidget {
  const GradientDonutChart({
    super.key,
    required this.segments,
    required this.size,
    required this.strokeWidth,
    this.separatorColor = Colors.white,
  });

  final List<GradientDonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Color separatorColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: segments,
          strokeWidth: strokeWidth,
          separatorColor: separatorColor,
        ),
        size: Size(size, size),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.separatorColor,
  });

  final List<GradientDonutSegment> segments;
  final double strokeWidth;
  final Color separatorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, seg) => s + seg.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final innerRadius = radius - strokeWidth / 2;
    final outerRadius = radius + strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final separatorPaint = Paint()
      ..color = separatorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Start at top (12 o'clock = -π/2)
    double currentAngle = -math.pi / 2;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi;

      // Gradient arc
      arcPaint.shader = SweepGradient(
        center: Alignment.center,
        startAngle: currentAngle,
        endAngle: currentAngle + sweepAngle,
        colors: [seg.startColor, seg.endColor],
        tileMode: TileMode.clamp,
      ).createShader(rect);

      canvas.drawArc(rect, currentAngle, sweepAngle, false, arcPaint);

      // White separator at start of segment
      final sc = math.cos(currentAngle);
      final ss = math.sin(currentAngle);
      canvas.drawLine(
        Offset(center.dx + innerRadius * sc, center.dy + innerRadius * ss),
        Offset(center.dx + outerRadius * sc, center.dy + outerRadius * ss),
        separatorPaint,
      );

      // Count label at midpoint of segment
      final midAngle = currentAngle + sweepAngle / 2;
      final labelPos = Offset(
        center.dx + radius * math.cos(midAngle),
        center.dy + radius * math.sin(midAngle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

// ── Status Bar Chart ─────────────────────────────────────────────────────────
// Always "All time" data from the decisions list.

class _StatusBarChart extends StatelessWidget {
  const _StatusBarChart({
    required this.draft,
    required this.active,
    required this.closed,
    required this.archived,
    required this.rangeLabel,
  });

  final int draft;
  final int active;
  final int closed;
  final int archived;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final maxVal =
        math.max(1, [draft, active, closed, archived].reduce(math.max))
            .toDouble();

    BarChartGroupData bar(int x, int value, Color color) =>
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: math.max(value.toDouble(), maxVal * 0.04),
              color: color,
              width: 22,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6)),
            ),
          ],
        );

    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS BREAKDOWN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.25,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.borderDefault,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, _) {
                        final counts = [draft, active, closed, archived];
                        final i = value.toInt();
                        if (i < 0 || i >= counts.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${counts[i]}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final labels = ['Draft', 'Active', 'Closed', 'Arch.'];
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  bar(0, draft, cs.textTertiary),
                  bar(1, active, AppColorScheme.accent),
                  bar(2, closed, AppColorScheme.success),
                  bar(3, archived, cs.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rangeLabel,
            style: TextStyle(
              fontSize: 11,
              color: cs.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health Donut ─────────────────────────────────────────────────────────────

class _HealthDonut extends StatelessWidget {
  const _HealthDonut({
    required this.onTrack,
    required this.needsAttention,
    required this.overdue,
  });

  final int? onTrack;
  final int? needsAttention;
  final int? overdue;

  @override
  Widget build(BuildContext context) {
    final total = (onTrack ?? 0) + (needsAttention ?? 0) + (overdue ?? 0);
    final hasData = total > 0;

    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DECISION HEALTH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: hasData
                  ? GradientDonutChart(
                      size: 200,
                      strokeWidth: 44,
                      separatorColor: cs.backgroundSecondary,
                      segments: [
                        GradientDonutSegment(
                          value: (onTrack ?? 0).toDouble(),
                          startColor: AppColorScheme.success,
                          endColor: AppColorScheme.success,
                          label: '${onTrack ?? 0}',
                        ),
                        GradientDonutSegment(
                          value: (needsAttention ?? 0).toDouble(),
                          startColor: AppColorScheme.warning,
                          endColor: AppColorScheme.warning,
                          label: '${needsAttention ?? 0}',
                        ),
                        GradientDonutSegment(
                          value: (overdue ?? 0).toDouble(),
                          startColor: AppColorScheme.destructive,
                          endColor: AppColorScheme.destructive,
                          label: '${overdue ?? 0}',
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        'No active\ndecisions',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.textTertiary,
                            ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasData)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                    color: const Color(0xFF2EA073),
                    label: 'On track',
                    count: onTrack),
                const SizedBox(width: 16),
                _LegendItem(
                    color: const Color(0xFFD97D24),
                    label: 'Needs attn',
                    count: needsAttention),
                const SizedBox(width: 16),
                _LegendItem(
                    color: const Color(0xFFDC4444),
                    label: 'Overdue',
                    count: overdue),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.count});

  final Color color;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        if (count != null) ...[
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.cs.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
        ],
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.cs.textTertiary),
        ),
      ],
    );
  }
}

// ── Calibration Metric Tiles ─────────────────────────────────────────────────

class _CalibrationMetricTiles extends StatelessWidget {
  const _CalibrationMetricTiles({
    required this.delta,
    required this.avgConfidence,
    required this.avgOutcomeScore,
  });

  final double? delta;
  final double? avgConfidence;
  final double? avgOutcomeScore;

  @override
  Widget build(BuildContext context) {
    final d = delta;

    Color calibColor;
    String calibValue;
    String calibSublabel;

    String calibUnit;

    if (d == null) {
      calibColor = context.cs.textTertiary;
      calibValue = '--';
      calibUnit = '';
      calibSublabel = 'No data yet';
    } else {
      if (d > 1.0) {
        calibColor = AppColorScheme.warning;
        calibSublabel = 'Overconfident';
      } else if (d < -1.0) {
        calibColor = AppColorScheme.accent;
        calibSublabel = 'Underconfident';
      } else {
        calibColor = AppColorScheme.success;
        calibSublabel = 'Well calibrated';
      }
      final sign = d >= 0 ? '+' : '';
      calibValue = '$sign${d.toStringAsFixed(1)}';
      calibUnit = '%';
    }

    final confValue =
        avgConfidence != null ? avgConfidence!.toStringAsFixed(1) : '--';
    final confUnit = avgConfidence != null ? '/ 10' : '';

    final outcomeValue =
        avgOutcomeScore != null ? avgOutcomeScore!.toStringAsFixed(1) : '--';
    final outcomeUnit = avgOutcomeScore != null ? '/ 10' : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Confidence Calibration',
              value: calibValue,
              unit: calibUnit,
              sublabel: calibSublabel,
              valueColor: calibColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'Avg. Confidence Given',
              value: confValue,
              unit: confUnit,
              sublabel: 'across all decisions',
              valueColor: AppColorScheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'Avg. Outcome Score',
              value: outcomeValue,
              unit: outcomeUnit,
              sublabel: 'from completed reviews',
              valueColor: AppColorScheme.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.unit = '',
    required this.sublabel,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final String sublabel;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: TextStyle(fontSize: 11, color: cs.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Needs Attention card ─────────────────────────────────────────────────────

class _NeedsAttentionCard extends StatelessWidget {
  const _NeedsAttentionCard({
    required this.decision,
    required this.dueDate,
  });

  final Decision decision;
  final DateTime? dueDate;

  Color _bgFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _fgFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentHover,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => context.push('/decisions/detail/${decision.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    decision.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.cs.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bgFor(decision.state),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        decision.state,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _fgFor(decision.state),
                        ),
                      ),
                    ),
                    if (dueDate != null) ...[
                      const Spacer(),
                      Text(
                        _dateFmt.format(dueDate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.cs.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recent decision tile ─────────────────────────────────────────────────────

class _RecentDecisionTile extends StatelessWidget {
  const _RecentDecisionTile({required this.decision});

  final Decision decision;

  Color _backgroundFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _foregroundFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentHover,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/decisions/detail/${decision.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  decision.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _backgroundFor(decision.state),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  decision.state,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _foregroundFor(decision.state),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
