// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'decision.freezed.dart';
part 'decision.g.dart';

@freezed
abstract class Decision with _$Decision {
  const Decision._();

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
    @Default(false) @JsonKey(name: 'requires_approval') bool requiresApproval,
    // Provenance — populated when this decision is a fork of another.
    @JsonKey(name: 'source_decision_id') String? sourceDecisionId,
    @JsonKey(name: 'shared_to_team_at') DateTime? sharedToTeamAt,
    @JsonKey(name: 'shared_from_personal_at') DateTime? sharedFromPersonalAt,
  }) = _Decision;

  factory Decision.fromJson(Map<String, dynamic> json) =>
      _$DecisionFromJson(json);

  bool get isActive => state == 'Active';
  bool get isDraft => state == 'Draft';
}
