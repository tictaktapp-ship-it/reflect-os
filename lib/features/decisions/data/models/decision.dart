// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'decision.freezed.dart';
part 'decision.g.dart';

@freezed
abstract class Decision with _$Decision {
  const factory Decision({
    required String id,
    required String title,
    required String state,
    String? stakes,
    @JsonKey(name: 'initial_confidence') int? initialConfidence,
    @JsonKey(name: 'category_name') String? categoryName,
    @JsonKey(name: 'description_encrypted') String? descriptionEncrypted,
    @JsonKey(name: 'health_state') String? healthState,
    @JsonKey(name: 'decision_deadline') DateTime? decisionDeadline,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Decision;

  factory Decision.fromJson(Map<String, dynamic> json) =>
      _$DecisionFromJson(json);
}
