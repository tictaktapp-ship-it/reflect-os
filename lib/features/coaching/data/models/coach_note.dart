import 'package:flutter/foundation.dart';

@immutable
class CoachNote {
  const CoachNote({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    this.decisionId,
    required this.noteEncrypted,
    required this.createdAt,
    this.coachingSessionId,
    this.coachConfidenceAdjustment,
    this.visibility = 'coach_only',
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String? decisionId;
  final String noteEncrypted;
  final DateTime createdAt;
  final String? coachingSessionId;
  final int? coachConfidenceAdjustment;
  final String visibility;

  factory CoachNote.fromJson(Map<String, dynamic> json) => CoachNote(
        id: json['id'] as String,
        coachUserId: json['coach_user_id'] as String,
        clientUserId: json['client_user_id'] as String,
        decisionId: json['decision_id'] as String?,
        noteEncrypted: json['note_encrypted'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        coachingSessionId: json['coaching_session_id'] as String?,
        coachConfidenceAdjustment:
            json['coach_confidence_adjustment'] as int?,
        visibility: json['visibility'] as String? ?? 'coach_only',
      );
}
