import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/debrief/data/models/decision_debrief.dart';

class DebriefRepository {
  const DebriefRepository();

  Future<DecisionDebrief?> getLatestDebrief(String decisionId) async {
    final rows = await supabase
        .from('decision_debriefs')
        .select()
        .eq('decision_id', decisionId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DecisionDebrief.fromJson(rows.first);
  }

  /// Invokes the generate-debrief Edge Function. Callers should refresh
  /// debriefProvider after this returns successfully.
  Future<void> generateDebrief(String decisionId) async {
    await supabase.functions.invoke(
      'generate-debrief',
      body: {'decision_id': decisionId},
    );
  }

  Future<void> saveFeedback(String debriefId, String feedback) async {
    await supabase
        .from('decision_debriefs')
        .update({'user_feedback': feedback})
        .eq('id', debriefId);
  }
}
