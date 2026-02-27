import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/investment/data/models/asset.dart';
import 'package:reflect_os/features/investment/data/models/ic_vote.dart';

class InvestmentRepository {
  const InvestmentRepository();

  // ── Assets ──────────────────────────────────────────────────────────────────

  Future<List<Asset>> getAssetsForWorkspace(String workspaceId) async {
    final rows = await supabase
        .from('assets')
        .select()
        .eq('workspace_id', workspaceId)
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map(Asset.fromJson).toList();
  }

  Future<List<Asset>> getLinkedAssets(String decisionId) async {
    final rows = await supabase
        .from('decision_assets')
        .select('asset_id, assets(*)')
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null);
    return rows
        .map((r) => Asset.fromJson(r['assets'] as Map<String, dynamic>))
        .toList();
  }

  Future<Asset> createAsset({
    required String workspaceId,
    required String name,
    String? sector,
    String? stage,
    String? geography,
  }) async {
    final data = <String, dynamic>{
      'workspace_id': workspaceId,
      'name': name,
    };
    if (sector != null) data['sector'] = sector;
    if (stage != null) data['stage'] = stage;
    if (geography != null) data['geography'] = geography;
    final row =
        await supabase.from('assets').insert(data).select().single();
    return Asset.fromJson(row);
  }

  Future<void> linkAsset({
    required String decisionId,
    required String assetId,
  }) async {
    await supabase.from('decision_assets').upsert(
      {'decision_id': decisionId, 'asset_id': assetId},
      onConflict: 'decision_id,asset_id',
    );
  }

  Future<void> unlinkAsset({
    required String decisionId,
    required String assetId,
  }) async {
    await supabase
        .from('decision_assets')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('decision_id', decisionId)
        .eq('asset_id', assetId);
  }

  // ── IC Votes ─────────────────────────────────────────────────────────────────

  Future<List<IcVote>> getVotesForDecision(String decisionId) async {
    final rows = await supabase
        .from('ic_votes')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('voted_at');
    return rows.map(IcVote.fromJson).toList();
  }

  /// Upserts a vote for the current user (conflict on decision_id + voter_user_id).
  Future<IcVote> castVote({
    required String decisionId,
    required String vote,
    String? dissentNotes,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final data = <String, dynamic>{
      'decision_id': decisionId,
      'voter_user_id': uid,
      'vote': vote,
      'voted_at': DateTime.now().toIso8601String(),
    };
    if (dissentNotes != null && dissentNotes.isNotEmpty) {
      data['dissent_notes_encrypted'] = dissentNotes;
    }
    final row = await supabase
        .from('ic_votes')
        .upsert(data, onConflict: 'decision_id,voter_user_id')
        .select()
        .single();
    return IcVote.fromJson(row);
  }
}
