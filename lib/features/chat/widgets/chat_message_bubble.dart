import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/chat/data/models/chat_attachment_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_message_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_reaction_model.dart';
import 'package:reflect_os/features/chat/widgets/emoji_picker_sheet.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

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
    this.onDownload,
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
  final void Function(ChatAttachmentModel)? onDownload;
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
        message.content != null &&
        DateTime.now().difference(message.createdAt).inMinutes < 5;
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
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
            if (message.content != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(
                      ClipboardData(text: message.content ?? ''));
                },
              ),
            for (final attachment in message.attachments)
              ListTile(
                leading: Icon(
                  attachment.isImage
                      ? Icons.save_alt
                      : Icons.download_outlined,
                  color: const Color(0xFF19CBD6),
                ),
                title: Text(
                    attachment.isImage ? 'Save image' : 'Download file'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDownload?.call(attachment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    if (message.attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: message.attachments
          .map((a) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: _AttachmentDisplay(
                    attachment: a,
                    isMine: isMine,
                    onDownload: () => onDownload?.call(a),
                  ),
                ),
              ))
          .toList(),
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
            child: Builder(
              builder: (context) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iReacted
                    ? AppColorScheme.accent.withValues(alpha: 0.15)
                    : context.cs.backgroundElevated,
                borderRadius: AppRadius.mdBR,
                border: Border.all(
                  color: iReacted
                      ? AppColorScheme.accent
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
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIcon([BuildContext? ctx]) {
    switch (deliveryStatus) {
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check, size: 12,
            color: ctx != null ? ctx.cs.textTertiary : const Color(0xFF9CA3AF));
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all, size: 12,
            color: ctx != null ? ctx.cs.textTertiary : const Color(0xFF9CA3AF));
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all,
            size: 12, color: AppColorScheme.accent);
    }
  }

  Widget _buildReplyPreview(BuildContext context) {
    if (replyToMessage == null) return const SizedBox.shrink();
    final displayName = replyToMessage!.senderName ?? 'Unknown';
    final previewText = replyToMessage!.isDeleted
        ? 'Message deleted'
        : replyToMessage!.content ??
            (replyToMessage!.hasAttachment ? '📎 Attachment' : '');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: Color(0xFF19CBD6), width: 3),
        ),
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: AppRadius.xsBR,
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
            previewText,
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
            if (b.message.content != null || b.message.attachments.isEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF19CBD6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.zero,
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (b.message.content != null)
                      Text(b.message.content!,
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
            b._buildAttachments(context),
            b._buildReactions(context),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 10,
                        color: context.cs.textTertiary)),
                const SizedBox(width: 4),
                b._buildStatusIcon(context),
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
                style: TextStyle(
                    fontSize: 11, color: context.cs.textTertiary)),
            const SizedBox(height: 2),
            b._buildReplyPreview(context),
            if (b.message.content != null || b.message.attachments.isEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cs.backgroundElevated,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.zero,
                    topRight: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (b.message.content != null)
                      Text(b.message.content!,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.cs.textPrimary)),
                    if (b.message.editedAt != null)
                      Text('(edited)',
                          style: TextStyle(
                              fontSize: 10,
                              color: context.cs.textTertiary,
                              fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            b._buildAttachments(context),
            b._buildReactions(context),
            Text(timeStr,
                style: TextStyle(
                    fontSize: 10,
                    color: context.cs.textTertiary)),
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
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Builder(
        builder: (context) => Text(
          'Message deleted',
          style: TextStyle(
            fontSize: 12,
            color: context.cs.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ── Attachment display ─────────────────────────────────────────────────────────

class _AttachmentDisplay extends StatefulWidget {
  const _AttachmentDisplay({
    required this.attachment,
    required this.isMine,
    required this.onDownload,
  });

  final ChatAttachmentModel attachment;
  final bool isMine;
  final VoidCallback onDownload;

  @override
  State<_AttachmentDisplay> createState() => _AttachmentDisplayState();
}

class _AttachmentDisplayState extends State<_AttachmentDisplay> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrl();
  }

  Future<void> _fetchSignedUrl() async {
    try {
      final url = await supabase.storage
          .from('chat-attachments')
          .createSignedUrl(widget.attachment.storagePath, 3600);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.attachment.isImage
        ? _buildImage(context)
        : _buildFile(context);
  }

  Widget _buildImage(BuildContext context) {
    final placeholderBg = context.cs.backgroundElevated;
    if (_signedUrl == null) {
      return ClipRRect(
        borderRadius: AppRadius.smBR,
        child: Container(
          width: 220,
          height: 160,
          color: placeholderBg,
          child: const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColorScheme.accent),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: ClipRRect(
        borderRadius: AppRadius.smBR,
        child: Image.network(
          _signedUrl!,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : Container(
                  width: 220,
                  height: 160,
                  color: placeholderBg,
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColorScheme.accent),
                  ),
                ),
          errorBuilder: (ctx, error, stackTrace) => Container(
            width: 220,
            height: 160,
            color: placeholderBg,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: context.cs.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    if (_signedUrl == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(_signedUrl!),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDownload,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMine
              ? Colors.white.withValues(alpha: 0.15)
              : context.cs.backgroundElevated,
          borderRadius: AppRadius.smBR,
          border: Border.all(
            color: widget.isMine
                ? Colors.white.withValues(alpha: 0.3)
                : AppColorScheme.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fileTypeIcon(widget.attachment.mimeType, context.cs.textSecondary),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isMine
                          ? Colors.white
                          : context.cs.textPrimary,
                    ),
                  ),
                  Text(
                    widget.attachment.formattedSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMine
                          ? Colors.white.withValues(alpha: 0.7)
                          : context.cs.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_outlined,
              size: 18,
              color: widget.isMine
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColorScheme.accent,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _fileTypeIcon(String mimeType, Color neutralColor) {
    if (mimeType == 'application/pdf') {
      return const Icon(Icons.picture_as_pdf,
          color: Color(0xFFDC4444), size: 28);
    } else if (mimeType.contains('word') ||
        mimeType == 'application/msword') {
      return const Icon(Icons.description,
          color: Color(0xFF2B5CE6), size: 28);
    } else if (mimeType.contains('excel') ||
        mimeType.contains('spreadsheet') ||
        mimeType == 'application/vnd.ms-excel') {
      return const Icon(Icons.table_chart,
          color: Color(0xFF1D6F42), size: 28);
    } else if (mimeType.contains('powerpoint') ||
        mimeType.contains('presentation') ||
        mimeType == 'application/vnd.ms-powerpoint') {
      return const Icon(Icons.slideshow,
          color: Color(0xFFD04423), size: 28);
    } else if (mimeType.startsWith('video/')) {
      return Icon(Icons.video_file, color: neutralColor, size: 28);
    } else if (mimeType.startsWith('audio/')) {
      return Icon(Icons.audio_file, color: neutralColor, size: 28);
    }
    return Icon(Icons.insert_drive_file, color: neutralColor, size: 28);
  }
}
