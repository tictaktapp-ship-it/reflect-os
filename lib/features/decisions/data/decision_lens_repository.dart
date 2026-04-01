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

  Future<DecisionLensData> compute({
    required Decision decision,
    required List<DecisionStakeholder> stakeholders,
    required RiskAssessment? riskAssessment,
    required List<EvidenceItem> evidence,
    required List<OutcomeUpdate> outcomes,
  }) async {
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

    var triggers = await _fetchTriggers(decision.id);

    // Part A: backfill triggers for decisions that have outcome reviews but
    // no confidence_triggers rows yet (e.g. all historical decisions).
    if (triggers.isEmpty && outcomes.isNotEmpty) {
      triggers = await const ConfidenceTriggersService().generateAndInsert(
        decision: decision,
        outcomes: outcomes,
        riskAssessment: riskAssessment,
      );
    }

    return DecisionLensData(
      confidenceScore: confidenceScore,
      healthScore: healthScore,
      influenceNodes: nodes,
      scoreComponents: scoreComponents,
      triggers: triggers,
    );
  }

  Future<List<ConfidenceTrigger>> _fetchTriggers(String decisionId) async {
    final response = await supabase
        .from('confidence_triggers')
        .select()
        .eq('decision_id', decisionId)
        .order('arc_position', ascending: true);

    return response
        .map((dynamic j) => _parseTrigger(j))
        .toList();
  }

  /// Safe parser: handles cached model objects, raw Maps, and
  /// dart2js Map types that are not strictly [Map] of String to dynamic.
  static ConfidenceTrigger _parseTrigger(dynamic item) {
    if (item is ConfidenceTrigger) return item;
    if (item is Map<String, dynamic>) return ConfidenceTrigger.fromJson(item);
    return ConfidenceTrigger.fromJson(Map<String, dynamic>.from(item as Map));
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
