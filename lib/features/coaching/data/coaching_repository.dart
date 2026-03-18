import 'dart:async';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/decisions/data/confidence_triggers_service.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';

class CoachingRepository {
  const CoachingRepository();

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

  // Get all relationships (both pending and active) as coach
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

  // Get all relationships (both pending and active) as client
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

  Future<void> inviteClient(String clientEmail, String workspaceId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');
    final expiresAt =
        DateTime.now().toUtc().add(const Duration(days: 7));
    await supabase.from('workspace_invites').insert({
      'workspace_id': workspaceId,
      'email': clientEmail,
      'role': 'Editor',
      'expires_at': expiresAt.toIso8601String(),
      'created_by_user_id': currentUserId,
    });
  }

  Future<void> revokeClient(String relationshipId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('coach_client_relationships')
        .update({'revoked_at': now, 'deleted_at': now})
        .eq('id', relationshipId);
  }

  // Update relationship focus/goals/notes (encrypted fields stored as plaintext for now)
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

  Future<CoachNote> addNote(
      String decisionId, String clientUserId, String noteText) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final row = await supabase
        .from('coach_notes')
        .insert({
          'coach_user_id': uid,
          'client_user_id': clientUserId,
          'decision_id': decisionId,
          'note_encrypted': noteText,
        })
        .select()
        .single();
    return CoachNote.fromJson(row);
  }

  Future<void> deleteNote(String id) async {
    await supabase
        .from('coach_notes')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // Get coach notes for a specific client (all decisions)
  Future<List<CoachNote>> getNotesForClient(String clientUserId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('coach_notes')
        .select()
        .eq('coach_user_id', uid)
        .eq('client_user_id', clientUserId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return rows.map((r) => CoachNote.fromJson(r)).toList();
  }

  // Add note with all fields
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
    if (decisionId != null && (confidenceAdjustment != 0)) {
      unawaited(const ConfidenceTriggersService()
          .insertCoachNoteTrigger(note, decisionId));
    }
    return note;
  }

  // Get confidence adjustments for a decision (for all coaches)
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

  Future<List<CoachingSession>> getSessions({String? clientUserId}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    List<Map<String, dynamic>> rows;
    if (clientUserId != null) {
      rows = await supabase
          .from('coaching_sessions')
          .select()
          .isFilter('deleted_at', null)
          .eq('client_user_id', clientUserId)
          .eq('coach_user_id', uid)
          .order('scheduled_at');
    } else {
      rows = await supabase
          .from('coaching_sessions')
          .select()
          .isFilter('deleted_at', null)
          .order('scheduled_at');
    }
    return rows.map((r) => CoachingSession.fromJson(r)).toList();
  }

  Future<CoachingSession> createSession({
    required String clientUserId,
    required DateTime scheduledAt,
    String? title,
    int durationMinutes = 60,
    String? workspaceId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final row = await supabase.from('coaching_sessions').insert({
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'title': title,
      'duration_minutes': durationMinutes,
      if (workspaceId != null) 'workspace_id': workspaceId,
    }).select().single();
    return CoachingSession.fromJson(row);
  }

  // Create session with resource link
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
      'title': title,
      'duration_minutes': durationMinutes,
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

  Future<List<CoachingSessionNote>> getSessionNotes(String clientUserId) async {
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

  Future<CoachingSessionNote> addSessionNote({
    required String clientUserId,
    required String body,
    String? workspaceId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final row = await supabase.from('coaching_session_notes').insert({
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'body_encrypted': body,
      if (workspaceId != null) 'workspace_id': workspaceId,
    }).select().single();
    return CoachingSessionNote.fromJson(row);
  }

  // Add session note (for past sessions)
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

  Future<CoachNote> addNoteWithAdjustment({
    required String decisionId,
    required String clientUserId,
    required String noteText,
    int? confidenceAdjustment,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final row = await supabase.from('coach_notes').insert({
      'coach_user_id': uid,
      'client_user_id': clientUserId,
      'decision_id': decisionId,
      'note_encrypted': noteText,
      if (confidenceAdjustment != null)
        'coach_confidence_adjustment': confidenceAdjustment,
    }).select().single();
    final note = CoachNote.fromJson(row);
    if (confidenceAdjustment != null && confidenceAdjustment != 0) {
      unawaited(const ConfidenceTriggersService()
          .insertCoachNoteTrigger(note, decisionId));
    }
    return note;
  }

  Future<void> inviteCoach(String coachEmail, String workspaceId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');
    final expiresAt =
        DateTime.now().toUtc().add(const Duration(days: 7));
    await supabase.from('workspace_invites').insert({
      'workspace_id': workspaceId,
      'email': coachEmail,
      'role': 'Editor',
      'expires_at': expiresAt.toIso8601String(),
      'created_by_user_id': currentUserId,
    });
  }

  // Action items
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
