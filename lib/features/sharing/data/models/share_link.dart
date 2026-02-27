import 'package:flutter/foundation.dart';

@immutable
class ShareLink {
  const ShareLink({
    required this.id,
    required this.decisionId,
    required this.createdByUserId,
    required this.tokenHash,
    this.expiresAt,
    this.revokedAt,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String createdByUserId;
  final String tokenHash;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  bool get isActive =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory ShareLink.fromJson(Map<String, dynamic> json) {
    return ShareLink(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      tokenHash: json['token_hash'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
