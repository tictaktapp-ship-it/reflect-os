// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Decision _$DecisionFromJson(Map<String, dynamic> json) => _Decision(
  id: json['id'] as String,
  title: json['title'] as String,
  status: json['status'] as String,
  decisionDate: json['decisionDate'] == null
      ? null
      : DateTime.parse(json['decisionDate'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$DecisionToJson(_Decision instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'status': instance.status,
  'decisionDate': instance.decisionDate?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
