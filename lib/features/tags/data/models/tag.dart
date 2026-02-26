class Tag {
  const Tag({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final DateTime createdAt;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
