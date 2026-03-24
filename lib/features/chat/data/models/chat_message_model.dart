import 'package:reflect_os/features/chat/data/models/chat_reaction_model.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.workspaceId,
    required this.senderUserId,
    required this.content,
    required this.createdAt,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.senderName,
    this.senderAvatarUrl,
    this.reactions = const [],
  });

  final String id;
  final String workspaceId;
  final String senderUserId;
  final String content;
  final DateTime createdAt;
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? senderName;
  final String? senderAvatarUrl;
  final List<ChatReactionModel> reactions;

  bool get isDeleted => deletedAt != null;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String? senderName;
    String? senderAvatarUrl;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      senderName = profiles['display_name'] as String?;
      senderAvatarUrl = profiles['avatar_url'] as String?;
    }
    return ChatMessageModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      replyToMessageId: json['reply_to_message_id'] as String?,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String).toLocal(),
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
    );
  }

  ChatMessageModel copyWith({
    String? content,
    DateTime? editedAt,
    DateTime? deletedAt,
    List<ChatReactionModel>? reactions,
  }) {
    return ChatMessageModel(
      id: id,
      workspaceId: workspaceId,
      senderUserId: senderUserId,
      content: content ?? this.content,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      reactions: reactions ?? this.reactions,
    );
  }
}
