import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/dashboard/providers/dashboard_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

final _dateFmt = DateFormat('d MMM');
final _refreshedFmt = DateFormat('d MMM yyyy HH:mm');

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
      await supabase.functions.invoke('refresh-analytics');
      ref.invalidate(dashboardAnalyticsProvider);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider);
    final checkpointsAsync = ref.watch(upcomingCheckpointsProvider);
    final workspaceName = ref.watch(workspaceNameProvider).valueOrNull;
    final analytics = analyticsAsync.valueOrNull;

    final avgQuality = switch (_selectedRange) {
      _DateRange.thirtyDays => analytics?.rolling30dAvgQuality,
      _DateRange.ninetyDays => analytics?.rolling90dAvgQuality,
      _DateRange.allTime => analytics?.allTimeAvgQuality,
    };

    final onTrack = switch (_selectedRange) {
      _DateRange.thirtyDays => analytics?.rolling30dOnTrackCount,
      _DateRange.ninetyDays => analytics?.rolling90dOnTrackCount,
      _DateRange.allTime => null,
    };
    final needsAttn = switch (_selectedRange) {
      _DateRange.thirtyDays => analytics?.rolling30dNeedsAttentionCount,
      _DateRange.ninetyDays => analytics?.rolling90dNeedsAttentionCount,
      _DateRange.allTime => null,
    };
    final overdue = switch (_selectedRange) {
      _DateRange.thirtyDays => analytics?.rolling30dOverdueCount,
      _DateRange.ninetyDays => analytics?.rolling90dOverdueCount,
      _DateRange.allTime => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
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
          final draft =
              decisions.where((d) => d.state == 'Draft').length;
          final active =
              decisions.where((d) => d.state == 'Active').length;
          final closed =
              decisions.where((d) => d.state == 'Closed').length;
          final archived =
              decisions.where((d) => d.state == 'Archived').length;

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
            padding: const EdgeInsets.all(16),
            children: [
              // ── Workspace indicator ───────────────────────────────────
              if (workspaceName != null) ...[
                Row(
                  children: [
                    Icon(Icons.business_outlined,
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      workspaceName,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── Date range selector ───────────────────────────────────
              SegmentedButton<_DateRange>(
                segments: const [
                  ButtonSegment(
                      value: _DateRange.thirtyDays, label: Text('30 Days')),
                  ButtonSegment(
                      value: _DateRange.ninetyDays, label: Text('90 Days')),
                  ButtonSegment(
                      value: _DateRange.allTime, label: Text('All Time')),
                ],
                selected: {_selectedRange},
                onSelectionChanged: (s) =>
                    setState(() => _selectedRange = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 20),

              // ── Row 1: Quality Dial + Health Donut ────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 500;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _QualityDial(quality: avgQuality)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HealthDonut(
                            onTrack: onTrack,
                            needsAttention: needsAttn,
                            overdue: overdue,
                            isAllTime: _selectedRange == _DateRange.allTime,
                          ),
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
                        isAllTime: _selectedRange == _DateRange.allTime,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Row 2: Status Bar Chart + Confidence Delta ────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 500;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatusBarChart(
                            draft: draft,
                            active: active,
                            closed: closed,
                            archived: archived,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ConfidenceDeltaCard(
                            delta: analytics?.confidenceCalibrationDelta,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _StatusBarChart(
                        draft: draft,
                        active: active,
                        closed: closed,
                        archived: archived,
                      ),
                      const SizedBox(height: 12),
                      _ConfidenceDeltaCard(
                        delta: analytics?.confidenceCalibrationDelta,
                      ),
                    ],
                  );
                },
              ),

              // ── Last refreshed ────────────────────────────────────────
              if (analytics?.computedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Last refreshed: ${_refreshedFmt.format(analytics!.computedAt!.toLocal())}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                ),

              // ── Needs Attention ───────────────────────────────────────
              _sectionHeader(context, 'NEEDS ATTENTION'),
              if (needsAttention.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'All clear — no decisions need attention.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                    itemCount: needsAttention.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final d = needsAttention[index];
                      return _NeedsAttentionCard(
                        decision: d,
                        dueDate: earliestDue[d.id],
                      );
                    },
                  ),
                ),

              // ── Recent Decisions ──────────────────────────────────────
              if (recentFive.isNotEmpty) ...[
                _sectionHeader(context, 'RECENT DECISIONS'),
                ...recentFive.map((d) => _RecentDecisionTile(decision: d)),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context, String label) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );

// ── Quality Dial ─────────────────────────────────────────────────────────────
// Half-donut arc gauge. quality is 0–10. Clipped to upper half.

class _QualityDial extends StatelessWidget {
  const _QualityDial({required this.quality});

  final double? quality;

  @override
  Widget build(BuildContext context) {
    final q = quality?.clamp(0.0, 10.0) ?? 0.0;
    final hasData = quality != null;

    // Arc colour: warning → accentHover as q goes 0→10
    final arcColor = hasData
        ? Color.lerp(AppColors.warning, AppColors.accentHover, q / 10)!
        : AppColors.textMuted.withValues(alpha: 0.3);

    final filledFraction = hasData ? q / 10 : 0.0;
    final emptyFraction = hasData ? (10.0 - q) / 10 : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decision Quality',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    )),
            const SizedBox(height: 8),
            // Half-donut: clip bottom half away
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.55,
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: 180,
                          sectionsSpace: 0,
                          centerSpaceRadius: 44,
                          sections: [
                            // Filled arc
                            PieChartSectionData(
                              value: filledFraction,
                              color: arcColor,
                              radius: 28,
                              showTitle: false,
                            ),
                            // Empty arc
                            PieChartSectionData(
                              value: emptyFraction,
                              color: AppColors.borderSubtle,
                              radius: 28,
                              showTitle: false,
                            ),
                            // Hidden lower half (transparent, same size)
                            PieChartSectionData(
                              value: 1,
                              color: Colors.transparent,
                              radius: 28,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      // Centre label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasData
                                  ? q.toStringAsFixed(1)
                                  : '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: arcColor,
                                  ),
                            ),
                            Text(
                              '/ 10',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Bar Chart ─────────────────────────────────────────────────────────
// Always "All time" data from the decisions list.

class _StatusBarChart extends StatelessWidget {
  const _StatusBarChart({
    required this.draft,
    required this.active,
    required this.closed,
    required this.archived,
  });

  final int draft;
  final int active;
  final int closed;
  final int archived;

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
              toY: value.toDouble(),
              color: color,
              width: 22,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6)),
            ),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Breakdown',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    )),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.25,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.07),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    bar(0, draft, AppColors.textSecondary),
                    bar(1, active, AppColors.accentHover),
                    bar(2, closed, AppColors.success),
                    bar(3, archived, AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All time',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
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
    required this.isAllTime,
  });

  final int? onTrack;
  final int? needsAttention;
  final int? overdue;
  final bool isAllTime;

  @override
  Widget build(BuildContext context) {
    final total = (onTrack ?? 0) + (needsAttention ?? 0) + (overdue ?? 0);
    final hasData = !isAllTime && total > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decision Health',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    )),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: hasData
                  ? PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 44,
                        sections: [
                          PieChartSectionData(
                            value: onTrack!.toDouble(),
                            color: AppColors.success,
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: needsAttention!.toDouble(),
                            color: AppColors.warning,
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: overdue!.toDouble(),
                            color: AppColors.destructive,
                            radius: 18,
                            showTitle: false,
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        isAllTime
                            ? 'Health tracked\nper period'
                            : 'No data yet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (hasData)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(color: AppColors.success, label: 'On track'),
                  const SizedBox(width: 12),
                  _LegendItem(
                      color: AppColors.warning, label: 'Needs attention'),
                  const SizedBox(width: 12),
                  _LegendItem(color: AppColors.destructive, label: 'Overdue'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

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
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                )),
      ],
    );
  }
}

// ── Confidence Delta Card ────────────────────────────────────────────────────

class _ConfidenceDeltaCard extends StatelessWidget {
  const _ConfidenceDeltaCard({required this.delta});

  final double? delta;

  @override
  Widget build(BuildContext context) {
    final d = delta;

    Color pillColor;
    String label;
    String description;

    if (d == null) {
      pillColor = AppColors.textMuted.withValues(alpha: 0.3);
      label = '—';
      description = 'No calibration data yet';
    } else {
      final abs = d.abs();
      if (abs <= 5) {
        pillColor = AppColors.success;
      } else if (abs <= 15) {
        pillColor = AppColors.warning;
      } else {
        pillColor = AppColors.destructive;
      }
      final sign = d >= 0 ? '+' : '';
      label = '$sign${d.toStringAsFixed(1)}%';
      description = d >= 0
          ? 'You tend to be overconfident'
          : 'You tend to be underconfident';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confidence Calibration',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      letterSpacing: 0.6,
                    )),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: pillColor.withValues(alpha: 0.5), width: 1),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: pillColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
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
      width: 200,
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
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _bgFor(decision.state),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        decision.state,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: _fgFor(decision.state),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (dueDate != null) ...[
                      const Spacer(),
                      Text(
                        'Due ${_dateFmt.format(dueDate!)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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
