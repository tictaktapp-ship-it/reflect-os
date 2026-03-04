class ToolPreset {
  final String id;
  final String workspaceId;
  final String toolDefinitionId;
  final String createdByUserId;
  final String name;
  final String? description;
  final Map<String, dynamic> inputsJsonb;
  final bool isWorkspaceDefault;
  final DateTime createdAt;
  // Joined from view
  final String toolName;
  final String toolKey;

  const ToolPreset({
    required this.id,
    required this.workspaceId,
    required this.toolDefinitionId,
    required this.createdByUserId,
    required this.name,
    this.description,
    required this.inputsJsonb,
    required this.isWorkspaceDefault,
    required this.createdAt,
    required this.toolName,
    required this.toolKey,
  });

  factory ToolPreset.fromJson(Map<String, dynamic> json) => ToolPreset(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        toolDefinitionId: json['tool_definition_id'] as String,
        createdByUserId: json['created_by_user_id'] as String? ?? '',
        name: json['name'] as String,
        description: json['description'] as String?,
        inputsJsonb: (json['inputs_jsonb'] as Map<String, dynamic>?) ?? {},
        isWorkspaceDefault: json['is_workspace_default'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        toolName: json['tool_name'] as String? ?? '',
        toolKey: json['tool_key'] as String? ?? '',
      );
}
