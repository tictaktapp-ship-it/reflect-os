class ToolRun {
  final String id;
  final String workspaceId;
  final String decisionId;
  final String toolDefinitionId;
  final String toolDefinitionName;
  final Map<String, dynamic> inputsJsonb;
  final Map<String, dynamic> outputsJsonb;
  final DateTime createdAt;

  const ToolRun({
    required this.id,
    required this.workspaceId,
    required this.decisionId,
    required this.toolDefinitionId,
    required this.toolDefinitionName,
    required this.inputsJsonb,
    required this.outputsJsonb,
    required this.createdAt,
  });

  factory ToolRun.fromJson(Map<String, dynamic> json) {
    return ToolRun(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      decisionId: json['decision_id'] as String,
      toolDefinitionId: json['tool_definition_id'] as String,
      toolDefinitionName: json['tool_definition_name'] as String? ?? '',
      inputsJsonb:
          (json['inputs_jsonb'] as Map<String, dynamic>?) ?? {},
      outputsJsonb:
          (json['outputs_jsonb'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
