class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.workspaceId,
    required this.actorUserId,
    required this.eventType,
    required this.subjectEntityType,
    required this.subjectEntityId,
    required this.metadataJsonb,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String actorUserId;
  final String eventType;
  final String subjectEntityType;
  final String subjectEntityId;
  final Map<String, dynamic> metadataJsonb;
  final DateTime createdAt;

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        actorUserId: json['actor_user_id'] as String,
        eventType: json['event_type'] as String,
        subjectEntityType: json['subject_entity_type'] as String,
        subjectEntityId: json['subject_entity_id'] as String,
        metadataJsonb:
            (json['metadata_jsonb'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
