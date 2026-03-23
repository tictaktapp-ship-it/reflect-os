import 'package:reflect_os/core/constants/supabase_constants.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'models/tool_definition.dart';
import 'models/tool_run.dart';
import 'models/tool_preset.dart';

class ToolkitRepository {
  const ToolkitRepository();

  // ── Read paths (views only) ──────────────────────────────────────────────

  Future<List<ToolDefinition>> getToolDefinitions() async {
    try {
      final rows = await supabase
          .from(SupabaseViews.toolDefinitions)
          .select()
          .order('name');
      return (rows as List).map((r) => ToolDefinition.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e, st) {
      // ignore: avoid_print
      print('getToolDefinitions error: $e\n$st');
      rethrow;
    }
  }

  Future<ToolDefinition> getToolDefinition(String id) async {
    final row = await supabase
        .from(SupabaseViews.toolDefinitions)
        .select()
        .eq('id', id)
        .single();
    return ToolDefinition.fromJson(row);
  }

  Future<List<ToolRun>> getToolRunsForDecision(String decisionId) async {
    final rows = await supabase
        .from(SupabaseViews.toolRuns)
        .select()
        .eq('decision_id', decisionId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => ToolRun.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<ToolPreset>> getPresetsForTool({
    required String workspaceId,
    required String toolDefinitionId,
  }) async {
    final rows = await supabase
        .from(SupabaseViews.toolPresets)
        .select()
        .eq('workspace_id', workspaceId)
        .eq('tool_definition_id', toolDefinitionId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => ToolPreset.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ── Write paths (RPCs only) ──────────────────────────────────────────────

  /// Creates a shell run row via RPC. Returns the full tool_runs row.
  Future<ToolRun> runTool({
    required String toolDefinitionId,
    required String workspaceId,
    required Map<String, dynamic> inputsJsonb,
    String? decisionId,
    int projectionYears = 3,
    String currencyCode = 'GBP',
    String confidenceScenario = 'base',
  }) async {
    final enrichedInputs = {
      ...inputsJsonb,
      '__projection_years': projectionYears,
      '__currency_code': currencyCode,
      '__confidence_scenario': confidenceScenario,
    };

    final result = await supabase.rpc(
      SupabaseRpcs.runTool,
      params: {
        'p_tool_definition_id': toolDefinitionId,
        'p_workspace_id': workspaceId,
        'p_inputs_jsonb': enrichedInputs,
        'p_decision_id': ?decisionId,
      },
    );
    return ToolRun.fromJson(result as Map<String, dynamic>);
  }

  /// Links a tool run to a decision if the run was created without a decision
  /// context (e.g. opened from the standalone toolkit, not from a decision).
  /// No-ops if the run already has a decision_id set.
  Future<void> linkRunToDecision({
    required String toolRunId,
    required String decisionId,
  }) async {
    await supabase
        .from('tool_runs')
        .update({'decision_id': decisionId})
        .eq('id', toolRunId)
        .isFilter('decision_id', null);
  }

  /// Approves client-computed outputs and injects them into a decision.
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
        'p_tool_run_id': toolRunId,
        'p_decision_id': decisionId,
        'p_final_description': finalDescription,
        'p_outputs_jsonb': outputsJsonb,
        'p_calculation_breakdown_jsonb': calculationBreakdownJsonb,
        'p_attach_tool_audit': attachToolAudit,
      },
    );
  }

  /// Inserts a generated_documents row and returns its id.
  Future<String> insertGeneratedDocument({
    required String workspaceId,
    required String userId,
    required String decisionId,
  }) async {
    final row = await supabase
        .from('generated_documents')
        .insert({
          'workspace_id': workspaceId,
          'created_by_user_id': userId,
          'document_type': 'tool_output',
          'subject_entity_type': 'decision',
          'subject_entity_id': decisionId,
          'status': 'Pending',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Updates the storage location and marks status as Ready.
  Future<void> updateDocumentStoragePath({
    required String documentId,
    required String storageBucket,
    required String storagePath,
  }) async {
    await supabase.from('generated_documents').update({
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'status': 'Ready',
    }).eq('id', documentId);
  }

  /// Saves current inputs as a named preset.
  Future<ToolPreset> savePreset({
    required String workspaceId,
    required String toolDefinitionId,
    required String name,
    required Map<String, dynamic> inputsJsonb,
    String? description,
    bool isWorkspaceDefault = false,
  }) async {
    final result = await supabase.rpc(
      SupabaseRpcs.saveToolPreset,
      params: {
        'p_workspace_id': workspaceId,
        'p_tool_definition_id': toolDefinitionId,
        'p_name': name,
        'p_inputs_jsonb': inputsJsonb,
        'p_description': ?description,
        'p_is_workspace_default': isWorkspaceDefault,
      },
    );
    return ToolPreset.fromJson(result as Map<String, dynamic>);
  }
}
