import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/settings/data/models/notification_preferences.dart';

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

  /// Returns the notification preferences row for the current user,
  /// or null if no row exists yet.
  Future<NotificationPreferences?> getNotificationPreferences() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return NotificationPreferences.fromJson(row);
  }

  Future<void> upsertNotificationPreferences({
    required bool weeklyDigest,
    required bool activationEmails,
    required String timezone,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('notification_preferences').upsert(
      {
        'user_id': userId,
        'weekly_digest_enabled': weeklyDigest,
        'weekly_digest_timezone': timezone,
        'activation_emails_enabled': activationEmails,
      },
      onConflict: 'user_id',
    );
  }
}
