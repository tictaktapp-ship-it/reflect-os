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
    @JsonKey(name: 'decision_deadline') DateTime? decisionDeadline,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Decision;

  factory Decision.fromJson(Map<String, dynamic> json) =>
      _$DecisionFromJson(json);
}
