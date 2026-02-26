import 'package:flutter/foundation.dart';

@immutable
class ApprovalRecord {
  const ApprovalRecord({
    required this.id,
    required this.decisionId,
    required this.approverUserId,
    required this.status,
    this.decidedAt,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String approverUserId;

  /// 'Pending' | 'Approved' | 'Rejected'
  final String status;
  final DateTime? decidedAt;
  final DateTime createdAt;

  factory ApprovalRecord.fromJson(Map<String, dynamic> json) {
    return ApprovalRecord(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      approverUserId: json['approver_user_id'] as String,
      status: json['status'] as String,
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
