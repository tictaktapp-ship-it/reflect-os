import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'models/encryption_settings.dart';

class EncryptionSettingsRepository {
  const EncryptionSettingsRepository();

  /// Returns the encryption settings for the workspace, or null if no row
  /// exists yet (treat as [EncryptionMode.encrypted] default).
  Future<EncryptionSettings?> getSettings(String workspaceId) async {
    final row = await supabase
        .from(SupabaseTables.workspaceSettings)
        .select(
          'workspace_id, encryption_mode, '
          'encryption_mode_changed_at, encryption_mode_changed_by',
        )
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    if (row == null) return null;
    return EncryptionSettings.fromJson(row);
  }

  /// Calls the owner-only `set_workspace_encryption_mode` RPC.
  ///
  /// Throws [EncryptionPermissionException] if Supabase returns a permission
  /// error, or rethrows other errors.
  Future<void> setMode({
    required String workspaceId,
    required EncryptionMode mode,
  }) async {
    try {
      await supabase.rpc(
        SupabaseRpcs.setWorkspaceEncryptionMode,
        params: {
          'p_workspace_id': workspaceId,
          'p_mode': mode == EncryptionMode.plaintext ? 'plaintext' : 'encrypted',
        },
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') ||
          msg.contains('owner') ||
          msg.contains('denied')) {
        throw const EncryptionPermissionException(
          'Only workspace owners can change the encryption mode.',
        );
      }
      rethrow;
    }
  }
}
