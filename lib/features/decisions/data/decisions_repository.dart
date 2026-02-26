import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';

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
  /// RLS INSERT policy requires created_by_user_id = auth.uid(),
  /// owner_user_id = auth.uid(), and state = 'Draft'.
  Future<String> createDecision(CreateDecisionInput input) async {
    final userId = supabase.auth.currentUser!.id;
    final payload = {
      ...input.toJson(),
      'created_by_user_id': userId,
      'owner_user_id': userId,
      'state': 'Draft',
    };

    final response = await supabase
        .from('decisions')
        .insert(payload)
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Two-step search: calls search_decisions RPC (returns ranked decision_ids),
  /// then fetches full rows from user_visible_decisions and reorders by rank.
  /// workspace_id is read from the subscriptions table (same RLS exception as
  /// createDecision). Returns empty list for blank queries.
  Future<List<Decision>> searchDecisions(String query) async {
    if (query.trim().isEmpty) return [];

    final userId = supabase.auth.currentUser!.id;
    final subRow = await supabase
        .from('subscriptions')
        .select('workspace_id')
        .eq('user_id', userId)
        .maybeSingle();
    final workspaceId = subRow?['workspace_id'] as String?;
    if (workspaceId == null) return [];

    // Step 1: RPC returns [{decision_id, rank}, …] ordered by rank desc.
    final rpcRows = await supabase.rpc('search_decisions', params: {
      'query_text': query,
      'workspace_id': workspaceId,
      'filters_json': '{}',
    }) as List<dynamic>;

    if (rpcRows.isEmpty) return [];

    final ranked = rpcRows.cast<Map<String, dynamic>>();
    final ids = ranked.map((r) => r['decision_id'] as String).toList();

    // Step 2: Fetch full decision rows for those ids.
    final rows = await supabase
        .from('user_visible_decisions')
        .select()
        .inFilter('id', ids);

    // Step 3: Reorder by rank (preserve RPC order).
    final byId = <String, Decision>{
      for (final row in rows)
        row['id'] as String: Decision.fromJson(row),
    };
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  /// Exception to the no-raw-tables rule: no RPC exists for updating decisions.
  /// Only sends the fields present in [fields] — callers diff before calling.
  Future<void> updateDecision(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    await supabase.from('decisions').update(fields).eq('id', id);
  }

  Future<void> activateDecision(String id) async {
    await supabase.rpc('activate_decision', params: {'p_decision_id': id});
  }

  Future<void> closeDecision(String id) async {
    await supabase.rpc('close_decision', params: {'p_decision_id': id});
  }

  Future<void> reopenDecision(String id) async {
    await supabase.rpc('reopen_decision', params: {'p_decision_id': id});
  }

  Future<void> archiveDecision(String id) async {
    await supabase.rpc('archive_decision', params: {'p_decision_id': id});
  }

  Future<void> unarchiveDecision(String id, String newState) async {
    await supabase.rpc('unarchive_decision', params: {
      'p_decision_id': id,
      'p_new_state': newState,
    });
  }

  /// RLS is SELECT-only — checkpoints are created by the activate_decision RPC.
  Future<List<ReviewCheckpoint>> getCheckpointsForDecision(
      String decisionId) async {
    final rows = await supabase
        .from('review_checkpoints')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('due_at');

    return rows.map((row) => ReviewCheckpoint.fromJson(row)).toList();
  }

  /// SELECT-only — audit_events_select_owner RLS policy gates access.
  Future<List<AuditEvent>> getAuditEventsForDecision(
      String decisionId) async {
    final rows = await supabase
        .from('audit_events')
        .select()
        .eq('subject_entity_id', decisionId)
        .eq('subject_entity_type', 'decision')
        .order('created_at', ascending: false)
        .limit(20);

    return rows.map((row) => AuditEvent.fromJson(row)).toList();
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
