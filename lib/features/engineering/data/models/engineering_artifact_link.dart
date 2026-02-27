import 'package:flutter/foundation.dart';

@immutable
class EngineeringArtifactLink {
  const EngineeringArtifactLink({
    required this.id,
    required this.workspaceId,
    required this.decisionId,
    required this.artifactType,
    required this.url,
    this.label,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String decisionId;

  /// 'RFC' | 'ADR' | 'PR' | 'Ticket' | 'Incident' | 'Runbook' | 'Other'
  final String artifactType;
  final String url;
  final String? label;
  final DateTime createdAt;

  factory EngineeringArtifactLink.fromJson(Map<String, dynamic> json) =>
      EngineeringArtifactLink(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        decisionId: json['decision_id'] as String,
        artifactType: json['artifact_type'] as String,
        url: json['url'] as String,
        label: json['label'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
