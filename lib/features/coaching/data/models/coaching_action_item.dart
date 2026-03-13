import 'package:flutter/foundation.dart';

@immutable
class CoachingActionItem {
  const CoachingActionItem({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.title,
    required this.createdAt,
    this.decisionId,
    this.coachingSessionId,
    this.descriptionEncrypted,
    this.dueDate,
    this.completedAt,
    this.deletedAt,
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String? decisionId;
  final String? coachingSessionId;
  final String title;
  final String? descriptionEncrypted;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isCompleted => completedAt != null;
  bool get isOverdue =>
      !isCompleted && dueDate != null && dueDate!.isBefore(DateTime.now());

  factory CoachingActionItem.fromJson(Map<String, dynamic> json) =>
      CoachingActionItem(
        id: json['id'] as String,
        coachUserId: json['coach_user_id'] as String,
        clientUserId: json['client_user_id'] as String,
        decisionId: json['decision_id'] as String?,
        coachingSessionId: json['coaching_session_id'] as String?,
        title: json['title'] as String,
        descriptionEncrypted: json['description_encrypted'] as String?,
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      );
}
