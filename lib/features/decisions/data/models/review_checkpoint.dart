class ReviewCheckpoint {
  const ReviewCheckpoint({
    required this.id,
    required this.decisionId,
    required this.checkpointType,
    required this.dueAt,
    this.snoozedUntil,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String decisionId;
  final String checkpointType;
  final DateTime dueAt;
  final DateTime? snoozedUntil;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReviewCheckpoint.fromJson(Map<String, dynamic> json) =>
      ReviewCheckpoint(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        checkpointType: json['checkpoint_type'] as String,
        dueAt: DateTime.parse(json['due_at'] as String),
        snoozedUntil: json['snoozed_until'] == null
            ? null
            : DateTime.parse(json['snoozed_until'] as String),
        status: json['status'] as String,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
