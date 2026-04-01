// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) =>
    _NotificationItem(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String?,
      type: json['type'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      relatedEntityType: json['related_entity_type'] as String?,
      relatedEntityId: json['related_entity_id'] as String?,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      status: json['status'] as String,
    );

Map<String, dynamic> _$NotificationItemToJson(_NotificationItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workspace_id': instance.workspaceId,
      'type': instance.type,
      'title': instance.title,
      'body': instance.body,
      'related_entity_type': instance.relatedEntityType,
      'related_entity_id': instance.relatedEntityId,
      'scheduled_for': instance.scheduledFor.toIso8601String(),
      'status': instance.status,
    };
