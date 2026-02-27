import 'package:flutter/foundation.dart';

@immutable
class CalendarConnection {
  const CalendarConnection({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.provider,
    this.deletedAt,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String userId;
  final String provider;
  final DateTime? deletedAt;
  final DateTime createdAt;

  bool get isConnected => deletedAt == null;

  factory CalendarConnection.fromJson(Map<String, dynamic> json) {
    return CalendarConnection(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      userId: json['user_id'] as String,
      provider: json['provider'] as String,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
