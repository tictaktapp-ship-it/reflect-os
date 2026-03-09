import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/services/encryption_service.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/approval_record.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/decisions/data/models/comment.dart';
import 'package:reflect_os/features/decisions/data/models/comment_thread.dart';
import 'package:reflect_os/features/decisions/data/models/decision_relationship.dart';
import 'package:reflect_os/features/decisions/data/models/decision_stakeholder.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';

class DecisionsRepository {
  const DecisionsRepository();

  // ── Encryption helpers ────────────────────────────────────────────────────

  EncryptionService get _enc => EncryptionService(supabase);

  /// Reads encryption mode; defaults to 'encrypted' when no row exists.
  Future<String?> _getEncryptionMode(String workspaceId) async {
    final result = await supabase
        .from(SupabaseTables.workspaceSettings)
        .select('encryption_mode')
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return result?['encryption_mode'] as String?;
  }

  /// Returns the current user's workspace_id via the subscriptions table.
  Future<String?> _getWorkspaceId() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await supabase
        .from('subscriptions')
        .select('workspace_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['workspace_id'] as String?;
  }

  bool _shouldEncrypt(String? mode) => mode != 'plaintext';

  /// Decrypts the three encrypted content fields for a single [row].
  Future<Map<String, dynamic>> _decryptRow(
      Map<String, dynamic> row, String workspaceId) async {
    final rawDesc = row['description_encrypted'] as String?;
    final rawCtx = row['situational_context_encrypted'] as String?;
    final rawOutcome = row['projected_outcome_encrypted'] as String?;

    try {
      final decrypted = await _enc.decryptFields(
        workspaceId: workspaceId,
        fields: {
          'description': rawDesc,
          'context': rawCtx,
          'outcome': rawOutcome,
        },
      );
      final out = Map<String, dynamic>.from(row);
      out['description_encrypted'] = decrypted['description'];
      out['situational_context_encrypted'] = decrypted['context'];
      out['projected_outcome_encrypted'] = decrypted['outcome'];
      return out;
    } catch (_) {
      // Edge function unavailable — return as-is (legacy plaintext or offline).
      return row;
    }
  }

  /// Decrypts all rows in a single batched edge-function call.
  Future<List<Map<String, dynamic>>> _decryptRows(
      List<Map<String, dynamic>> rows, String workspaceId) async {
    if (rows.isEmpty) return rows;
    // Batch all fields into one call, keyed by "<id>:field".
    final batch = <String, String?>{};
    for (final row in rows) {
      final id = row['id'] as String;
      batch['$id:description'] = row['description_encrypted'] as String?;
      batch['$id:context'] =
          row['situational_context_encrypted'] as String?;
      batch['$id:outcome'] = row['projected_outcome_encrypted'] as String?;
    }
    try {
      final decrypted = await _enc.decryptFields(
        workspaceId: workspaceId,
        fields: batch,
      );
      return rows.map((row) {
        final id = row['id'] as String;
        final out = Map<String, dynamic>.from(row);
        out['description_encrypted'] = decrypted['$id:description'];
        out['situational_context_encrypted'] = decrypted['$id:context'];
        out['projected_outcome_encrypted'] = decrypted['$id:outcome'];
        return out;
      }).toList();
    } catch (_) {
      return rows;
    }
  }

  // ── Reads ─────────────────────────────────────────────────────────────────

  Future<List<Decision>> getDecisions() async {
    final rows = await supabase
        .from('user_visible_decisions')
        .select()
        .order('created_at', ascending: false);

    if (rows.isEmpty) return [];

    // workspace_id is sourced from the decisions table via the view.
    // All rows belong to the same workspace under RLS.
    final workspaceId = rows.first['workspace_id'] as String?;
    final decryptedRows = workspaceId != null
        ? await _decryptRows(rows, workspaceId)
        : rows;
    return decryptedRows.map(Decision.fromJson).toList();
  }

  Future<Decision?> getDecisionById(String id) async {
    final row = await supabase
        .from('user_visible_decisions')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    final workspaceId = row['workspace_id'] as String?;
    final mapped =
        workspaceId != null ? await _decryptRow(row, workspaceId) : row;
    return Decision.fromJson(mapped);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Exception to the no-raw-tables rule: decisions table is written to
  /// directly. There is no RPC for creating decisions in the current schema.
  Future<String> createDecision(CreateDecisionInput input) async {
    final mode = await _getEncryptionMode(input.workspaceId);
    final doEncrypt = _shouldEncrypt(mode);
    final workspaceId = input.workspaceId;

    final userId = supabase.auth.currentUser!.id;
    final payload = {
      ...input.toJson(),
      'created_by_user_id': userId,
      'owner_user_id': userId,
      'state': 'Draft',
    };

    if (doEncrypt) {
      final desc = payload['description_encrypted'] as String?;
      final ctx = payload['situational_context_encrypted'] as String?;
      final outcome = payload['projected_outcome_encrypted'] as String?;

      final hasContent = (desc != null && desc.isNotEmpty) ||
          (ctx != null && ctx.isNotEmpty) ||
          (outcome != null && outcome.isNotEmpty);

      if (hasContent) {
        try {
          final encrypted = await _enc.encryptFields(
            workspaceId: workspaceId,
            fields: {
              'description': desc,
              'context': ctx,
              'outcome': outcome,
            },
          );
          if (encrypted['description'] != null) {
            payload['description_encrypted'] = encrypted['description'];
          }
          if (encrypted['context'] != null) {
            payload['situational_context_encrypted'] = encrypted['context'];
          }
          if (encrypted['outcome'] != null) {
            payload['projected_outcome_encrypted'] = encrypted['outcome'];
          }
        } catch (_) {
          // Edge function unavailable — persist as plaintext (degraded mode).
        }
      }
    }

    final response = await supabase
        .from('decisions')
        .insert(payload)
        .select('id')
        .single();

    final decisionId = response['id'] as String;

    // Fire-and-forget: sync checkpoints/deadline to calendar if connected.
    supabase.functions.invoke(
      'calendar-sync',
      body: {'workspace_id': workspaceId, 'decision_id': decisionId},
    ).ignore();

    return decisionId;
  }

  /// Exception to the no-raw-tables rule: no RPC exists for updating decisions.
  /// Only sends the fields present in [fields] — callers diff before calling.
  Future<void> updateDecision(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;

    const encryptedDbKeys = {
      'description_encrypted',
      'situational_context_encrypted',
      'projected_outcome_encrypted',
    };

    final hasEncryptedContent = fields.keys.any(encryptedDbKeys.contains);
    Map<String, dynamic> toSave = fields;

    if (hasEncryptedContent) {
      final workspaceId = await _getWorkspaceId();
      if (workspaceId != null) {
        final mode = await _getEncryptionMode(workspaceId);
        if (_shouldEncrypt(mode)) {
          final desc = fields['description_encrypted'] as String?;
          final ctx = fields['situational_context_encrypted'] as String?;
          final outcome = fields['projected_outcome_encrypted'] as String?;

          try {
            final encrypted = await _enc.encryptFields(
              workspaceId: workspaceId,
              fields: {
                'description': desc,
                'context': ctx,
                'outcome': outcome,
              },
            );
            toSave = Map<String, dynamic>.from(fields);
            if (encrypted['description'] != null) {
              toSave['description_encrypted'] = encrypted['description'];
            }
            if (encrypted['context'] != null) {
              toSave['situational_context_encrypted'] = encrypted['context'];
            }
            if (encrypted['outcome'] != null) {
              toSave['projected_outcome_encrypted'] = encrypted['outcome'];
            }
          } catch (_) {
            // Edge function unavailable — persist as-is.
          }
        }
      }
    }

    await supabase.from('decisions').update(toSave).eq('id', id);
  }

  // ── Search ────────────────────────────────────────────────────────────────

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

    final rpcRows = await supabase.rpc('search_decisions', params: {
      'query_text': query,
      'workspace_id': workspaceId,
      'filters_json': '{}',
    }) as List<dynamic>;

    if (rpcRows.isEmpty) return [];

    final ranked = rpcRows.cast<Map<String, dynamic>>();
    final ids = ranked.map((r) => r['decision_id'] as String).toList();

    final rows = await supabase
        .from('user_visible_decisions')
        .select()
        .inFilter('id', ids);

    final decryptedRows = await _decryptRows(rows, workspaceId);
    final byId = <String, Decision>{
      for (final row in decryptedRows)
        row['id'] as String: Decision.fromJson(row),
    };
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  // ── Lifecycle RPCs ────────────────────────────────────────────────────────

  Future<void> shareDecisionToTeam(
      String decisionId, String targetWorkspaceId) async {
    await supabase.rpc('share_decision_to_team', params: {
      'p_decision_id': decisionId,
      'p_target_workspace_id': targetWorkspaceId,
      'p_user_id': supabase.auth.currentUser!.id,
      'p_now': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDecision(String id) async {
    await supabase
        .from('decisions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
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

  // ── Checkpoints ───────────────────────────────────────────────────────────

  Future<List<ReviewCheckpoint>> getUpcomingCheckpoints() async {
    final cutoff =
        DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String();
    final rows = await supabase
        .from('review_checkpoints')
        .select()
        .eq('status', 'Scheduled')
        .lte('due_at', cutoff)
        .isFilter('deleted_at', null)
        .order('due_at');
    return rows.map((row) => ReviewCheckpoint.fromJson(row)).toList();
  }

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

  // ── Stakeholders ──────────────────────────────────────────────────────────

  Future<List<DecisionStakeholder>> getStakeholders(
      String decisionId) async {
    final rows = await supabase
        .from('decision_stakeholders')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null);
    return rows.map((row) => DecisionStakeholder.fromJson(row)).toList();
  }

  Future<void> addStakeholder(
      String decisionId, String userId, String role) async {
    await supabase.from('decision_stakeholders').insert({
      'decision_id': decisionId,
      'user_id': userId,
      'stakeholder_role': role,
    });
  }

  Future<void> removeStakeholder(String decisionId, String userId) async {
    await supabase
        .from('decision_stakeholders')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('decision_id', decisionId)
        .eq('user_id', userId)
        .isFilter('deleted_at', null);
  }

  // ── Audit ─────────────────────────────────────────────────────────────────

  Future<List<AuditEvent>> getAuditEventsForDecision(
      String decisionId, String workspaceId) async {
    final rows = await supabase
        .from('audit_events')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('subject_entity_id', decisionId)
        .eq('subject_entity_type', 'decision')
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((row) => AuditEvent.fromJson(row)).toList();
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<CommentThread?> getCommentThread(String decisionId) async {
    final row = await supabase
        .from('comment_threads')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return CommentThread.fromJson(row);
  }

  Future<List<Comment>> getComments(String threadId) async {
    final rows = await supabase
        .from('comments')
        .select()
        .eq('thread_id', threadId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return rows.map((row) => Comment.fromJson(row)).toList();
  }

  Future<void> postComment(String threadId, String body) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase.from('comments').insert({
      'thread_id': threadId,
      'author_user_id': supabase.auth.currentUser!.id,
      'body_encrypted': body,
      'created_at': now,
      'updated_at': now,
    });
  }

  // ── Relationships ─────────────────────────────────────────────────────────

  Future<List<DecisionRelationship>> getRelationshipsForDecision(
      String decisionId) async {
    final rows = await supabase
        .from('user_visible_decision_relationships')
        .select()
        .or('from_decision_id.eq.$decisionId,to_decision_id.eq.$decisionId')
        .isFilter('deleted_at', null);
    return rows.map((row) => DecisionRelationship.fromJson(row)).toList();
  }

  Future<void> addRelationship(
    String fromDecisionId,
    String toDecisionId,
    String relationshipType,
    String workspaceId,
  ) async {
    await supabase.from('decision_relationships').insert({
      'from_decision_id': fromDecisionId,
      'to_decision_id': toDecisionId,
      'relationship_type': relationshipType,
      'workspace_id': workspaceId,
    });
  }

  Future<void> removeRelationship(String id) async {
    await supabase
        .from('decision_relationships')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Approval records ──────────────────────────────────────────────────────

  Future<List<ApprovalRecord>> getApprovalRecords(String decisionId) async {
    final rows = await supabase
        .from('approval_records')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return rows.map((row) => ApprovalRecord.fromJson(row)).toList();
  }

  Future<void> requestApproval(
      String decisionId, String approverUserId) async {
    await supabase.from('approval_records').insert({
      'decision_id': decisionId,
      'approver_user_id': approverUserId,
      'status': 'Pending',
    });
  }

  Future<void> approveDecision(String approvalRecordId) async {
    await supabase.from('approval_records').update({
      'status': 'Approved',
      'decided_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', approvalRecordId);
  }

  Future<void> rejectDecision(String approvalRecordId) async {
    await supabase.from('approval_records').update({
      'status': 'Rejected',
      'decided_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', approvalRecordId);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> getCategories(String workspaceId) async {
    final rows = await supabase
        .from('categories')
        .select('id, name')
        .eq('workspace_id', workspaceId)
        .order('name');
    return rows.map((row) => Category.fromJson(row)).toList();
  }
}
