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
}
