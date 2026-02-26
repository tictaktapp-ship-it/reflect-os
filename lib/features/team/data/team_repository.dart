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

    return rows.map((row) => WorkspaceMembership.fromJson(row)).toList();
  }
}
