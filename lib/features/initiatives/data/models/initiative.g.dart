// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initiative.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Initiative _$InitiativeFromJson(Map<String, dynamic> json) => _Initiative(
  id: json['id'] as String,
  workspaceId: json['workspace_id'] as String,
  name: json['name'] as String,
  descriptionEncrypted: json['description_encrypted'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$InitiativeToJson(_Initiative instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workspace_id': instance.workspaceId,
      'name': instance.name,
      'description_encrypted': instance.descriptionEncrypted,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
