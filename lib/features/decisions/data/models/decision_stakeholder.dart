class DecisionStakeholder {
  const DecisionStakeholder({
    required this.id,
    required this.decisionId,
    required this.userId,
    required this.stakeholderRole,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String userId;
  final String stakeholderRole;
  final DateTime createdAt;

  factory DecisionStakeholder.fromJson(Map<String, dynamic> json) =>
      DecisionStakeholder(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        userId: json['user_id'] as String,
        stakeholderRole: json['stakeholder_role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
