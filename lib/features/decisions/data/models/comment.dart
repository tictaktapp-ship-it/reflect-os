class Comment {
  const Comment({
    required this.id,
    required this.threadId,
    this.authorUserId,
    required this.bodyEncrypted,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String? authorUserId;
  final String bodyEncrypted;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        authorUserId: json['author_user_id'] as String?,
        bodyEncrypted: json['body_encrypted'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
