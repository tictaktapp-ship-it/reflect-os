// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

@freezed
abstract class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    // Nullable: activation-sequence notifications are user-scoped, not workspace-scoped.
    @JsonKey(name: 'workspace_id') String? workspaceId,
    required String type,
    String? title,
    String? body,
    @JsonKey(name: 'related_entity_type') String? relatedEntityType,
    @JsonKey(name: 'related_entity_id') String? relatedEntityId,
    @JsonKey(name: 'scheduled_for') required DateTime scheduledFor,
    required String status,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
