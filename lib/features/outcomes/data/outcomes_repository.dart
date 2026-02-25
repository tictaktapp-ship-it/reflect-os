import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';

class OutcomesRepository {
  const OutcomesRepository();

  Future<List<OutcomeUpdate>> getOutcomesForDecision(
      String decisionId) async {
    final rows = await supabase
        .from('user_visible_outcome_updates')
        .select()
        .eq('decision_id', decisionId)
        .order('created_at', ascending: false);

    return rows.map((row) => OutcomeUpdate.fromJson(row)).toList();
  }

  Future<void> saveOutcomeUpdate({
    required String decisionId,
    required int qualityScore,
    String? outcomeText,
    String? outcomeState,
    String? lessonsLearned,
  }) async {
    await supabase.rpc('save_outcome_update', params: {
      'p_decision_id': decisionId,
      'p_outcome_quality_score': qualityScore,
      'p_outcome_text_encrypted': ?outcomeText,
      'p_outcome_state': ?outcomeState,
      'p_lessons_learned_encrypted': ?lessonsLearned,
    });
  }
}
