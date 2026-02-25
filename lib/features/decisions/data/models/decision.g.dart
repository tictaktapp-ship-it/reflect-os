// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Decision _$DecisionFromJson(Map<String, dynamic> json) => _Decision(
  id: json['id'] as String,
  title: json['title'] as String,
  state: json['state'] as String,
  decisionDeadline: json['decision_deadline'] == null
      ? null
      : DateTime.parse(json['decision_deadline'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$DecisionToJson(_Decision instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'state': instance.state,
  'decision_deadline': instance.decisionDeadline?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};
