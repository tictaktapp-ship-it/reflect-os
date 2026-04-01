import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

class RiskRepository {
  const RiskRepository();

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<RiskAssessment?> getLatestRiskAssessment(String decisionId) async {
    final rows = await supabase
        .from('risk_assessments')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return RiskAssessment.fromJson(rows.first);
  }

  Future<RiskAssessment?> getApprovedRiskAssessment(String decisionId) async {
    final rows = await supabase
        .from('risk_assessments')
        .select()
        .eq('decision_id', decisionId)
        .not('approved_at', 'is', null)
        .isFilter('deleted_at', null)
        .order('approved_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return RiskAssessment.fromJson(rows.first);
  }

  // ── AI generation ─────────────────────────────────────────────────────────

  /// Invokes the assess-risk Edge Function (Gemini). Returns the saved
  /// RiskAssessment (status = 'Pending').
  Future<RiskAssessment> generateRiskAssessment(String decisionId) async {
    final response = await supabase.functions.invoke(
      'assess-risk',
      body: {'decision_id': decisionId},
    );
    if (response.status >= 400) {
      throw Exception(
          'assess-risk failed (${response.status}): ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    return RiskAssessment.fromJson(data);
  }

  // ── Manual entry ──────────────────────────────────────────────────────────

  Future<RiskAssessment> saveManualRiskAssessment({
    required String decisionId,
    required List<Map<String, dynamic>> risks,
    required String overallRiskLevel,
  }) async {
    final row = await supabase
        .from('risk_assessments')
        .insert({
          'decision_id': decisionId,
          'methodology': 'custom',
          'manual_risks_jsonb': {'risks': risks},
          'overall_risk_level': overallRiskLevel,
          'output_jsonb': <String, dynamic>{},
          'provider': 'manual',
          'model': 'manual',
          'status': 'Pending',
        })
        .select()
        .single();
    return RiskAssessment.fromJson(row);
  }

  // ── Approval ──────────────────────────────────────────────────────────────

  Future<void> approveRiskAssessment({
    required String assessmentId,
    required String userId,
    required int confidenceImpact,
    required String overallRiskLevel,
  }) async {
    await supabase.from('risk_assessments').update({
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      'approved_by_user_id': userId,
      'confidence_impact': confidenceImpact,
      'overall_risk_level': overallRiskLevel,
      'status': 'approved',
    }).eq('id', assessmentId);
  }

  // ── Confidence impact ─────────────────────────────────────────────────────

  /// Sum of confidence_impact from all approved risk assessments.
  Future<int> getRiskConfidenceAdjustment(String decisionId) async {
    final rows = await supabase
        .from('risk_assessments')
        .select('confidence_impact')
        .eq('decision_id', decisionId)
        .not('approved_at', 'is', null)
        .isFilter('deleted_at', null);
    return rows.fold<int>(
      0,
      (sum, r) => sum + ((r['confidence_impact'] as num?)?.toInt() ?? 0),
    );
  }
}
