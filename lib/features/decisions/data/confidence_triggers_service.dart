import 'package:flutter/foundation.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

/// Generates and persists `confidence_triggers` rows derived from outcome
/// updates, approved risk assessments, and coach notes.
///
/// Called from two sites:
///   1. [DecisionLensRepository.compute] — backfill when no triggers exist.
///   2. [CreateOutcomeScreen._submit] — forward-write after each new review.
///   3. [CoachingRepository] — after inserting a coach note with an adjustment.
class ConfidenceTriggersService {
  const ConfidenceTriggersService();

  // ── Arc position (Part C) ─────────────────────────────────────────────────

  double _arcPosition(DateTime triggerDate, Decision decision) {
    final horizonDays = decision.decisionDeadline != null
        ? decision.decisionDeadline!
            .difference(decision.createdAt)
            .inDays
            .toDouble()
        : 365.0;
    final daysSince =
        triggerDate.difference(decision.createdAt).inDays.toDouble();
    if (horizonDays <= 0) return 0.05;
    return (daysSince / horizonDays).clamp(0.05, 1.0);
  }

  // ── Core row-builder ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildRows({
    required Decision decision,
    required List<OutcomeUpdate> outcomes, // must be sorted ASC by created_at
    required RiskAssessment? riskAssessment,
    required Set<String> skipOutcomeUpdateIds,
    required bool riskSignalExists,
  }) {
    final rows = <Map<String, dynamic>>[];
    final initial = (decision.initialConfidence ?? 5).toDouble();

    for (int i = 0; i < outcomes.length; i++) {
      final update = outcomes[i];
      if (skipOutcomeUpdateIds.contains(update.id)) continue;

      final arc = _arcPosition(update.createdAt, decision);
      final score = update.outcomeQualityScore.toDouble();

      if (i == 0) {
        // ── First update: first_review + optional overconfidence ─────────
        final delta = score - initial;
        rows.add({
          'decision_id': decision.id,
          'outcome_update_id': update.id,
          'trigger_date': update.createdAt.toUtc().toIso8601String(),
          'trigger_type': 'first_review',
          'title': 'First outcome review',
          'confidence_delta': delta,
          'influence_strength': 3,
          'arc_position': arc,
        });
        if (delta <= -2) {
          rows.add({
            'decision_id': decision.id,
            'outcome_update_id': update.id,
            'trigger_date': update.createdAt.toUtc().toIso8601String(),
            'trigger_type': 'overconfidence',
            'title': 'Overconfidence detected',
            'confidence_delta': delta,
            'influence_strength': 4,
            'arc_position': arc,
          });
        }
      } else {
        // ── Subsequent updates ───────────────────────────────────────────
        final prevScore = outcomes[i - 1].outcomeQualityScore.toDouble();
        if (score > prevScore + 1) {
          rows.add({
            'decision_id': decision.id,
            'outcome_update_id': update.id,
            'trigger_date': update.createdAt.toUtc().toIso8601String(),
            'trigger_type': 'positive_momentum',
            'title': 'Positive momentum',
            'confidence_delta': score - prevScore,
            'influence_strength': 3,
            'arc_position': arc,
          });
        }
        if (score >= 8) {
          rows.add({
            'decision_id': decision.id,
            'outcome_update_id': update.id,
            'trigger_date': update.createdAt.toUtc().toIso8601String(),
            'trigger_type': 'strong_outcome',
            'title': 'Strong outcome',
            'confidence_delta': 1.0,
            'influence_strength': 4,
            'arc_position': arc,
          });
        }
      }
    }

    // ── Risk signal: once per decision if approved assessment exists ──────
    if (!riskSignalExists &&
        riskAssessment != null &&
        riskAssessment.isApproved) {
      final approvedAt = riskAssessment.approvedAt!;
      rows.add({
        'decision_id': decision.id,
        'outcome_update_id': null,
        'trigger_date': approvedAt.toUtc().toIso8601String(),
        'trigger_type': 'risk_signal',
        'title': 'Risk factor identified',
        'confidence_delta': riskAssessment.confidenceImpact.toDouble(),
        'influence_strength': 3,
        'arc_position': _arcPosition(approvedAt, decision),
      });
    }

    return rows;
  }

  // ── Part A: backfill — called from compute() when triggers are empty ──────

  /// Generates and inserts triggers for [outcomes] with no existing triggers.
  /// Returns the newly inserted [ConfidenceTrigger] list.
  Future<List<ConfidenceTrigger>> generateAndInsert({
    required Decision decision,
    required List<OutcomeUpdate> outcomes,
    required RiskAssessment? riskAssessment,
  }) async {
    if (outcomes.isEmpty) return [];

    final sorted = List<OutcomeUpdate>.from(outcomes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final rows = _buildRows(
      decision: decision,
      outcomes: sorted,
      riskAssessment: riskAssessment,
      skipOutcomeUpdateIds: {},
      riskSignalExists: false,
    );

    if (rows.isEmpty) return [];

    try {
      final inserted = await supabase
          .from('confidence_triggers')
          .insert(rows)
          .select();
      return inserted
          .map((dynamic j) => _parseTrigger(j))
          .toList();
    } catch (e) {
      debugPrint('[ConfidenceTriggersService] generateAndInsert error: $e');
      return [];
    }
  }

  /// Safe parser: handles cached model objects, raw Maps, and
  /// dart2js Map types that are not strictly [Map] of String to dynamic.
  static ConfidenceTrigger _parseTrigger(dynamic item) {
    if (item is ConfidenceTrigger) return item;
    if (item is Map<String, dynamic>) return ConfidenceTrigger.fromJson(item);
    return ConfidenceTrigger.fromJson(Map<String, dynamic>.from(item as Map));
  }

  // ── Part B: forward-write — called after saveOutcomeUpdate ───────────────

  /// Self-contained: fetches all needed data, generates only triggers that
  /// are not yet present (by outcome_update_id), then inserts them.
  Future<void> inferForDecision(String decisionId) async {
    try {
      final decRow = await supabase
          .from('user_visible_decisions')
          .select()
          .eq('id', decisionId)
          .maybeSingle();
      if (decRow == null) return;
      final decision = Decision.fromJson(decRow);

      final outcomeRows = await supabase
          .from('user_visible_outcome_updates')
          .select()
          .eq('decision_id', decisionId)
          .order('created_at', ascending: true);
      if (outcomeRows.isEmpty) return;

      final outcomes =
          outcomeRows.map((r) => OutcomeUpdate.fromJson(r)).toList();

      final existingRows = await supabase
          .from('confidence_triggers')
          .select('outcome_update_id, trigger_type')
          .eq('decision_id', decisionId);

      final skipIds = existingRows
          .map((r) => r['outcome_update_id'] as String?)
          .whereType<String>()
          .toSet();
      final riskSignalExists =
          existingRows.any((r) => r['trigger_type'] == 'risk_signal');

      final riskRows = await supabase
          .from('risk_assessments')
          .select()
          .eq('decision_id', decisionId)
          .not('approved_at', 'is', null)
          .order('approved_at', ascending: false)
          .limit(1);
      final riskAssessment = riskRows.isNotEmpty
          ? RiskAssessment.fromJson(riskRows.first)
          : null;

      final rows = _buildRows(
        decision: decision,
        outcomes: outcomes,
        riskAssessment: riskAssessment,
        skipOutcomeUpdateIds: skipIds,
        riskSignalExists: riskSignalExists,
      );

      if (rows.isEmpty) return;
      await supabase.from('confidence_triggers').insert(rows);
    } catch (e) {
      debugPrint('[ConfidenceTriggersService] inferForDecision error: $e');
    }
  }

  // ── Part B: coach note trigger ────────────────────────────────────────────

  /// Inserts a single trigger derived from a coach note with a non-zero
  /// confidence adjustment. No-ops silently if adjustment is 0 or null.
  Future<void> insertCoachNoteTrigger(
      CoachNote note, String decisionId) async {
    final adj = note.coachConfidenceAdjustment ?? 0;
    if (adj == 0) return;

    try {
      final decRow = await supabase
          .from('user_visible_decisions')
          .select()
          .eq('id', decisionId)
          .maybeSingle();
      if (decRow == null) return;
      final decision = Decision.fromJson(decRow);

      final arc = _arcPosition(note.createdAt, decision);
      await supabase.from('confidence_triggers').insert({
        'decision_id': decisionId,
        'outcome_update_id': null,
        'trigger_date': note.createdAt.toUtc().toIso8601String(),
        'trigger_type': adj > 0 ? 'positive_momentum' : 'risk_signal',
        'title': 'Coach adjustment',
        'confidence_delta': adj.toDouble(),
        'influence_strength': 3,
        'arc_position': arc,
      });
    } catch (e) {
      debugPrint(
          '[ConfidenceTriggersService] insertCoachNoteTrigger error: $e');
    }
  }
}
