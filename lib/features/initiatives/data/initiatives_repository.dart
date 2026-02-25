import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
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

  Future<Initiative?> getInitiativeById(String id) async {
    final row = await supabase
        .from('user_visible_initiatives')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return Initiative.fromJson(row);
  }

  Future<List<Decision>> getDecisionsForInitiative(
      String initiativeId) async {
    // Step 1: get decision_ids linked to this initiative from the join view.
    final joinRows = await supabase
        .from('user_visible_decision_initiatives')
        .select('decision_id')
        .eq('initiative_id', initiativeId)
        .isFilter('deleted_at', null);

    if (joinRows.isEmpty) return [];

    final ids =
        joinRows.map((r) => r['decision_id'] as String).toList();

    // Step 2: fetch full decision rows ordered by created_at desc.
    final rows = await supabase
        .from('user_visible_decisions')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);

    return rows.map((row) => Decision.fromJson(row)).toList();
  }

  /// Exception to the no-raw-tables rule: no RPC exists for linking initiatives.
  /// No RLS on decision_initiatives — both ids must be provided explicitly.
  Future<void> linkInitiativeToDecision(
      String decisionId, String initiativeId) async {
    await supabase.from('decision_initiatives').insert({
      'decision_id': decisionId,
      'initiative_id': initiativeId,
    });
  }

  /// Soft-delete: sets deleted_at = now() on the matching active row.
  Future<void> unlinkInitiativeFromDecision(
      String decisionId, String initiativeId) async {
    await supabase
        .from('decision_initiatives')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('decision_id', decisionId)
        .eq('initiative_id', initiativeId)
        .isFilter('deleted_at', null);
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
