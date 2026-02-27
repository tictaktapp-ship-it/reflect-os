import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';

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

  Future<void> inviteClient(String clientEmail) async {
    throw Exception(
        'Client invitation requires email lookup — coming soon');
  }

  Future<void> revokeClient(String relationshipId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('coach_client_relationships')
        .update({'revoked_at': now, 'deleted_at': now})
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
}
