import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'models/demographic_pack.dart';

class DemographicPacksRepository {
  const DemographicPacksRepository();

  Future<List<DemographicPack>> getPacks() async {
    final rows = await supabase
        .from(SupabaseTables.demographicPacks)
        .select()
        .order('name');
    return rows.map(DemographicPack.fromJson).toList();
  }

  /// Reads the workspace_settings row for the current workspace to get the
  /// default pack id.
  Future<String?> getDefaultPackId(String workspaceId) async {
    final row = await supabase
        .from(SupabaseTables.workspaceSettings)
        .select('default_demographic_pack_id')
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return row?['default_demographic_pack_id'] as String?;
  }

  /// Calls the `set_workspace_default_pack` RPC.
  Future<void> setDefaultPack({
    required String workspaceId,
    required String packId,
  }) async {
    await supabase.rpc(
      SupabaseRpcs.setWorkspaceDefaultPack,
      params: {
        'p_workspace_id': workspaceId,
        'p_pack_id': packId,
      },
    );
  }
}
