class WorkspaceMembership {
  const WorkspaceMembership({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String userId;
  final String role;
  final DateTime createdAt;

  factory WorkspaceMembership.fromJson(Map<String, dynamic> json) =>
      WorkspaceMembership(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
