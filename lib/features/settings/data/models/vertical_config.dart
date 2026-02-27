import 'package:flutter/foundation.dart';

@immutable
class VerticalConfig {
  const VerticalConfig({
    required this.id,
    required this.verticalName,
    required this.displayName,
    required this.description,
    required this.suggestedTags,
    required this.suggestedCategories,
    required this.defaultCheckpointSchedule,
    required this.features,
  });

  final String id;
  final String verticalName;
  final String displayName;
  final String description;
  final List<String> suggestedTags;
  final List<String> suggestedCategories;
  final List<Map<String, dynamic>> defaultCheckpointSchedule;
  final Map<String, dynamic> features;

  factory VerticalConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['config_jsonb'];
    final config = raw != null
        ? Map<String, dynamic>.from(raw as Map)
        : <String, dynamic>{};

    return VerticalConfig(
      id: json['id'] as String,
      verticalName: json['vertical_name'] as String,
      displayName: config['display_name'] as String? ??
          json['vertical_name'] as String,
      description: config['description'] as String? ?? '',
      suggestedTags: _stringList(config['suggested_tags']),
      suggestedCategories: _stringList(config['suggested_categories']),
      defaultCheckpointSchedule:
          _mapList(config['default_checkpoint_schedule']),
      features: config['features'] is Map
          ? Map<String, dynamic>.from(config['features'] as Map)
          : const {},
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
}
