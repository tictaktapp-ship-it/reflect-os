import 'package:reflect_os/core/supabase/supabase_client.dart';
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
        value: (evidence.length / 5).clamp(0.0, 1.0),
        displayValue: '${evidence.length} item${evidence.length == 1 ? '' : 's'}',
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

    final triggers = await _fetchTriggers(decision.id);

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

    return (response as List)
        .map((j) => ConfidenceTrigger.fromJson(j as Map<String, dynamic>))
        .toList();
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
