class CommentThread {
  const CommentThread({
    required this.id,
    required this.decisionId,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String state;
  final DateTime createdAt;

  factory CommentThread.fromJson(Map<String, dynamic> json) => CommentThread(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        state: json['state'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
