import 'package:flutter/foundation.dart';

@immutable
class IcVote {
  const IcVote({
    required this.id,
    required this.decisionId,
    required this.voterUserId,
    required this.vote,
    this.dissentNotes,
    required this.votedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String decisionId;
  final String voterUserId;

  /// 'Yes' | 'No' | 'Abstain'
  final String vote;
  final String? dissentNotes;
  final DateTime votedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory IcVote.fromJson(Map<String, dynamic> json) => IcVote(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        voterUserId: json['voter_user_id'] as String,
        vote: json['vote'] as String,
        dissentNotes: json['dissent_notes_encrypted'] as String?,
        votedAt: DateTime.parse(json['voted_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
