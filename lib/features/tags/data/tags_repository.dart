import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/tags/data/models/tag.dart';

class TagsRepository {
  const TagsRepository();

  Future<List<Tag>> getTagsForWorkspace(String workspaceId) async {
    final rows = await supabase
        .from('tags')
        .select()
        .eq('workspace_id', workspaceId)
        .isFilter('deleted_at', null)
        .order('name');

    return rows.map((row) => Tag.fromJson(row)).toList();
  }

  Future<List<Tag>> getTagsForDecision(String decisionId) async {
    // Join decision_tags → tags, filtering soft-deleted rows on both sides.
    final rows = await supabase
        .from('tags')
        .select('*, decision_tags!inner(decision_id, deleted_at)')
        .eq('decision_tags.decision_id', decisionId)
        .isFilter('decision_tags.deleted_at', null)
        .isFilter('deleted_at', null)
        .order('name');

    return rows.map((row) => Tag.fromJson(row)).toList();
  }

  Future<void> addTagToDecision(String decisionId, String tagId) async {
    await supabase.from('decision_tags').insert({
      'decision_id': decisionId,
      'tag_id': tagId,
    });
  }

  Future<void> removeTagFromDecision(String decisionId, String tagId) async {
    await supabase
        .from('decision_tags')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('decision_id', decisionId)
        .eq('tag_id', tagId)
        .isFilter('deleted_at', null);
  }

  Future<Tag> createTag(String workspaceId, String name) async {
    final row = await supabase
        .from('tags')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
        })
        .select()
        .single();

    return Tag.fromJson(row);
  }
}
