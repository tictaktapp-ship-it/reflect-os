import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/calendar/data/models/calendar_connection.dart';

class CalendarRepository {
  const CalendarRepository();

  Future<List<CalendarConnection>> getConnections(String workspaceId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await supabase
        .from('calendar_connections')
        .select()
        .eq('user_id', userId)
        .eq('workspace_id', workspaceId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return rows.map((r) => CalendarConnection.fromJson(r)).toList();
  }

  Future<void> disconnectCalendar(String id) async {
    await supabase
        .from('calendar_connections')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getEventLinksForCheckpoint(
      String checkpointId) async {
    final rows = await supabase
        .from('calendar_event_links')
        .select()
        .eq('checkpoint_id', checkpointId)
        .isFilter('deleted_at', null);
    return List<Map<String, dynamic>>.from(rows);
  }
}
