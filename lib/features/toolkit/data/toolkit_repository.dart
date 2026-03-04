import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'models/tool_definition.dart';
import 'models/tool_run.dart';

class ToolkitRepository {
  const ToolkitRepository();

  Future<List<ToolDefinition>> getToolDefinitions() async {
    final rows = await supabase
        .from(SupabaseViews.toolDefinitions)
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
    // RPC returns the inserted tool_runs row as a Map
    final row = result as Map<String, dynamic>;
    return row['id'] as String;
  }

  /// Step 2 of the two-call flow: persists client-computed outputs.
  Future<void> approveAndInjectToolOutput({
    required String toolRunId,
    required String decisionId,
    required String finalDescription,
    required Map<String, dynamic> outputsJsonb,
    required Map<String, dynamic> calculationBreakdownJsonb,
    bool attachToolAudit = false,
  }) async {
    await supabase.rpc(
      SupabaseRpcs.approveAndInjectToolOutput,
      params: {
        'p_tool_run_id':                  toolRunId,
        'p_decision_id':                  decisionId,
        'p_final_description':            finalDescription,
        'p_outputs_jsonb':                outputsJsonb,
        'p_calculation_breakdown_jsonb':  calculationBreakdownJsonb,
        'p_attach_tool_audit':            attachToolAudit,
      },
    );
  }
}
