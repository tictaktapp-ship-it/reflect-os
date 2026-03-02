class WorkspaceModel {
  const WorkspaceModel({
    required this.id,
    required this.name,
    required this.workspaceType,
    required this.role,
    this.ownerUserId,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String workspaceType;
  final String role;
  final String? ownerUserId;
  final DateTime? joinedAt;

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) => WorkspaceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        workspaceType: json['workspace_type'] as String? ?? 'personal',
        role: json['role'] as String? ?? 'member',
        ownerUserId: json['owner_user_id'] as String?,
        joinedAt: json['joined_at'] == null
            ? null
            : DateTime.parse(json['joined_at'] as String),
      );
}
