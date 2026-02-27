import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/settings/data/models/notification_preferences.dart';
import 'package:reflect_os/features/settings/data/models/workspace_branding.dart';

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

  Future<WorkspaceBranding?> getWorkspaceBranding(String workspaceId) async {
    final row = await supabase
        .from('workspace_branding')
        .select()
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    if (row == null) return null;
    return WorkspaceBranding.fromJson(row);
  }

  Future<void> upsertWorkspaceBranding({
    required String workspaceId,
    String? companyName,
    String? tagline,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? logoFileUrl,
  }) async {
    final data = <String, dynamic>{'workspace_id': workspaceId};
    if (companyName != null) data['company_name'] = companyName;
    if (tagline != null) data['company_tagline'] = tagline;
    if (primaryColorHex != null) data['primary_color_hex'] = primaryColorHex;
    if (secondaryColorHex != null) data['secondary_color_hex'] = secondaryColorHex;
    if (logoFileUrl != null) data['logo_file_url'] = logoFileUrl;
    await supabase
        .from('workspace_branding')
        .upsert(data, onConflict: 'workspace_id');
  }
}
