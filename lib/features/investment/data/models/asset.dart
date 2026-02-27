import 'package:flutter/foundation.dart';

@immutable
class Asset {
  const Asset({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.sector,
    this.stage,
    this.geography,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String? sector;
  final String? stage;
  final String? geography;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        name: json['name'] as String,
        sector: json['sector'] as String?,
        stage: json['stage'] as String?,
        geography: json['geography'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
