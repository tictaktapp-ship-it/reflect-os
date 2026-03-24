import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/features/chat/data/models/chat_message_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_reaction_model.dart';
import 'package:reflect_os/features/chat/widgets/emoji_picker_sheet.dart';

enum MessageDeliveryStatus { sent, delivered, read }

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.replyToMessage,
    required this.onReply,
    required this.onReact,
    required this.onEdit,
    required this.onDelete,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  final ChatMessageModel message;
  final bool isMine;
  final String currentUserId;
  final ChatMessageModel? replyToMessage;
  final VoidCallback onReply;
  final void Function(String emoji) onReact;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final MessageDeliveryStatus deliveryStatus;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _DeletedBubble(isMine: isMine, createdAt: message.createdAt);
    }

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: isMine ? _MyBubble(this) : _TheirBubble(this),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final canEdit = isMine &&
        DateTime.now().difference(message.createdAt).inMinutes < 5;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(ctx);
                showEmojiPickerSheet(context, onEmojiSelected: onReact);
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit?.call();
                },
              ),
            if (isMine)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    final grouped = <String, List<ChatReactionModel>>{};
    for (final r in message.reactions) {
      grouped.putIfAbsent(r.emoji, () => []).add(r);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: grouped.entries.map((entry) {
          final iReacted =
              entry.value.any((r) => r.userId == currentUserId);
          return GestureDetector(
            onTap: () => onReact(entry.key),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iReacted
                    ? const Color(0xFF19CBD6).withValues(alpha: 0.15)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iReacted
                      ? const Color(0xFF19CBD6)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('${entry.value.length}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (deliveryStatus) {
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check, size: 12, color: Color(0xFF9CA3AF));
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all,
            size: 12, color: Color(0xFF9CA3AF));
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all,
            size: 12, color: Color(0xFF19CBD6));
    }
  }

  Widget _buildReplyPreview(BuildContext context) {
    if (replyToMessage == null) return const SizedBox.shrink();
    final displayName =
        replyToMessage!.senderName ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: Color(0xFF19CBD6), width: 3),
        ),
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF19CBD6),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            replyToMessage!.isDeleted
                ? 'Message deleted'
                : replyToMessage!.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

// ── My bubble ──────────────────────────────────────────────────────────────────

class _MyBubble extends StatelessWidget {
  const _MyBubble(this.b);
  final ChatMessageBubble b;

  @override
  Widget build(BuildContext context) {
    final timeStr = ChatMessageBubble._timeFmt.format(b.message.createdAt);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            b._buildReplyPreview(context),
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF19CBD6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.zero,
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.message.content,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                  if (b.message.editedAt != null)
                    const Text('(edited)',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            b._buildReactions(context),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeStr,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
                const SizedBox(width: 4),
                b._buildStatusIcon(),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── Their bubble ───────────────────────────────────────────────────────────────

class _TheirBubble extends StatelessWidget {
  const _TheirBubble(this.b);
  final ChatMessageBubble b;

  @override
  Widget build(BuildContext context) {
    final timeStr = ChatMessageBubble._timeFmt.format(b.message.createdAt);
    final name = b.message.senderName ?? 'Unknown';
    final initials = _initials(name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF19CBD6),
          backgroundImage: b.message.senderAvatarUrl != null
              ? NetworkImage(b.message.senderAvatarUrl!)
              : null,
          child: b.message.senderAvatarUrl == null
              ? Text(initials,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600))
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            b._buildReplyPreview(context),
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.message.content,
                      style: const TextStyle(fontSize: 14)),
                  if (b.message.editedAt != null)
                    const Text('(edited)',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            b._buildReactions(context),
            Text(timeStr,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'[\s@]+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Deleted bubble ─────────────────────────────────────────────────────────────

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.isMine, required this.createdAt});
  final bool isMine;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: isMine
            ? const EdgeInsets.only(left: 40)
            : const EdgeInsets.only(left: 40),
        child: const Text(
          'Message deleted',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
