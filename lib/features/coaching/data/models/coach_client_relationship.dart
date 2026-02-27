import 'package:flutter/foundation.dart';

@immutable
class CoachClientRelationship {
  const CoachClientRelationship({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.status,
    required this.grantedAt,
    this.revokedAt,
  });

  final String id;
  final String coachUserId;
  final String clientUserId;
  final String status;
  final DateTime grantedAt;
  final DateTime? revokedAt;

  bool get isActive => status == 'Active' && revokedAt == null;

  factory CoachClientRelationship.fromJson(Map<String, dynamic> json) =>
      CoachClientRelationship(
        id: json['id'] as String,
        coachUserId: json['coach_user_id'] as String,
        clientUserId: json['client_user_id'] as String,
        status: json['status'] as String,
        grantedAt: DateTime.parse(json['granted_at'] as String),
        revokedAt: json['revoked_at'] != null
            ? DateTime.parse(json['revoked_at'] as String)
            : null,
      );
}
