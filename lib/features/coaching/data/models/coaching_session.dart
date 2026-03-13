import 'package:flutter/foundation.dart';

@immutable
class CoachingSession {
  const CoachingSession({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.scheduledAt,
    required this.status,
    required this.durationMinutes,
    this.workspaceId,
    this.title,
    this.notesEncrypted,
    this.resourceUrl,
    this.resourceLabel,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String? workspaceId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? title;
  final String? notesEncrypted;
  final String? resourceUrl;
  final String? resourceLabel;
  final String status;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  bool get isOverdue =>
      status == 'scheduled' && scheduledAt.isBefore(DateTime.now());

  factory CoachingSession.fromJson(Map<String, dynamic> json) => CoachingSession(
        id: json['id'] as String,
        coachUserId: json['coach_user_id'] as String,
        clientUserId: json['client_user_id'] as String,
        workspaceId: json['workspace_id'] as String?,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        durationMinutes: json['duration_minutes'] as int? ?? 60,
        title: json['title'] as String?,
        notesEncrypted: json['notes_encrypted'] as String?,
        resourceUrl: json['resource_url'] as String?,
        resourceLabel: json['resource_label'] as String?,
        status: json['status'] as String? ?? 'scheduled',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      );
}
