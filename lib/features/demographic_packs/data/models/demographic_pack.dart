class DemographicPack {
  final String id;
  final String name;
  final String description;
  final String targetAudience;

  /// Field values to pre-populate on the create-decision form.
  /// Keys map to decision form field ids.
  final Map<String, dynamic> prePopulateFields;

  const DemographicPack({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAudience,
    required this.prePopulateFields,
  });

  factory DemographicPack.fromJson(Map<String, dynamic> json) {
    return DemographicPack(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      targetAudience: json['target_audience'] as String? ?? '',
      prePopulateFields:
          (json['pre_populate_fields'] as Map<String, dynamic>?) ?? {},
    );
  }
}
