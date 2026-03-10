import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

class DashboardAnalytics {
  const DashboardAnalytics({
    this.rolling30dAvgQuality,
    this.rolling90dAvgQuality,
    this.allTimeAvgQuality,
    this.allTimeDecisionsLogged,
    this.rolling30dDecisionsReviewed,
    this.rolling90dDecisionsReviewed,
    this.computedAt,
    this.rolling30dDecisionsLogged,
    this.rolling30dOnTrackCount,
    this.rolling30dNeedsAttentionCount,
    this.rolling30dOverdueCount,
    this.rolling90dDecisionsLogged,
    this.rolling90dOnTrackCount,
    this.rolling90dNeedsAttentionCount,
    this.rolling90dOverdueCount,
    this.confidenceCalibrationDelta,
  });

  final double? rolling30dAvgQuality;
  final double? rolling90dAvgQuality;
  final double? allTimeAvgQuality;
  final int? allTimeDecisionsLogged;
  final int? rolling30dDecisionsReviewed;
  final int? rolling90dDecisionsReviewed;
  final DateTime? computedAt;
  final int? rolling30dDecisionsLogged;
  final int? rolling30dOnTrackCount;
  final int? rolling30dNeedsAttentionCount;
  final int? rolling30dOverdueCount;
  final int? rolling90dDecisionsLogged;
  final int? rolling90dOnTrackCount;
  final int? rolling90dNeedsAttentionCount;
  final int? rolling90dOverdueCount;
  final double? confidenceCalibrationDelta;
}

/// Computes analytics directly from user_visible_decisions.
/// The analytics_summary view does not exist in the DB, so we aggregate here.
final dashboardAnalyticsProvider =
    FutureProvider.autoDispose<DashboardAnalytics>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return const DashboardAnalytics();

  // Fetch lightweight columns needed for all aggregations.
  final rows = await supabase
      .from('user_visible_decisions')
      .select('initial_confidence, created_at, health_state')
      .eq('workspace_id', workspaceId);

  if (rows.isEmpty) return DashboardAnalytics(computedAt: DateTime.now());

  final now = DateTime.now();
  final cutoff30 = now.subtract(const Duration(days: 30));
  final cutoff90 = now.subtract(const Duration(days: 90));

  // Partition by time window.
  final last30 = rows.where((r) {
    final ts = r['created_at'] as String?;
    if (ts == null) return false;
    final dt = DateTime.tryParse(ts);
    return dt != null && dt.isAfter(cutoff30);
  }).toList();

  final last90 = rows.where((r) {
    final ts = r['created_at'] as String?;
    if (ts == null) return false;
    final dt = DateTime.tryParse(ts);
    return dt != null && dt.isAfter(cutoff90);
  }).toList();

  // Average initial_confidence for a subset, scaled 1–10 → 0–100.
  double? avgQuality(List subset) {
    final vals = subset
        .map((r) => r['initial_confidence'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return avg * 10.0; // confidence stored as 1–10, dial expects 0–100
  }

  // Count rows matching a health_state value.
  int healthCount(List subset, String state) =>
      subset.where((r) => r['health_state'] == state).length;

  final allTimeQuality = avgQuality(rows);
  final rolling30dQuality = avgQuality(last30);
  final rolling90dQuality = avgQuality(last90);

  debugPrint('[DashboardAnalytics] rows=${rows.length} '
      'last30=${last30.length} last90=${last90.length} '
      'allTimeAvgQuality=$allTimeQuality '
      'rolling30dAvgQuality=$rolling30dQuality '
      'rolling90dAvgQuality=$rolling90dQuality');

  return DashboardAnalytics(
    allTimeAvgQuality: allTimeQuality,
    rolling30dAvgQuality: rolling30dQuality,
    rolling90dAvgQuality: rolling90dQuality,
    allTimeDecisionsLogged: rows.length,
    rolling30dDecisionsLogged: last30.length,
    rolling90dDecisionsLogged: last90.length,
    rolling30dOnTrackCount: healthCount(last30, 'on_track'),
    rolling30dNeedsAttentionCount: healthCount(last30, 'needs_attention'),
    rolling30dOverdueCount: healthCount(last30, 'overdue'),
    rolling90dOnTrackCount: healthCount(last90, 'on_track'),
    rolling90dNeedsAttentionCount: healthCount(last90, 'needs_attention'),
    rolling90dOverdueCount: healthCount(last90, 'overdue'),
    computedAt: now,
  );
});
