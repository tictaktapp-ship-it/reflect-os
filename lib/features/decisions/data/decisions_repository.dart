import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
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

  /// Exception to the no-raw-tables rule: decisions table is written to
  /// directly. There is no RPC for creating decisions in the current schema.
  /// RLS on the decisions table ensures users can only insert into their
  /// own workspace.
  Future<String> createDecision(CreateDecisionInput input) async {
    final response = await supabase
        .from('decisions')
        .insert(input.toJson())
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Exception to the no-raw-tables rule: there is no user_visible_categories
  /// view in the schema. The categories table is queried directly here.
  /// RLS ensures users can only read categories belonging to their workspace.
  Future<List<Category>> getCategories(String workspaceId) async {
    final rows = await supabase
        .from('categories')
        .select('id, name')
        .eq('workspace_id', workspaceId)
        .order('name');

    return rows.map((row) => Category.fromJson(row)).toList();
  }
}
