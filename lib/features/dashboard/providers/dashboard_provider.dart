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

/// Reads from the precomputed analytics_summary view filtered by workspace.
/// Never aggregate outcome scores in Flutter — use this view instead.
final dashboardAnalyticsProvider =
    FutureProvider.autoDispose<DashboardAnalytics>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return const DashboardAnalytics();

  final row = await supabase.from('analytics_summary').select(
      'rolling_30d_avg_quality, rolling_90d_avg_quality, all_time_avg_quality, '
      'all_time_decisions_logged, rolling_30d_decisions_reviewed, '
      'rolling_90d_decisions_reviewed, computed_at, '
      'rolling_30d_decisions_logged, rolling_30d_on_track_count, '
      'rolling_30d_needs_attention_count, rolling_30d_overdue_count, '
      'rolling_90d_decisions_logged, rolling_90d_on_track_count, '
      'rolling_90d_needs_attention_count, rolling_90d_overdue_count, '
      'confidence_calibration_delta')
      .eq('workspace_id', workspaceId)
      .maybeSingle();

  if (row == null) return const DashboardAnalytics();

  double? asDouble(dynamic v) => v != null ? (v as num).toDouble() : null;
  int? asInt(dynamic v) => v != null ? (v as num).toInt() : null;

  return DashboardAnalytics(
    rolling30dAvgQuality: asDouble(row['rolling_30d_avg_quality']),
    rolling90dAvgQuality: asDouble(row['rolling_90d_avg_quality']),
    allTimeAvgQuality: asDouble(row['all_time_avg_quality']),
    allTimeDecisionsLogged: asInt(row['all_time_decisions_logged']),
    rolling30dDecisionsReviewed: asInt(row['rolling_30d_decisions_reviewed']),
    rolling90dDecisionsReviewed: asInt(row['rolling_90d_decisions_reviewed']),
    computedAt: row['computed_at'] == null
        ? null
        : DateTime.parse(row['computed_at'] as String),
    rolling30dDecisionsLogged: asInt(row['rolling_30d_decisions_logged']),
    rolling30dOnTrackCount: asInt(row['rolling_30d_on_track_count']),
    rolling30dNeedsAttentionCount:
        asInt(row['rolling_30d_needs_attention_count']),
    rolling30dOverdueCount: asInt(row['rolling_30d_overdue_count']),
    rolling90dDecisionsLogged: asInt(row['rolling_90d_decisions_logged']),
    rolling90dOnTrackCount: asInt(row['rolling_90d_on_track_count']),
    rolling90dNeedsAttentionCount:
        asInt(row['rolling_90d_needs_attention_count']),
    rolling90dOverdueCount: asInt(row['rolling_90d_overdue_count']),
    confidenceCalibrationDelta: asDouble(row['confidence_calibration_delta']),
  );
});
