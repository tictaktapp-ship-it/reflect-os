class ToolDefinition {
  final String id;
  final String key;
  final String? vertical;
  final String name;
  final String category;
  final String description;
  final Map<String, dynamic> inputSchemaJsonb;
  final Map<String, dynamic> outputSchemaJsonb;
  final Map<String, dynamic> calculationSpecJsonb;
  final Map<String, dynamic> uiConfigJsonb;
  final int version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ToolDefinition({
    required this.id,
    required this.key,
    this.vertical,
    required this.name,
    required this.category,
    required this.description,
    required this.inputSchemaJsonb,
    required this.outputSchemaJsonb,
    required this.calculationSpecJsonb,
    required this.uiConfigJsonb,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ToolDefinition.fromJson(Map<String, dynamic> json) {
    return ToolDefinition(
      id: json['id'] as String,
      key: json['key'] as String,
      vertical: json['vertical'] as String?,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      inputSchemaJsonb:
          (json['input_schema_jsonb'] as Map<String, dynamic>?) ?? {},
      outputSchemaJsonb:
          (json['output_schema_jsonb'] as Map<String, dynamic>?) ?? {},
      calculationSpecJsonb:
          (json['calculation_spec_jsonb'] as Map<String, dynamic>?) ?? {},
      uiConfigJsonb:
          (json['ui_config_jsonb'] as Map<String, dynamic>?) ?? {},
      version: json['version'] as int? ?? 2,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // ── Convenience getters ──────────────────────────────────────────────────

  List<dynamic> get sections =>
      (inputSchemaJsonb['sections'] as List<dynamic>?) ?? [];

  List<dynamic> get summaryFields =>
      (outputSchemaJsonb['summary_fields'] as List<dynamic>?) ?? [];

  List<dynamic> get annualProjectionColumns =>
      (outputSchemaJsonb['annual_projection_columns'] as List<dynamic>?) ?? [];

  Map<String, dynamic> get chartConfig =>
      (outputSchemaJsonb['chart_config'] as Map<String, dynamic>?) ?? {};

  String get narrativeTemplate =>
      (outputSchemaJsonb['narrative_template'] as String?) ?? '';

  int get defaultProjectionYears =>
      (uiConfigJsonb['default_projection_years'] as int?) ?? 3;

  int get minProjectionYears =>
      (inputSchemaJsonb['min_projection_years'] as int?) ?? 1;

  int get maxProjectionYears =>
      (inputSchemaJsonb['max_projection_years'] as int?) ?? 10;

  bool get hasProjectionYearsField =>
      (inputSchemaJsonb['projection_years_field'] as bool?) ?? false;

  String get confidenceMode =>
      (inputSchemaJsonb['confidence_mode'] as String?) ?? 'none';

  String get pdfTitle => (uiConfigJsonb['pdf_title'] as String?) ?? name;

  String get iconName => (uiConfigJsonb['icon'] as String?) ?? 'calculate';
}
