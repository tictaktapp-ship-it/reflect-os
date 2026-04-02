import 'package:flutter/foundation.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/confidence_triggers_service.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/data/models/decision_stakeholder.dart';
import 'package:reflect_os/features/evidence/data/models/evidence_item.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

class DecisionLensRepository {
  const DecisionLensRepository();

  // ── Public entry-point ─────────────────────────────────────────────────────
  //
  // Fetches every table with a separate independent query (no JOINs).
  // This prevents Cartesian-product row explosion when a decision has multiple
  // outcome updates, triggers, coach notes and a risk assessment.

  Future<DecisionLensData> fetchAndCompute(String decisionId) async {
    // 1. Decision row — abort early if missing.
    final decRow = await supabase
        .from('user_visible_decisions')
        .select()
        .eq('id', decisionId)
        .maybeSingle();
    if (decRow == null) throw Exception('Decision not found: $decisionId');
    final decision = Decision.fromJson(_toMap(decRow));

    // 2. Remaining tables — all separate queries, run in parallel.
    final results = await Future.wait([
      supabase // [0] outcome_updates
          .from('user_visible_outcome_updates')
          .select()
          .eq('decision_id', decisionId)
          .order('created_at', ascending: true),
      supabase // [1] confidence_triggers
          .from('confidence_triggers')
          .select()
          .eq('decision_id', decisionId)
          .order('arc_position', ascending: true),
      supabase // [2] risk_assessments
          .from('risk_assessments')
          .select()
          .eq('decision_id', decisionId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1),
      supabase // [3] evidence_items
          .from('user_visible_evidence_items')
          .select()
          .eq('decision_id', decisionId),
      supabase // [4] decision_stakeholders
          .from('decision_stakeholders')
          .select()
          .eq('decision_id', decisionId),
    ]);

    final outcomes = _parseList<OutcomeUpdate>(
        results[0], (m) => OutcomeUpdate.fromJson(m));

    var triggers = _parseList<ConfidenceTrigger>(
        results[1], (m) => ConfidenceTrigger.fromJson(m));

    final riskRows = results[2] as List;
    final riskAssessment = riskRows.isNotEmpty
        ? _safeParseOrNull(riskRows.first, RiskAssessment.fromJson)
        : null;

    final evidence = _parseList<EvidenceItem>(
        results[3], (m) => EvidenceItem.fromJson(m));

    final stakeholders = _parseList<DecisionStakeholder>(
        results[4], (m) => DecisionStakeholder.fromJson(m));

    // 3. Backfill triggers for decisions that have outcomes but no triggers yet.
    if (triggers.isEmpty && outcomes.isNotEmpty) {
      triggers = await const ConfidenceTriggersService().generateAndInsert(
        decision: decision,
        outcomes: outcomes,
        riskAssessment: riskAssessment,
      );
    }

    return _buildLensData(
      decision: decision,
      stakeholders: stakeholders,
      riskAssessment: riskAssessment,
      evidence: evidence,
      outcomes: outcomes,
      triggers: triggers,
    );
  }

  // ── Core computation (pure — no I/O) ───────────────────────────────────────

  DecisionLensData _buildLensData({
    required Decision decision,
    required List<DecisionStakeholder> stakeholders,
    required RiskAssessment? riskAssessment,
    required List<EvidenceItem> evidence,
    required List<OutcomeUpdate> outcomes,
    required List<ConfidenceTrigger> triggers,
  }) {
    final confidenceScore = (decision.initialConfidence ?? 5).toDouble();

    final healthScore = switch (decision.healthState) {
      'on_track' => 90,
      'needs_attention' => 50,
      'overdue' => 20,
      _ => 65,
    };

    final nodes = <InfluenceNode>[
      ...stakeholders.map(
        (s) => InfluenceNode(
          label: s.stakeholderRole,
          type: 'stakeholder',
          subtitle: s.displayName,
        ),
      ),
      if (riskAssessment != null)
        ...riskAssessment.risks.take(5).map((r) {
          final rawLabel = (r['title'] as String?) ??
              (r['description'] as String? ?? 'Risk');
          final shortLabel = rawLabel.split(' ').take(5).join(' ');
          return InfluenceNode(
            label: shortLabel,
            type: 'risk',
            subtitle: r['severity'] as String?,
          );
        }),
      ...evidence.take(5).map(
            (e) => InfluenceNode(
              label: e.label ?? e.originalFilename ?? 'Evidence',
              type: 'evidence',
              subtitle: e.type,
            ),
          ),
    ];

    final scoreComponents = [
      ScoreComponent(
        label: 'Confidence',
        value: (confidenceScore / 10).clamp(0.0, 1.0),
        displayValue: '${confidenceScore.toStringAsFixed(0)}/10',
      ),
      ScoreComponent(
        label: 'Evidence',
        value: outcomes.isEmpty
            ? 0.0
            : (outcomes
                        .map((o) => o.outcomeQualityScore)
                        .reduce((a, b) => a + b) /
                    outcomes.length /
                    10.0)
                .clamp(0.0, 1.0),
        displayValue: outcomes.isEmpty
            ? 'No reviews'
            : 'Avg ${(outcomes.map((o) => o.outcomeQualityScore).reduce((a, b) => a + b) / outcomes.length).toStringAsFixed(1)}/10',
      ),
      ScoreComponent(
        label: 'Risk',
        value: _riskScore(riskAssessment),
        displayValue: riskAssessment?.overallRiskLevel?.capitalize() ??
            'No assessment',
      ),
      ScoreComponent(
        label: 'Stakeholders',
        value: (stakeholders.length / 5).clamp(0.0, 1.0),
        displayValue: '${stakeholders.length}',
      ),
    ];

    return DecisionLensData(
      confidenceScore: confidenceScore,
      healthScore: healthScore,
      influenceNodes: nodes,
      scoreComponents: scoreComponents,
      triggers: triggers,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Materialises a concrete [Map<String, dynamic>] from any Map-like value.
  static Map<String, dynamic> _toMap(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    throw StateError('Cannot convert ${item.runtimeType} to Map<String, dynamic>');
  }

  /// Null-safe list parser — skips any row that fails to parse.
  static List<T> _parseList<T>(
    dynamic rows,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (rows is! List) return [];
    final result = <T>[];
    for (final item in rows) {
      try {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        result.add(fromJson(map));
      } catch (e) {
        debugPrint('[DecisionLensRepository] row parse error: $e\n  row: $item');
      }
    }
    return result;
  }

  /// Safe single-item parser — returns null if parsing fails.
  static T? _safeParseOrNull<T>(
    dynamic item,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      return fromJson(_toMap(item));
    } catch (e) {
      debugPrint('[DecisionLensRepository] single parse error: $e');
      return null;
    }
  }

  double _riskScore(RiskAssessment? assessment) {
    if (assessment == null) return 0.5;
    return switch (assessment.overallRiskLevel?.toLowerCase()) {
      'low' => 0.85,
      'medium' => 0.60,
      'high' => 0.30,
      'critical' => 0.10,
      _ => 0.50,
    };
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
