class DecisionStakeholder {
  const DecisionStakeholder({
    required this.id,
    required this.decisionId,
    this.userId,
    required this.stakeholderRole,
    required this.createdAt,
    this.stakeholderName,
    this.stakeholderEmail,
  });

  final String id;
  final String decisionId;
  final String? userId;
  final String stakeholderRole;
  final DateTime createdAt;
  final String? stakeholderName;
  final String? stakeholderEmail;

  /// Display name: stakeholder_name > email > first 8 chars of userId.
  String get displayName {
    if (stakeholderName?.isNotEmpty == true) return stakeholderName!;
    if (stakeholderEmail?.isNotEmpty == true) return stakeholderEmail!;
    final uid = userId ?? '';
    return uid.length >= 8 ? uid.substring(0, 8) : uid;
  }

  factory DecisionStakeholder.fromJson(Map<String, dynamic> json) =>
      DecisionStakeholder(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        userId: json['user_id'] as String?,
        stakeholderRole: json['stakeholder_role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        stakeholderName: json['stakeholder_name'] as String?,
        stakeholderEmail: json['stakeholder_email'] as String?,
      );
}
