// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'outcome_update.freezed.dart';
part 'outcome_update.g.dart';

@freezed
abstract class OutcomeUpdate with _$OutcomeUpdate {
  const factory OutcomeUpdate({
    required String id,
    @JsonKey(name: 'decision_id') required String decisionId,
    @JsonKey(name: 'checkpoint_id') String? checkpointId,
    @JsonKey(name: 'recorded_by_user_id') required String recordedByUserId,
    @JsonKey(name: 'outcome_text_encrypted') String? outcomeTextEncrypted,
    @JsonKey(name: 'outcome_quality_score') required int outcomeQualityScore,
    @JsonKey(name: 'outcome_state') String? outcomeState,
    @JsonKey(name: 'lessons_learned_encrypted') String? lessonsLearnedEncrypted,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _OutcomeUpdate;

  factory OutcomeUpdate.fromJson(Map<String, dynamic> json) =>
      _$OutcomeUpdateFromJson(json);
}
