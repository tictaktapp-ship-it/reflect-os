import 'package:flutter/foundation.dart';

@immutable
class CoachingSessionNote {
  const CoachingSessionNote({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.bodyEncrypted,
    required this.createdAt,
    this.workspaceId,
    this.updatedAt,
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String? workspaceId;
  final String bodyEncrypted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory CoachingSessionNote.fromJson(Map<String, dynamic> json) =>
      CoachingSessionNote(
        id: json['id'] as String,
        coachUserId: json['coach_user_id'] as String,
        clientUserId: json['client_user_id'] as String,
        workspaceId: json['workspace_id'] as String?,
        bodyEncrypted: json['body_encrypted'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}
