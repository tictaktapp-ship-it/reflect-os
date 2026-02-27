import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/engineering/data/models/engineering_artifact_link.dart';

class EngineeringRepository {
  const EngineeringRepository();

  Future<List<EngineeringArtifactLink>> getArtifactsForDecision(
      String decisionId) async {
    final rows = await supabase
        .from('engineering_artifact_links')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return rows.map(EngineeringArtifactLink.fromJson).toList();
  }

  Future<EngineeringArtifactLink> addArtifact({
    required String decisionId,
    required String workspaceId,
    required String artifactType,
    required String url,
    String? label,
  }) async {
    final data = <String, dynamic>{
      'decision_id': decisionId,
      'workspace_id': workspaceId,
      'artifact_type': artifactType,
      'url': url,
    };
    if (label != null && label.isNotEmpty) data['label'] = label;
    final row = await supabase
        .from('engineering_artifact_links')
        .insert(data)
        .select()
        .single();
    return EngineeringArtifactLink.fromJson(row);
  }

  Future<void> deleteArtifact(String id) async {
    await supabase
        .from('engineering_artifact_links')
        .delete()
        .eq('id', id);
  }
}
