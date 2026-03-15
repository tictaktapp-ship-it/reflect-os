import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/workspace/data/models/workspace_model.dart';

class WorkspaceRepository {
  const WorkspaceRepository();

  /// Reads from the user_visible_workspaces view.
  /// RLS ensures the user sees only their own workspaces.
  /// Personal workspace sorts first (alphabetically 'personal' < 'team').
  Future<List<WorkspaceModel>> getUserWorkspaces() async {
    final rows = await supabase
        .from('user_visible_workspaces')
        .select()
        .order('workspace_type', ascending: true);
    return rows.map((row) => WorkspaceModel.fromJson(row)).toList();
  }

  /// Creates the workspace and returns its new id.
  Future<String> createWorkspace(String name, bool shareWithTeam) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final row = await supabase
        .from('workspaces')
        .insert({
          'name': name,
          'workspace_type': shareWithTeam ? 'team' : 'personal',
          'owner_user_id': userId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Batch-inserts workspace_invites rows. Each invite expires in 7 days.
  Future<void> sendInvites({
    required String workspaceId,
    required List<({String email, String role})> invites,
  }) async {
    if (invites.isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
    await supabase.from('workspace_invites').insert(
          invites
              .map((i) => {
                    'workspace_id': workspaceId,
                    'email': i.email,
                    'role': i.role,
                    'expires_at': expiresAt.toIso8601String(),
                    'created_by_user_id': userId,
                  })
              .toList(),
        );
  }

  Future<void> renameWorkspace(String id, String name) async {
    await supabase
        .from('workspaces')
        .update({'name': name})
        .eq('id', id);
  }

  Future<void> deleteWorkspace(String id) async {
    await supabase
        .from('workspaces')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
