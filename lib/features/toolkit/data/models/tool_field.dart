// Parsed representation of one field from the tool input or output schema.

class ToolInputField {
  final String id;
  final String label;

  /// 'number' | 'text' | 'array' | 'object'
  final String type;
  final String? unit;
  final double? min;
  final double? max;
  final bool required;
  final dynamic defaultValue;
  final String? hint;

  // For array types
  final String? itemType; // 'number' | 'object'
  final Map<String, dynamic>? itemSchema; // sub-fields for item_type=object
  final int? minItems;
  final int? maxItems;

  const ToolInputField({
    required this.id,
    required this.label,
    required this.type,
    this.unit,
    this.min,
    this.max,
    required this.required,
    this.defaultValue,
    this.hint,
    this.itemType,
    this.itemSchema,
    this.minItems,
    this.maxItems,
  });

  factory ToolInputField.fromJson(Map<String, dynamic> json) {
    return ToolInputField(
      id: json['id'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      unit: json['unit'] as String?,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      required: (json['required'] as bool?) ?? false,
      defaultValue: json['default'],
      hint: json['hint'] as String?,
      itemType: json['item_type'] as String?,
      itemSchema: json['item_schema'] as Map<String, dynamic>?,
      minItems: json['min_items'] as int?,
      maxItems: json['max_items'] as int?,
    );
  }
}

class ToolOutputField {
  final String id;
  final String label;
  final String type;
  final String? unit;
  final int displayOrder;

  const ToolOutputField({
    required this.id,
    required this.label,
    required this.type,
    this.unit,
    required this.displayOrder,
  });

  factory ToolOutputField.fromJson(Map<String, dynamic> json) {
    return ToolOutputField(
      id: json['id'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      unit: json['unit'] as String?,
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}
