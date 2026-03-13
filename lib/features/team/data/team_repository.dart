import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';

class TeamRepository {
  const TeamRepository();

  Future<List<WorkspaceMembership>> getWorkspaceMemberships(
      String workspaceId) async {
    final rows = await supabase
        .from('user_visible_workspace_memberships')
        .select()
        .eq('workspace_id', workspaceId)
        .isFilter('deleted_at', null)
        .order('role')
        .order('created_at');

    if (rows.isEmpty) return [];

    // Fetch display names and avatars from profiles.
    final userIds = rows.map((r) => r['user_id'] as String).toList();
    final profileRows = await supabase
        .from('profiles')
        .select('user_id, display_name, avatar_url')
        .inFilter('user_id', userIds);

    final profileMap = {
      for (final p in profileRows) p['user_id'] as String: p,
    };

    return rows.map((row) {
      final profile = profileMap[row['user_id'] as String];
      return WorkspaceMembership.fromJson({
        ...row,
        'display_name': profile?['display_name'],
        'avatar_url': profile?['avatar_url'],
      });
    }).toList();
  }

  Future<void> updateMemberRole(String membershipId, String newRole) async {
    await supabase
        .from('workspace_memberships')
        .update({'role': newRole})
        .eq('id', membershipId);
  }

  Future<void> removeMember(String membershipId) async {
    await supabase
        .from('workspace_memberships')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', membershipId);
  }

  Future<List<Map<String, dynamic>>> getPendingInvites(
      String workspaceId) async {
    final rows = await supabase
        .from('workspace_invites')
        .select()
        .eq('workspace_id', workspaceId)
        .isFilter('accepted_at', null)
        .isFilter('revoked_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return rows;
  }

  Future<void> inviteMember({
    required String workspaceId,
    required String email,
    required String role,
  }) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
    await supabase.from('workspace_invites').insert({
      'workspace_id': workspaceId,
      'email': email,
      'role': role,
      'expires_at': expiresAt.toIso8601String(),
      'created_by_user_id': currentUserId,
    });
  }

  Future<void> revokeInvite(String inviteId) async {
    await supabase
        .from('workspace_invites')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', inviteId);
  }
}
