import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

class DashboardAnalytics {
  const DashboardAnalytics({this.avgOutcomeQualityScore});

  final double? avgOutcomeQualityScore;
}

/// Reads from the precomputed analytics_summary view.
/// RLS ensures the user sees only their workspace's data.
/// Never aggregate outcome scores in Flutter — use this view instead.
final dashboardAnalyticsProvider =
    FutureProvider<DashboardAnalytics>((ref) async {
  final row = await supabase
      .from('analytics_summary')
      .select('avg_outcome_quality_score')
      .maybeSingle();

  if (row == null) return const DashboardAnalytics();

  final raw = row['avg_outcome_quality_score'];
  return DashboardAnalytics(
    avgOutcomeQualityScore: raw != null ? (raw as num).toDouble() : null,
  );
});
