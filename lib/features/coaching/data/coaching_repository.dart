import 'dart:async';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/data/models/coach_shared_decision.dart';
import 'package:reflect_os/features/coaching/data/models/cross_client_dashboard.dart';
import 'package:reflect_os/features/decisions/data/confidence_triggers_service.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';

class CoachingRepository {
  const CoachingRepository();

  // ── Relationships ──────────────────────────────────────────────────────────

  Future<List<CoachClientRelationship>> getMyClients() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_client_relationships')
        .select()
        .eq('coach_user_id', uid)
        .eq('status', 'Active')
        .isFilter('deleted_at', null)
        .order('granted_at');
    return rows.map((r) => CoachClientRelationship.fromJson(r)).toList();
  }

  Future<List<CoachClientRelationship>> getMyCoaches() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_client_relationships')
        .select()
        .eq('client_user_id', uid)
        .eq('status', 'Active')
        .isFilter('deleted_at', null)
        .order('granted_at');
    return rows.map((r) => CoachClientRelationship.fromJson(r)).toList();
  }

  Future<List<CoachClientRelationship>> getMyClientsAll() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_client_relationships')
        .select()
        .eq('coach_user_id', uid)
        .isFilter('deleted_at', null)
        .order('granted_at');
    return rows.map((r) => CoachClientRelationship.fromJson(r)).toList();
  }

  Future<List<CoachClientRelationship>> getMyCoachesAll() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_client_relationships')
        .select()
        .eq('client_user_id', uid)
        .isFilter('deleted_at', null)
        .order('granted_at');
    return rows.map((r) => CoachClientRelationship.fromJson(r)).toList();
  }

  /// Coach invites a client by email. Inserts into coach_client_relationships.
  Future<void> inviteClient(String clientEmail) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await supabase.from('coach_client_relationships').insert({
      'coach_user_id': uid,
      'invited_email': clientEmail,
      'status': 'Active',
      'granted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Client invites a coach by email. Inserts into coach_client_relationships.
  Future<void> inviteCoach(String coachEmail) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await supabase.from('coach_client_relationships').insert({
      'client_user_id': uid,
      'invited_email': coachEmail,
      'status': 'Active',
      'granted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> revokeClient(String relationshipId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('coach_client_relationships')
        .update({'status': 'Revoked', 'revoked_at': now, 'deleted_at': now})
        .eq('id', relationshipId);
  }

  Future<void> updateRelationshipFields(
    String relationshipId, {
    String? focusAreas,
    String? goals,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (focusAreas != null) updates['focus_areas_encrypted'] = focusAreas;
    if (goals != null) updates['goals_encrypted'] = goals;
    if (notes != null) updates['notes_encrypted'] = notes;
    if (updates.isEmpty) return;
    await supabase
        .from('coach_client_relationships')
        .update(updates)
        .eq('id', relationshipId);
  }

  // ── Shared Decisions ───────────────────────────────────────────────────────

  static const _sharedDecisionSelect =
      'id, coach_user_id, client_user_id, decision_id, shared_at, revoked_at, created_at, '
      'decisions(id, title, state, stakes, initial_confidence, health_state, category_name, created_at)';

  /// Coach: get decisions a specific client has shared with this coach.
  Future<List<CoachSharedDecision>> getSharedDecisionsForClient(
      String clientUserId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_shared_decisions')
        .select(_sharedDecisionSelect)
        .eq('coach_user_id', uid)
        .eq('client_user_id', clientUserId)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return rows.map((r) => CoachSharedDecision.fromJson(r)).toList();
  }

  /// Client: get all decisions this user has shared with any coach.
  Future<List<CoachSharedDecision>> getMySharedDecisions() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_shared_decisions')
        .select(_sharedDecisionSelect)
        .eq('client_user_id', uid)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return rows.map((r) => CoachSharedDecision.fromJson(r)).toList();
  }

  /// Client: share a decision with a coach (upserts to handle re-sharing).
  Future<void> shareDecisionWithCoach({
    required String coachUserId,
    required String decisionId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await supabase.from('coach_shared_decisions').upsert(
      {
        'coach_user_id': coachUserId,
        'client_user_id': uid,
        'decision_id': decisionId,
        'shared_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_at': null,
      },
      onConflict: 'coach_user_id,client_user_id,decision_id',
    );
  }

  /// Client: revoke a previously shared decision.
  Future<void> revokeSharedDecision(String id) async {
    await supabase
        .from('coach_shared_decisions')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Cross-client Dashboard ─────────────────────────────────────────────────

  Future<CrossClientDashboard> getCrossClientDashboard() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const CrossClientDashboard.empty();

    // All shared decisions across all clients
    final List<dynamic> sharedRows = await supabase
        .from('coach_shared_decisions')
        .select(
            'decision_id, client_user_id, decisions(title, state, health_state)')
        .eq('coach_user_id', uid)
        .isFilter('revoked_at', null);

    // Build client name map from relationships
    final List<dynamic> clientRows = await supabase
        .from('coach_client_relationships')
        .select('client_user_id, invited_email')
        .eq('coach_user_id', uid)
        .eq('status', 'Active')
        .isFilter('deleted_at', null);

    final clientNames = <String, String>{};
    for (final r in clientRows) {
      final cid = r['client_user_id'] as String?;
      if (cid != null) {
        clientNames[cid] =
            r['invited_email'] as String? ?? 'Client ${cid.substring(0, 6)}';
      }
    }

    int totalActive = 0;
    int overdueCount = 0;
    final attentionItems = <AttentionDecision>[];

    for (final row in sharedRows) {
      final d = row['decisions'] as Map<String, dynamic>?;
      if (d == null) continue;
      final state = d['state'] as String? ?? '';
      final healthState = d['health_state'] as String? ?? '';
      if (state != 'Archived') {
        totalActive++;
        if (healthState == 'overdue' || healthState == 'needs_attention') {
          overdueCount++;
          final cid = row['client_user_id'] as String;
          attentionItems.add(AttentionDecision(
            clientUserId: cid,
            clientName:
                clientNames[cid] ?? 'Client ${cid.substring(0, 6)}',
            decisionId: row['decision_id'] as String,
            decisionTitle: d['title'] as String? ?? 'Untitled',
            healthState: healthState,
          ));
        }
      }
    }

    // Sessions this month
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final endOfMonth =
        DateTime(now.year, now.month + 1, 1).toUtc().toIso8601String();

    final List<dynamic> sessionsThisMonthRows = await supabase
        .from('coaching_sessions')
        .select('id')
        .eq('coach_user_id', uid)
        .gte('scheduled_at', startOfMonth)
        .lt('scheduled_at', endOfMonth)
        .isFilter('deleted_at', null);

    // Upcoming sessions (next 5)
    final List<dynamic> upcomingRows = await supabase
        .from('coaching_sessions')
        .select()
        .eq('coach_user_id', uid)
        .eq('status', 'scheduled')
        .gt('scheduled_at', DateTime.now().toUtc().toIso8601String())
        .isFilter('deleted_at', null)
        .order('scheduled_at')
        .limit(5);

    return CrossClientDashboard(
      totalActiveDecisions: totalActive,
      overdueReviews: overdueCount,
      sessionsThisMonth: sessionsThisMonthRows.length,
      attentionNeeded: attentionItems,
      upcomingSessions:
          upcomingRows.map((r) => CoachingSession.fromJson(r)).toList(),
    );
  }

  // ── Coach Notes ────────────────────────────────────────────────────────────

  Future<List<CoachNote>> getNotesForDecision(String decisionId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_notes')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return rows.map((r) => CoachNote.fromJson(r)).toList();
  }

  Future<List<CoachNote>> getNotesForClient(String clientUserId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_notes')
        .select()
        .eq('coach_user_id', uid)
        .eq('client_user_id', clientUserId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map((r) => CoachNote.fromJson(r)).toList();
  }

  /// Client: notes shared with this user by any coach.
  Future<List<CoachNote>> getNotesSharedWithMe() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_notes')
        .select()
        .eq('client_user_id', uid)
        .eq('visibility', 'shared_with_client')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map((r) => CoachNote.fromJson(r)).toList();
  }

  Future<CoachNote> addCoachNote({
    required String clientUserId,
    required String noteText,
    String? decisionId,
    String? coachingSessionId,
    int confidenceAdjustment = 0,
    String visibility = 'coach_only',
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = {
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'note_encrypted': noteText,
      'coach_confidence_adjustment': confidenceAdjustment,
      'visibility': visibility,
      if (decisionId != null) 'decision_id': decisionId,
      if (coachingSessionId != null) 'coaching_session_id': coachingSessionId,
    };
    final row =
        await supabase.from('coach_notes').insert(data).select().single();
    final note = CoachNote.fromJson(row);
    if (decisionId != null && confidenceAdjustment != 0) {
      unawaited(const ConfidenceTriggersService()
          .insertCoachNoteTrigger(note, decisionId));
    }
    return note;
  }

  Future<void> deleteNote(String id) async {
    await supabase
        .from('coach_notes')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<int> getConfidenceAdjustmentSum(String decisionId) async {
    final rows = await supabase
        .from('coach_notes')
        .select('coach_confidence_adjustment')
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null);
    int sum = 0;
    for (final r in rows) {
      final adj = r['coach_confidence_adjustment'] as int?;
      if (adj != null) sum += adj;
    }
    return sum;
  }

  // Backwards-compat alias used by confidence triggers
  Future<CoachNote> addNoteWithAdjustment({
    required String decisionId,
    required String clientUserId,
    required String noteText,
    int? confidenceAdjustment,
  }) =>
      addCoachNote(
        clientUserId: clientUserId,
        noteText: noteText,
        decisionId: decisionId,
        confidenceAdjustment: confidenceAdjustment ?? 0,
      );

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<CoachingSession>> getSessions({String? clientUserId}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    var query = supabase
        .from('coaching_sessions')
        .select()
        .isFilter('deleted_at', null);
    if (clientUserId != null) {
      query = query
          .eq('client_user_id', clientUserId)
          .eq('coach_user_id', uid);
    }
    final rows = await query.order('scheduled_at');
    return rows.map((r) => CoachingSession.fromJson(r)).toList();
  }

  Future<CoachingSession> createSessionFull({
    required String clientUserId,
    required DateTime scheduledAt,
    String? title,
    int durationMinutes = 60,
    String? workspaceId,
    String? resourceUrl,
    String? resourceLabel,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = {
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      if (title != null && title.isNotEmpty) 'title': title,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (resourceUrl != null && resourceUrl.isNotEmpty)
        'resource_url': resourceUrl,
      if (resourceLabel != null && resourceLabel.isNotEmpty)
        'resource_label': resourceLabel,
    };
    final row =
        await supabase.from('coaching_sessions').insert(data).select().single();
    return CoachingSession.fromJson(row);
  }

  Future<void> updateSessionStatus(String sessionId, String status) async {
    await supabase
        .from('coaching_sessions')
        .update({'status': status})
        .eq('id', sessionId);
  }

  // ── Session Notes ──────────────────────────────────────────────────────────

  Future<List<CoachingSessionNote>> getSessionNotes(
      String clientUserId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coaching_session_notes')
        .select()
        .eq('coach_user_id', uid)
        .eq('client_user_id', clientUserId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map((r) => CoachingSessionNote.fromJson(r)).toList();
  }

  /// Client: fetch session notes where they are the client (latest 10).
  Future<List<CoachingSessionNote>> getMySessionNotes() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coaching_session_notes')
        .select()
        .eq('client_user_id', uid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(10);
    return rows.map((r) => CoachingSessionNote.fromJson(r)).toList();
  }

  Future<CoachingSessionNote> addSessionNoteForSession({
    required String clientUserId,
    required String body,
    String? workspaceId,
    String? coachingSessionId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = {
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'body_encrypted': body,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (coachingSessionId != null) 'coaching_session_id': coachingSessionId,
    };
    final row = await supabase
        .from('coaching_session_notes')
        .insert(data)
        .select()
        .single();
    return CoachingSessionNote.fromJson(row);
  }

  // ── Action Items ───────────────────────────────────────────────────────────

  Future<List<CoachingActionItem>> getActionItems(String clientUserId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coaching_action_items')
        .select()
        .eq('coach_user_id', uid)
        .eq('client_user_id', clientUserId)
        .isFilter('deleted_at', null)
        .order('due_date');
    return rows.map((r) => CoachingActionItem.fromJson(r)).toList();
  }

  Future<List<CoachingActionItem>> getMyActionItems() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coaching_action_items')
        .select()
        .eq('client_user_id', uid)
        .isFilter('deleted_at', null)
        .order('due_date');
    return rows.map((r) => CoachingActionItem.fromJson(r)).toList();
  }

  Future<CoachingActionItem> createActionItem({
    required String clientUserId,
    required String title,
    String? descriptionEncrypted,
    DateTime? dueDate,
    String? decisionId,
    String? coachingSessionId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = {
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'title': title,
      if (descriptionEncrypted != null)
        'description_encrypted': descriptionEncrypted,
      if (dueDate != null)
        'due_date': dueDate.toIso8601String().split('T').first,
      if (decisionId != null) 'decision_id': decisionId,
      if (coachingSessionId != null) 'coaching_session_id': coachingSessionId,
    };
    final row = await supabase
        .from('coaching_action_items')
        .insert(data)
        .select()
        .single();
    return CoachingActionItem.fromJson(row);
  }

  Future<void> markActionItemComplete(String itemId) async {
    await supabase
        .from('coaching_action_items')
        .update({'completed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', itemId);
  }

  Future<void> deleteActionItem(String itemId) async {
    await supabase
        .from('coaching_action_items')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', itemId);
  }
}
