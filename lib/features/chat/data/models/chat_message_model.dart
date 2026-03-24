import 'package:reflect_os/features/chat/data/models/chat_attachment_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_reaction_model.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.workspaceId,
    required this.senderUserId,
    this.content,
    required this.createdAt,
    this.hasAttachment = false,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.senderName,
    this.senderAvatarUrl,
    this.reactions = const [],
    this.attachments = const [],
  });

  final String id;
  final String workspaceId;
  final String senderUserId;
  final String? content;
  final DateTime createdAt;
  final bool hasAttachment;
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? senderName;
  final String? senderAvatarUrl;
  final List<ChatReactionModel> reactions;
  final List<ChatAttachmentModel> attachments;

  bool get isDeleted => deletedAt != null;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String? senderName;
    String? senderAvatarUrl;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      senderName = profiles['display_name'] as String?;
      senderAvatarUrl = profiles['avatar_url'] as String?;
    }

    final attachmentsRaw = json['chat_attachments'];
    final attachments = attachmentsRaw is List
        ? attachmentsRaw
            .map((a) =>
                ChatAttachmentModel.fromJson(a as Map<String, dynamic>))
            .toList()
        : <ChatAttachmentModel>[];

    return ChatMessageModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      hasAttachment: json['has_attachment'] as bool? ?? false,
      replyToMessageId: json['reply_to_message_id'] as String?,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String).toLocal(),
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      attachments: attachments,
    );
  }

  ChatMessageModel copyWith({
    String? content,
    bool? hasAttachment,
    DateTime? editedAt,
    DateTime? deletedAt,
    List<ChatReactionModel>? reactions,
    List<ChatAttachmentModel>? attachments,
  }) {
    return ChatMessageModel(
      id: id,
      workspaceId: workspaceId,
      senderUserId: senderUserId,
      content: content ?? this.content,
      createdAt: createdAt,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      replyToMessageId: replyToMessageId,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      reactions: reactions ?? this.reactions,
      attachments: attachments ?? this.attachments,
    );
  }
}
