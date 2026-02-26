import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';

/// Exception to the no-raw-tables rule: no user_visible_decision_templates view.
/// RLS on decision_templates allows workspace members to read system templates
/// and their own workspace templates.
class TemplatesRepository {
  const TemplatesRepository();

  Future<List<DecisionTemplate>> getTemplates(String workspaceId) async {
    final rows = await supabase
        .from('decision_templates')
        .select()
        .or('workspace_id.eq.$workspaceId,is_system.eq.true')
        .isFilter('deleted_at', null)
        .order('is_system', ascending: false)
        .order('name', ascending: true);

    return rows.map((row) => DecisionTemplate.fromJson(row)).toList();
  }

  Future<void> createTemplate({
    required String workspaceId,
    required String name,
    String? description,
    String? defaultStakes,
    required bool requiresApproval,
  }) async {
    await supabase.from('decision_templates').insert({
      'workspace_id': workspaceId,
      'name': name,
      // ignore: use_null_aware_elements
      if (description != null && description.isNotEmpty)
        'description_encrypted': description,
      'default_stakes': ?defaultStakes,
      'requires_approval': requiresApproval,
      'is_system': false,
    });
  }

  Future<void> deleteTemplate(String id) async {
    await supabase
        .from('decision_templates')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
