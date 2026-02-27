import 'package:flutter/foundation.dart';

@immutable
class GdprRequest {
  const GdprRequest({
    required this.id,
    required this.userId,
    required this.requestType,
    required this.status,
    this.reason,
    required this.createdAt,
    this.cancelledAt,
    this.completedAt,
  });

  final String id;
  final String userId;

  /// 'deletion' | 'anonymisation' | 'export'
  final String requestType;

  /// 'Pending' | 'Processing' | 'Complete' | 'Cancelled'
  final String status;
  final String? reason;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  bool get isPending => status == 'Pending';
  bool get isCancellable => status == 'Pending';

  factory GdprRequest.fromJson(Map<String, dynamic> json) => GdprRequest(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        requestType: json['request_type'] as String,
        status: json['status'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        cancelledAt: json['cancelled_at'] != null
            ? DateTime.parse(json['cancelled_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );
}
