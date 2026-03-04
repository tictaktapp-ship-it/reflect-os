class ToolRun {
  final String id;
  final String workspaceId;
  final String? decisionId;
  final String toolDefinitionId;
  final String ranByUserId;
  final Map<String, dynamic> inputsJsonb;
  final Map<String, dynamic> outputsJsonb;
  final Map<String, dynamic> calculationBreakdownJsonb;
  final String status; // 'Completed' | 'Failed' | 'Cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;
  // V2 fields
  final int projectionYears;
  final String currencyCode;
  final String confidenceScenario; // 'base' | 'optimistic' | 'pessimistic'
  final List<dynamic> annualProjectionsJsonb;
  final String? presetId;
  // Joined fields from view
  final String toolName;
  final String toolKey;
  final String toolCategory;

  const ToolRun({
    required this.id,
    required this.workspaceId,
    this.decisionId,
    required this.toolDefinitionId,
    required this.ranByUserId,
    required this.inputsJsonb,
    required this.outputsJsonb,
    required this.calculationBreakdownJsonb,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.projectionYears,
    required this.currencyCode,
    required this.confidenceScenario,
    required this.annualProjectionsJsonb,
    this.presetId,
    required this.toolName,
    required this.toolKey,
    required this.toolCategory,
  });

  factory ToolRun.fromJson(Map<String, dynamic> json) {
    return ToolRun(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      decisionId: json['decision_id'] as String?,
      toolDefinitionId: json['tool_definition_id'] as String,
      ranByUserId: json['ran_by_user_id'] as String? ?? '',
      inputsJsonb: (json['inputs_jsonb'] as Map<String, dynamic>?) ?? {},
      outputsJsonb: (json['outputs_jsonb'] as Map<String, dynamic>?) ?? {},
      calculationBreakdownJsonb:
          (json['calculation_breakdown_jsonb'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'Completed',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? json['created_at'] as String),
      projectionYears: json['projection_years'] as int? ?? 3,
      currencyCode: json['currency_code'] as String? ?? 'GBP',
      confidenceScenario: json['confidence_scenario'] as String? ?? 'base',
      annualProjectionsJsonb:
          (json['annual_projections_jsonb'] as List<dynamic>?) ?? [],
      presetId: json['preset_id'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      toolKey: json['tool_key'] as String? ?? '',
      toolCategory: json['tool_category'] as String? ?? '',
    );
  }
}
