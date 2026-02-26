import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';

class SettingsRepository {
  const SettingsRepository();

  /// Reads the 100 most recent audit events for the given workspace.
  /// audit_events_select_owner RLS policy gates access to workspace members.
  Future<List<AuditEvent>> getAuditLog(String workspaceId) async {
    final rows = await supabase
        .from('audit_events')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .limit(100);

    return rows.map((row) => AuditEvent.fromJson(row)).toList();
  }
}
