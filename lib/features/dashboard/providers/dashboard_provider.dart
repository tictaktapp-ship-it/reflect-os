import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  final double? rolling30dAvgQuality;
  final double? rolling90dAvgQuality;
  final double? allTimeAvgQuality;
  final int? allTimeDecisionsLogged;
  final int? rolling30dDecisionsReviewed;
  final int? rolling90dDecisionsReviewed;
  final DateTime? computedAt;
}

/// Reads from the precomputed analytics_summary view.
/// RLS ensures the user sees only their workspace's data.
/// Never aggregate outcome scores in Flutter — use this view instead.
final dashboardAnalyticsProvider =
    FutureProvider<DashboardAnalytics>((ref) async {
  final row = await supabase.from('analytics_summary').select(
      'rolling_30d_avg_quality, rolling_90d_avg_quality, all_time_avg_quality, '
      'all_time_decisions_logged, rolling_30d_decisions_reviewed, '
      'rolling_90d_decisions_reviewed, computed_at').maybeSingle();

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
  );
});
