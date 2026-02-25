import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';

class InitiativesRepository {
  const InitiativesRepository();

  Future<List<Initiative>> getInitiatives() async {
    final rows = await supabase
        .from('user_visible_initiatives')
        .select()
        .order('name');

    return rows.map((row) => Initiative.fromJson(row)).toList();
  }

  /// Exception to the no-raw-tables rule: no RPC exists for creating initiatives.
  /// No RLS on initiatives table — workspace_id must be provided explicitly.
  Future<String> createInitiative({
    required String name,
    required String workspaceId,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'workspace_id': workspaceId,
      'name': name,
      if (description != null && description.isNotEmpty)
        'description_encrypted': description,
    };

    final response = await supabase
        .from('initiatives')
        .insert(payload)
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<Initiative>> getInitiativesForDecision(
      String decisionId) async {
    // Step 1: get initiative_ids for this decision from the join view.
    final joinRows = await supabase
        .from('user_visible_decision_initiatives')
        .select('initiative_id')
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null);

    if (joinRows.isEmpty) return [];

    final ids =
        joinRows.map((r) => r['initiative_id'] as String).toList();

    // Step 2: fetch full initiative details ordered by name.
    final rows = await supabase
        .from('user_visible_initiatives')
        .select()
        .inFilter('id', ids)
        .order('name');

    return rows.map((row) => Initiative.fromJson(row)).toList();
  }
}
