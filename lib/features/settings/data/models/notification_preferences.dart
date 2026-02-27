import 'package:flutter/foundation.dart';

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    required this.weeklyDigestEnabled,
    required this.weeklyDigestTimezone,
    required this.activationEmailsEnabled,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final bool weeklyDigestEnabled;
  final String weeklyDigestTimezone;
  final bool activationEmailsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      weeklyDigestEnabled:
          json['weekly_digest_enabled'] as bool? ?? true,
      weeklyDigestTimezone:
          json['weekly_digest_timezone'] as String? ?? 'Europe/London',
      activationEmailsEnabled:
          json['activation_emails_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
