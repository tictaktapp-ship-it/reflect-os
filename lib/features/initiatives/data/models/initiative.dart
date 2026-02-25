// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'initiative.freezed.dart';
part 'initiative.g.dart';

@freezed
abstract class Initiative with _$Initiative {
  const factory Initiative({
    required String id,
    @JsonKey(name: 'workspace_id') required String workspaceId,
    required String name,
    @JsonKey(name: 'description_encrypted') String? descriptionEncrypted,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Initiative;

  factory Initiative.fromJson(Map<String, dynamic> json) =>
      _$InitiativeFromJson(json);
}
