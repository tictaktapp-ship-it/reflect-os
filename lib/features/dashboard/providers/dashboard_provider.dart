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
    this.rolling90dDecisionsLogged,
    this.checkpointOnTrackCount,
    this.checkpointNeedsAttentionCount,
    this.checkpointOverdueCount,
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
  final int? rolling90dDecisionsLogged;
  // Checkpoint-based health (all active decisions, not period-filtered)
  final int? checkpointOnTrackCount;
  final int? checkpointNeedsAttentionCount;
  final int? checkpointOverdueCount;
  final double? confidenceCalibrationDelta;
}

/// Computes analytics directly from user_visible_decisions + outcome_updates
/// + review_checkpoints.
final dashboardAnalyticsProvider =
    FutureProvider.autoDispose<DashboardAnalytics>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return const DashboardAnalytics();

  // Fetch decisions (lightweight — just id, confidence, created_at, state).
  final rows = await supabase
      .from('user_visible_decisions')
      .select('id, initial_confidence, created_at, state')
      .eq('workspace_id', workspaceId);

  if (rows.isEmpty) return DashboardAnalytics(computedAt: DateTime.now());

  final now = DateTime.now();
  final cutoff30 = now.subtract(const Duration(days: 30));
  final cutoff90 = now.subtract(const Duration(days: 90));

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

  final decisionIds = rows.map((r) => r['id'] as String).toList();

  // ── Quality: from outcome_updates.outcome_quality_score (1–10 → ×10 → 0–100) ─
  double? allTimeQuality;
  double? rolling30dQuality;
  double? rolling90dQuality;
  double? calibrationDelta;

  try {
    final outcomeRows = await supabase
        .from('outcome_updates')
        .select('decision_id, outcome_quality_score, updated_at')
        .inFilter('decision_id', decisionIds)
        .not('outcome_quality_score', 'is', null)
        .isFilter('deleted_at', null);

    if (outcomeRows.isNotEmpty) {
      // Collect latest outcome score per decision (prefer most recent update).
      final latestByDecision = <String, Map<String, dynamic>>{};
      for (final o in outcomeRows) {
        final decId = o['decision_id'] as String?;
        if (decId == null) continue;
        final existing = latestByDecision[decId];
        if (existing == null) {
          latestByDecision[decId] = o;
        } else {
          final existingTs = existing['updated_at'] as String? ?? '';
          final newTs = o['updated_at'] as String? ?? '';
          if (newTs.compareTo(existingTs) > 0) latestByDecision[decId] = o;
        }
      }

      double? calcAvgQuality(List<Map<String, dynamic>> decisionSubset) {
        final ids = decisionSubset.map((r) => r['id'] as String).toSet();
        final vals = latestByDecision.entries
            .where((e) => ids.contains(e.key))
            .map((e) => (e.value['outcome_quality_score'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (vals.isEmpty) return null;
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        return avg * 10.0; // 1–10 → 0–100 for dial
      }

      allTimeQuality = calcAvgQuality(rows);
      rolling30dQuality = calcAvgQuality(last30);
      rolling90dQuality = calcAvgQuality(last90);

      // Calibration: initial_confidence vs outcome_quality_score (both 1–10).
      final confByDecision = <String, double>{};
      for (final r in rows) {
        final id = r['id'] as String?;
        final conf = (r['initial_confidence'] as num?)?.toDouble();
        if (id != null && conf != null) confByDecision[id] = conf;
      }

      final deltas = <double>[];
      for (final entry in latestByDecision.entries) {
        final conf = confByDecision[entry.key];
        final quality =
            (entry.value['outcome_quality_score'] as num?)?.toDouble();
        if (conf != null && quality != null) {
          deltas.add((conf - quality) * 10.0);
        }
      }
      if (deltas.isNotEmpty) {
        calibrationDelta = deltas.reduce((a, b) => a + b) / deltas.length;
      }
    }
  } catch (e) {
    debugPrint('[DashboardAnalytics] outcome query failed: $e');
  }

  // ── Health: checkpoint-based for all active decisions ──────────────────────
  int checkpointOnTrack = 0;
  int checkpointNeedsAttention = 0;
  int checkpointOverdue = 0;

  try {
    final activeIds = rows
        .where((r) => (r['state'] as String?)?.toLowerCase() == 'active')
        .map((r) => r['id'] as String)
        .toList();

    if (activeIds.isNotEmpty) {
      final checkpoints = await supabase
          .from('review_checkpoints')
          .select('decision_id, due_at, completed_at')
          .inFilter('decision_id', activeIds)
          .isFilter('deleted_at', null);

      final cutoffNeeds = now.add(const Duration(days: 14));

      // Find the most-relevant (earliest due) open checkpoint per decision.
      final openByDecision = <String, Map<String, dynamic>>{};
      for (final c in checkpoints) {
        if (c['completed_at'] != null) continue;
        final decId = c['decision_id'] as String?;
        if (decId == null) continue;
        final existing = openByDecision[decId];
        if (existing == null) {
          openByDecision[decId] = c;
        } else {
          final existingDue = existing['due_at'] as String? ?? '';
          final newDue = c['due_at'] as String? ?? '';
          if (newDue.compareTo(existingDue) < 0) openByDecision[decId] = c;
        }
      }

      // Decisions with no open checkpoints count as on-track.
      final decisionsWithOpen = openByDecision.keys.toSet();
      checkpointOnTrack += activeIds.where((id) => !decisionsWithOpen.contains(id)).length;

      for (final entry in openByDecision.entries) {
        final dueStr = entry.value['due_at'] as String?;
        final dueAt = dueStr != null ? DateTime.tryParse(dueStr) : null;
        if (dueAt == null || dueAt.isBefore(now)) {
          checkpointOverdue++;
        } else if (dueAt.isBefore(cutoffNeeds)) {
          checkpointNeedsAttention++;
        } else {
          checkpointOnTrack++;
        }
      }
    }
  } catch (e) {
    debugPrint('[DashboardAnalytics] checkpoint query failed: $e');
  }

  debugPrint('[DashboardAnalytics] rows=${rows.length} '
      'allTimeAvgQuality=$allTimeQuality '
      'rolling30dAvgQuality=$rolling30dQuality '
      'checkpointOnTrack=$checkpointOnTrack '
      'checkpointNeedsAttn=$checkpointNeedsAttention '
      'checkpointOverdue=$checkpointOverdue '
      'calibrationDelta=$calibrationDelta');

  return DashboardAnalytics(
    allTimeAvgQuality: allTimeQuality,
    rolling30dAvgQuality: rolling30dQuality,
    rolling90dAvgQuality: rolling90dQuality,
    allTimeDecisionsLogged: rows.length,
    rolling30dDecisionsLogged: last30.length,
    rolling90dDecisionsLogged: last90.length,
    checkpointOnTrackCount: checkpointOnTrack,
    checkpointNeedsAttentionCount: checkpointNeedsAttention,
    checkpointOverdueCount: checkpointOverdue,
    confidenceCalibrationDelta: calibrationDelta,
    computedAt: now,
  );
});
