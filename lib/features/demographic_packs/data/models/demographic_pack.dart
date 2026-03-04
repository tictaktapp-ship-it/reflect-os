class DemographicPack {
  final String id;
  final String key;
  final String displayName;
  final String description;
  final bool isActive;
  final Map<String, dynamic> preferencesJsonb;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DemographicPack({
    required this.id,
    required this.key,
    required this.displayName,
    required this.description,
    required this.isActive,
    required this.preferencesJsonb,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DemographicPack.fromJson(Map<String, dynamic> json) {
    return DemographicPack(
      id:               json['id']           as String,
      key:              json['key']          as String,
      displayName:      json['display_name'] as String,
      description:      json['description']  as String? ?? '',
      isActive:         json['is_active']    as bool? ?? true,
      preferencesJsonb: json['preferences_jsonb'] as Map<String, dynamic>? ?? {},
      createdAt:        DateTime.parse(json['created_at'] as String),
      updatedAt:        DateTime.parse(json['updated_at'] as String),
    );
  }
}
