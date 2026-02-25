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
}
