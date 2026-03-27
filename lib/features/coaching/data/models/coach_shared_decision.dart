import 'package:flutter/foundation.dart';

@immutable
class CoachSharedDecision {
  const CoachSharedDecision({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.decisionId,
    required this.sharedAt,
    required this.createdAt,
    this.revokedAt,
    this.decisionTitle,
    this.decisionState,
    this.decisionHealthState,
    this.categoryName,
    this.initialConfidence,
    this.stakes,
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String decisionId;
  final DateTime sharedAt;
  final DateTime createdAt;
  final DateTime? revokedAt;

  // Flattened from joined decisions table
  final String? decisionTitle;
  final String? decisionState;
  final String? decisionHealthState;
  final String? categoryName;
  final int? initialConfidence;
  final String? stakes;

  bool get isRevoked => revokedAt != null;

  factory CoachSharedDecision.fromJson(Map<String, dynamic> json) {
    final d = json['decisions'] as Map<String, dynamic>?;
    return CoachSharedDecision(
      id: json['id'] as String,
      coachUserId: json['coach_user_id'] as String,
      clientUserId: json['client_user_id'] as String,
      decisionId: json['decision_id'] as String,
      sharedAt: DateTime.parse(json['shared_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      decisionTitle: d?['title'] as String?,
      decisionState: d?['state'] as String?,
      decisionHealthState: d?['health_state'] as String?,
      categoryName: d?['category_name'] as String?,
      initialConfidence: d?['initial_confidence'] as int?,
      stakes: d?['stakes'] as String?,
    );
  }
}
