class DecisionRelationship {
  const DecisionRelationship({
    required this.id,
    required this.workspaceId,
    required this.fromDecisionId,
    required this.toDecisionId,
    required this.relationshipType,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String workspaceId;
  final String fromDecisionId;
  final String toDecisionId;
  final String relationshipType;
  final DateTime createdAt;
  final DateTime? deletedAt;

  factory DecisionRelationship.fromJson(Map<String, dynamic> json) =>
      DecisionRelationship(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        fromDecisionId: json['from_decision_id'] as String,
        toDecisionId: json['to_decision_id'] as String,
        relationshipType: json['relationship_type'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
      );
}
