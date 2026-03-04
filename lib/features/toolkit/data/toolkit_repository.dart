import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'models/tool_definition.dart';
import 'models/tool_run.dart';

class ToolkitRepository {
  const ToolkitRepository();

  Future<List<ToolDefinition>> getToolDefinitions() async {
    final rows = await supabase
        .from(SupabaseTables.toolDefinitions)
        .select()
        .order('name');
    return rows.map(ToolDefinition.fromJson).toList();
  }

  Future<List<ToolRun>> getToolRunsForDecision(String decisionId) async {
    final rows = await supabase
        .from(SupabaseViews.workspaceToolRuns)
        .select()
        .eq('decision_id', decisionId)
        .order('created_at', ascending: false);
    return rows.map(ToolRun.fromJson).toList();
  }

  /// Step 1 of the two-call flow: creates a shell run row, returns its id.
  Future<String> runTool({
    required String workspaceId,
    required String decisionId,
    required String toolDefinitionId,
    required Map<String, dynamic> inputsJsonb,
  }) async {
    final result =
        await supabase.rpc(SupabaseRpcs.runTool, params: {
      'p_workspace_id': workspaceId,
      'p_decision_id': decisionId,
      'p_tool_definition_id': toolDefinitionId,
      'p_inputs_jsonb': inputsJsonb,
    });
    return result as String;
  }

  /// Step 2 of the two-call flow: persists client-computed outputs.
  Future<void> approveAndInjectToolOutput({
    required String toolRunId,
    required Map<String, dynamic> outputsJsonb,
  }) async {
    await supabase.rpc(
      SupabaseRpcs.approveAndInjectToolOutput,
      params: {
        'p_tool_run_id': toolRunId,
        'p_outputs_jsonb': outputsJsonb,
      },
    );
  }
}
