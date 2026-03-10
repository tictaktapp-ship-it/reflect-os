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
        .select('id, display_name, avatar_url')
        .inFilter('id', userIds);

    final profileMap = {
      for (final p in profileRows) p['id'] as String: p,
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
}
