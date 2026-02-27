import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

class RiskRepository {
  const RiskRepository();

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

  /// Invokes the assess-risk Edge Function. The function saves the result to
  /// risk_assessments and returns {assessment_id, output}. Callers should
  /// refresh riskAssessmentProvider after this returns successfully.
  Future<void> generateRiskAssessment(String decisionId) async {
    await supabase.functions.invoke(
      'assess-risk',
      body: {'decision_id': decisionId},
    );
  }
}
