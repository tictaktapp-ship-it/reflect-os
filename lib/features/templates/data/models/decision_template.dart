import 'package:flutter/foundation.dart';

@immutable
class DecisionTemplate {
  const DecisionTemplate({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.descriptionEncrypted,
    this.defaultStakes,
    required this.defaultCheckpointSchedule,
    required this.suggestedStakeholderRoles,
    required this.requiresApproval,
    required this.isSystem,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String? descriptionEncrypted;
  final String? defaultStakes;
  final List<String> defaultCheckpointSchedule;
  final List<String> suggestedStakeholderRoles;
  final bool requiresApproval;
  final bool isSystem;
  final DateTime createdAt;

  factory DecisionTemplate.fromJson(Map<String, dynamic> json) {
    return DecisionTemplate(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      name: json['name'] as String,
      descriptionEncrypted: json['description_encrypted'] as String?,
      defaultStakes: json['default_stakes'] as String?,
      defaultCheckpointSchedule:
          (json['default_checkpoint_schedule_jsonb'] as List?)
                  ?.cast<String>() ??
              [],
      suggestedStakeholderRoles:
          (json['suggested_stakeholder_roles_jsonb'] as List?)
                  ?.cast<String>() ??
              [],
      requiresApproval: json['requires_approval'] as bool? ?? false,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
