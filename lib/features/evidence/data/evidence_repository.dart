import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/evidence/data/models/evidence_item.dart';

class EvidenceRepository {
  const EvidenceRepository();

  Future<List<EvidenceItem>> getEvidenceForDecision(String decisionId) async {
    final rows = await supabase
        .from('user_visible_evidence_items')
        .select()
        .eq('decision_id', decisionId)
        .order('created_at');

    return rows.map((row) => EvidenceItem.fromJson(row)).toList();
  }

  Future<void> addLinkEvidence(
      String decisionId, String label, String url) async {
    await supabase.from('evidence_items').insert({
      'decision_id': decisionId,
      'type': 'link',
      'label': label.isEmpty ? null : label,
      'url': url,
      'created_by_user_id': supabase.auth.currentUser!.id,
    });
  }

  /// Hard delete — evidence_items has no UPDATE RLS policy so soft-delete
  /// via deleted_at is not available.
  Future<void> deleteEvidence(String id) async {
    await supabase.from('evidence_items').delete().eq('id', id);
  }
}
