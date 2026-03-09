// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Decision _$DecisionFromJson(Map<String, dynamic> json) => _Decision(
  id: json['id'] as String,
  title: json['title'] as String,
  state: json['state'] as String,
  stakes: json['stakes'] as String?,
  initialConfidence: (json['initial_confidence'] as num?)?.toInt(),
  categoryName: json['category_name'] as String?,
  descriptionEncrypted: json['description_encrypted'] as String?,
  healthState: json['health_state'] as String?,
  decisionDeadline: json['decision_deadline'] == null
      ? null
      : DateTime.parse(json['decision_deadline'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  requiresApproval: json['requires_approval'] as bool? ?? false,
  sourceDecisionId: json['source_decision_id'] as String?,
  sharedToTeamAt: json['shared_to_team_at'] == null
      ? null
      : DateTime.parse(json['shared_to_team_at'] as String),
  sharedFromPersonalAt: json['shared_from_personal_at'] == null
      ? null
      : DateTime.parse(json['shared_from_personal_at'] as String),
  rawDescriptionEncrypted: json['raw_description_encrypted'] as String?,
);

Map<String, dynamic> _$DecisionToJson(_Decision instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'state': instance.state,
  'stakes': instance.stakes,
  'initial_confidence': instance.initialConfidence,
  'category_name': instance.categoryName,
  'description_encrypted': instance.descriptionEncrypted,
  'health_state': instance.healthState,
  'decision_deadline': instance.decisionDeadline?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'requires_approval': instance.requiresApproval,
  'source_decision_id': instance.sourceDecisionId,
  'shared_to_team_at': instance.sharedToTeamAt?.toIso8601String(),
  'shared_from_personal_at': instance.sharedFromPersonalAt?.toIso8601String(),
};
