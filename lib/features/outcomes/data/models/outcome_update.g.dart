// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outcome_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OutcomeUpdate _$OutcomeUpdateFromJson(Map<String, dynamic> json) =>
    _OutcomeUpdate(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      checkpointId: json['checkpoint_id'] as String?,
      recordedByUserId: json['recorded_by_user_id'] as String,
      outcomeTextEncrypted: json['outcome_text_encrypted'] as String?,
      outcomeQualityScore: (json['outcome_quality_score'] as num).toInt(),
      outcomeState: json['outcome_state'] as String?,
      lessonsLearnedEncrypted: json['lessons_learned_encrypted'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$OutcomeUpdateToJson(_OutcomeUpdate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'decision_id': instance.decisionId,
      'checkpoint_id': instance.checkpointId,
      'recorded_by_user_id': instance.recordedByUserId,
      'outcome_text_encrypted': instance.outcomeTextEncrypted,
      'outcome_quality_score': instance.outcomeQualityScore,
      'outcome_state': instance.outcomeState,
      'lessons_learned_encrypted': instance.lessonsLearnedEncrypted,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
