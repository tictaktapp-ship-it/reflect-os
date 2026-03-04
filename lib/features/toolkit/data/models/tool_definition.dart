import 'tool_field.dart';

class ToolDefinition {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<ToolInputField> inputSchema;
  final List<ToolOutputField> outputSchema;
  final Map<String, dynamic> formulaAst;
  final Map<String, dynamic>? metadata;

  const ToolDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.inputSchema,
    required this.outputSchema,
    required this.formulaAst,
    this.metadata,
  });

  factory ToolDefinition.fromJson(Map<String, dynamic> json) {
    final inputSchema = json['input_schema_jsonb'] as Map<String, dynamic>? ?? {};
    final inputList = ((inputSchema['fields'] as List<dynamic>?) ?? [])
        .map((e) => ToolInputField.fromJson(e as Map<String, dynamic>))
        .toList();

    final outputSchema = json['output_schema_jsonb'] as Map<String, dynamic>? ?? {};
    final outputList = ((outputSchema['fields'] as List<dynamic>?) ?? [])
        .map((e) => ToolOutputField.fromJson(e as Map<String, dynamic>))
        .toList();
    return ToolDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      inputSchema: inputList,
      outputSchema: outputList,
      formulaAst: json['calculation_spec_jsonb'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
