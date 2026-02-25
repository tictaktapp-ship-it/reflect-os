import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';

class DecisionsRepository {
  const DecisionsRepository();

  Future<List<Decision>> getDecisions() async {
    final rows = await supabase
        .from('user_visible_decisions')
        .select()
        .order('created_at', ascending: false);

    return rows.map((row) => Decision.fromJson(row)).toList();
  }

  Future<Decision?> getDecisionById(String id) async {
    final row = await supabase
        .from('user_visible_decisions')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return Decision.fromJson(row);
  }
}
